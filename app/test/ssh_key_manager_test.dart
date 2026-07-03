import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runpod_manager/domain/ssh_key_manager.dart';

import 'fake_settings_store.dart';

void main() {
  group('SshKeyManager', () {
    test('generates an ed25519 identity with an OpenSSH-formatted public key', () async {
      final manager = SshKeyManager(FakeSettingsStore());
      final identity = await manager.ensureIdentity();

      expect(identity.publicKeyOpenSsh, startsWith('ssh-ed25519 '));
      expect(identity.privateKeyPem, contains('BEGIN OPENSSH PRIVATE KEY'));

      // The generated PEM must itself be parseable by dartssh2's own decoder,
      // proving it round-trips through the exact format the real client uses.
      final parsed = SSHKeyPair.fromPem(identity.privateKeyPem);
      expect(parsed, hasLength(1));
      expect(parsed.first.name, 'ssh-ed25519');
    });

    test('reuses the same identity across calls instead of regenerating', () async {
      final store = FakeSettingsStore();
      final first = await SshKeyManager(store).ensureIdentity();
      final second = await SshKeyManager(store).ensureIdentity();

      expect(second.publicKeyOpenSsh, first.publicKeyOpenSsh);
    });
  });
}
