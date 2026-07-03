import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:runpod_manager/data/ssh_connector.dart';
import 'package:runpod_manager/domain/ssh_key_manager.dart';

import 'fake_settings_store.dart';

/// Genuine end-to-end proof that the app's SSH stack (in-app ed25519 key
/// generation, OpenSSH PEM encoding, and dartssh2 auth/shell handling) works
/// against a real sshd -- not a fake. Requires openssh-server + ssh-keygen on
/// PATH; skipped automatically if unavailable.
void main() {
  const testPort = 2299;
  late Directory tempDir;
  Process? sshdProcess;
  // Shared across setUpAll and the test so the key written to authorized_keys
  // is the exact same one used to authenticate.
  late SshIdentity identity;

  setUpAll(() async {
    if (!File('/usr/sbin/sshd').existsSync()) {
      return;
    }
    // Debian/Ubuntu's sshd refuses to start without its privilege separation
    // directory; normally created by the package postinst, but harmless (and
    // idempotent) to ensure here for minimal base images.
    await Directory('/run/sshd').create(recursive: true);

    tempDir = await Directory.systemTemp.createTemp('runpod_ssh_e2e_');

    final hostKeyPath = '${tempDir.path}/host_ed25519_key';
    final keygen = await Process.run(
      'ssh-keygen',
      ['-t', 'ed25519', '-f', hostKeyPath, '-N', ''],
    );
    expect(keygen.exitCode, 0, reason: keygen.stderr.toString());

    identity = await SshKeyManager(FakeSettingsStore()).ensureIdentity();
    final authorizedKeysPath = '${tempDir.path}/authorized_keys';
    await File(authorizedKeysPath).writeAsString('${identity.publicKeyOpenSsh}\n');

    final sshdConfigPath = '${tempDir.path}/sshd_config';
    await File(sshdConfigPath).writeAsString('''
Port $testPort
ListenAddress 127.0.0.1
HostKey $hostKeyPath
AuthorizedKeysFile $authorizedKeysPath
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
UsePAM no
PermitRootLogin yes
StrictModes no
PidFile ${tempDir.path}/sshd.pid
''');

    sshdProcess = await Process.start('/usr/sbin/sshd', ['-f', sshdConfigPath, '-D', '-e']);

    // Wait for sshd to actually be accepting connections.
    for (var i = 0; i < 50; i++) {
      try {
        final socket = await Socket.connect('127.0.0.1', testPort,
            timeout: const Duration(milliseconds: 200));
        await socket.close();
        return;
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    fail('local test sshd never started listening on port $testPort');
  });

  tearDownAll(() async {
    sshdProcess?.kill();
    if (sshdProcess != null) {
      await sshdProcess!.exitCode;
    }
  });

  test('connects with the app-generated key and executes a command over a real shell',
      () async {
    if (!File('/usr/sbin/sshd').existsSync()) {
      markTestSkipped('openssh-server not installed in this environment');
      return;
    }

    final connector = DartSshConnector();

    final handle = await connector.connectShell(
      host: '127.0.0.1',
      port: testPort,
      username: 'root',
      identity: identity.keyPair,
    );

    final outputBuffer = StringBuffer();
    final marker = 'RUNPOD_E2E_${DateTime.now().microsecondsSinceEpoch}';
    final sawMarkerTwice = Completer<void>();

    // The marker should appear twice: once as the pty's echo of our typed
    // input, and once as the actual stdout of the executed `echo` command --
    // requiring both proves the remote shell really ran the command rather
    // than just looping input back.
    int occurrences() => marker.allMatches(outputBuffer.toString()).length;

    final sub = handle.output.listen((Uint8List data) {
      outputBuffer.write(utf8.decode(data, allowMalformed: true));
      if (occurrences() >= 2 && !sawMarkerTwice.isCompleted) {
        sawMarkerTwice.complete();
      }
    });

    handle.write(Uint8List.fromList(utf8.encode('echo $marker\n')));

    await sawMarkerTwice.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () =>
          fail('expected marker twice (echo + command output), got: $outputBuffer'),
    );

    await sub.cancel();
    handle.close();
  });
}
