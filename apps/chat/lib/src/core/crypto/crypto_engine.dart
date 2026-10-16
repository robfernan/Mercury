import 'dart:typed_data';

/// Public half of a device identity, safe to share with peers and the server.
class IdentityPublicKey {
  const IdentityPublicKey(this.bytes);

  /// Raw Ed25519 public key (32 bytes).
  final Uint8List bytes;

  /// Short, human-comparable fingerprint (e.g. for safety-number UI).
  String get fingerprint {
    final hex = bytes
        .take(8)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return [
      for (var i = 0; i < hex.length; i += 4) hex.substring(i, i + 4),
    ].join(' ').toUpperCase();
  }
}

/// Which E2EE scheme protects a conversation.
enum EncryptionScheme {
  /// 1:1 direct messages.
  doubleRatchet,

  /// Groups and calls: hybrid post-quantum MLS (ML-KEM + X25519).
  hybridPqMls,
}

/// Result of decrypting an inbound envelope.
class DecryptedMessage {
  const DecryptedMessage({required this.plaintext, required this.verified});

  final String plaintext;

  /// Whether the sender's Ed25519 signature checked out.
  final bool verified;
}

/// Boundary to the Rust crypto core (uniffi bindings).
///
/// Everything above this interface is platform-agnostic Dart. The production
/// implementation will wrap the generated bindings in
/// `lib/src/generated/` (see README step 2). Until those exist, the app runs
/// against `MockCryptoEngine`.
abstract interface class CryptoEngine {
  /// Human-readable name shown in diagnostics UI.
  String get displayName;

  /// Whether this engine provides real cryptographic guarantees.
  bool get isSecure;

  /// Loads or creates this device's identity key pair and returns the public half.
  Future<IdentityPublicKey> loadIdentity();

  /// Encrypts [plaintext] for [conversationId] and returns an opaque envelope
  /// (ciphertext + Ed25519 signature) ready to hand to the gateway.
  Future<Uint8List> encrypt({
    required String conversationId,
    required EncryptionScheme scheme,
    required String plaintext,
  });

  /// Verifies and decrypts an envelope produced by [encrypt] on any peer.
  Future<DecryptedMessage> decrypt({
    required String conversationId,
    required EncryptionScheme scheme,
    required Uint8List envelope,
  });
}
