import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

/// A live interactive shell session over SSH.
abstract class SshShellHandle {
  Stream<Uint8List> get output;
  void write(Uint8List data);
  void resize(int width, int height);
  Future<int?> get exitCode;
  void close();
}

abstract class SshConnector {
  Future<SshShellHandle> connectShell({
    required String host,
    required int port,
    required String username,
    required SSHKeyPair identity,
    int cols = 80,
    int rows = 24,
    Duration timeout = const Duration(seconds: 10),
  });
}

class DartSshConnector implements SshConnector {
  const DartSshConnector();

  @override
  Future<SshShellHandle> connectShell({
    required String host,
    required int port,
    required String username,
    required SSHKeyPair identity,
    int cols = 80,
    int rows = 24,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final socket = await SSHSocket.connect(host, port, timeout: timeout);
    final client = SSHClient(
      socket,
      username: username,
      identities: [identity],
    );
    final session = await client.shell(
      pty: SSHPtyConfig(width: cols, height: rows),
    );
    return _DartSshShellHandle(client, session);
  }
}

class _DartSshShellHandle implements SshShellHandle {
  final SSHClient _client;
  final SSHSession _session;

  _DartSshShellHandle(this._client, this._session);

  @override
  Stream<Uint8List> get output => _session.stdout;

  @override
  void write(Uint8List data) => _session.write(data);

  @override
  void resize(int width, int height) => _session.resizeTerminal(width, height);

  @override
  Future<int?> get exitCode => _session.waitForExit();

  @override
  void close() {
    _session.close();
    _client.close();
  }
}
