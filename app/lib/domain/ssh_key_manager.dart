import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' as crypto;
import 'package:dartssh2/dartssh2.dart';

import '../data/settings_store.dart';

class SshIdentity {
  final SSHKeyPair keyPair;
  final String privateKeyPem;
  final String publicKeyOpenSsh;

  const SshIdentity({
    required this.keyPair,
    required this.privateKeyPem,
    required this.publicKeyOpenSsh,
  });
}

/// Generates (once) and persists an ed25519 identity used to authenticate to
/// deployed pods, so a user never has to create or paste a key by hand.
class SshKeyManager {
  static const _comment = 'runpod-manager';

  final SettingsStore store;

  SshKeyManager(this.store);

  SshIdentity? _cached;

  Future<SshIdentity> ensureIdentity() async {
    final cached = _cached;
    if (cached != null) return cached;

    final existingPem = await store.getSshPrivateKeyPem();
    final identity = existingPem != null
        ? _identityFromPem(existingPem)
        : await _generateIdentity();

    if (existingPem == null) {
      await store.setSshPrivateKeyPem(identity.privateKeyPem);
    }
    _cached = identity;
    return identity;
  }

  Future<SshIdentity> _generateIdentity() async {
    final algorithm = crypto.Ed25519();
    final keyPair = await algorithm.newKeyPair();
    final seed = await keyPair.extractPrivateKeyBytes();
    final publicKey = await keyPair.extractPublicKey();

    // OpenSSH's ed25519 private key field is the 32-byte seed followed by
    // the 32-byte public key.
    final privateKeyBytes = Uint8List.fromList([...seed, ...publicKey.bytes]);
    final publicKeyBytes = Uint8List.fromList(publicKey.bytes);

    final sshKeyPair = OpenSSHEd25519KeyPair(publicKeyBytes, privateKeyBytes, _comment);
    return SshIdentity(
      keyPair: sshKeyPair,
      privateKeyPem: sshKeyPair.toPem(),
      publicKeyOpenSsh: _encodeOpenSshPublicKey(sshKeyPair),
    );
  }

  SshIdentity _identityFromPem(String pem) {
    final keyPair = SSHKeyPair.fromPem(pem).first;
    return SshIdentity(
      keyPair: keyPair,
      privateKeyPem: pem,
      publicKeyOpenSsh: _encodeOpenSshPublicKey(keyPair),
    );
  }

  String _encodeOpenSshPublicKey(SSHKeyPair keyPair) {
    final blob = keyPair.toPublicKey().encode();
    return '${keyPair.name} ${base64.encode(blob)} $_comment';
  }
}
