import 'dart:convert';
import 'dart:typed_data';

import 'crypto_engine.dart';

/// Deterministic, **insecure** stand-in for the Rust crypto core.
///
/// It exists so the UI can exercise the full encrypt → send → receive →
/// verify → decrypt pipeline without the native uniffi library. Output is
/// stable across runs and platforms (useful for golden tests), but it is
/// trivially reversible — never ship this outside dev builds.
///
/// Envelope layout:
/// ```
/// [0..4)   magic "MCK1"
/// [4]      scheme index
/// [5..13)  mock signature (FNV-1a 64 over conversationId + ciphertext)
/// [13..)   ciphertext (UTF-8 plaintext XOR per-conversation keystream)
/// ```
class MockCryptoEngine implements CryptoEngine {
  MockCryptoEngine({this.deviceSeed = 'mercury-dev-device'});

  /// Seed for the deterministic identity key.
  final String deviceSeed;

  static const _magic = [0x4D, 0x43, 0x4B, 0x31]; // "MCK1"
  static const _headerLength = 13;

  @override
  String get displayName => 'MockCryptoEngine (insecure, dev only)';

  @override
  bool get isSecure => false;

  @override
  Future<IdentityPublicKey> loadIdentity() async =>
      IdentityPublicKey(_expand('identity:$deviceSeed', 32));

  @override
  Future<Uint8List> encrypt({
    required String conversationId,
    required EncryptionScheme scheme,
    required String plaintext,
  }) async {
    final body = Uint8List.fromList(utf8.encode(plaintext));
    _xorInPlace(body, conversationId);
    final signature = _sign(conversationId, body);

    return (BytesBuilder(copy: false)
          ..add(_magic)
          ..addByte(scheme.index)
          ..add(signature)
          ..add(body))
        .takeBytes();
  }

  @override
  Future<DecryptedMessage> decrypt({
    required String conversationId,
    required EncryptionScheme scheme,
    required Uint8List envelope,
  }) async {
    if (envelope.length < _headerLength ||
        !_listEquals(envelope.sublist(0, 4), _magic)) {
      throw const FormatException('Not a MockCryptoEngine envelope');
    }
    final signature = envelope.sublist(5, _headerLength);
    final body = Uint8List.fromList(envelope.sublist(_headerLength));
    final verified = _listEquals(signature, _sign(conversationId, body));

    _xorInPlace(body, conversationId);
    return DecryptedMessage(
      plaintext: utf8.decode(body, allowMalformed: true),
      verified: verified,
    );
  }

  // --- deterministic helpers -------------------------------------------------

  // All arithmetic below is exact 32-bit so results are bit-identical on the
  // Dart VM, dart2js (where ints are doubles) and dart2wasm.
  static const _mask32 = 0xFFFFFFFF;

  /// 8-byte mock signature: two FNV-1a passes with different seeds.
  static Uint8List _sign(String conversationId, Uint8List body) {
    final id = utf8.encode(conversationId);
    final a = _fnv1a(body, seed: _fnv1a(id));
    final b = _fnv1a(body, seed: _fnv1a(id, seed: 0x01234567));
    return Uint8List(8)
      ..buffer.asByteData().setUint32(0, a)
      ..buffer.asByteData().setUint32(4, b);
  }

  static void _xorInPlace(Uint8List data, String conversationId) {
    final keystream = _expand('stream:$conversationId', data.length);
    for (var i = 0; i < data.length; i++) {
      data[i] ^= keystream[i];
    }
  }

  /// Expands [label] into [length] pseudo-random bytes (xorshift32).
  static Uint8List _expand(String label, int length) {
    var x = _fnv1a(utf8.encode(label));
    if (x == 0) x = 0x9E3779B9;
    final out = Uint8List(length);
    for (var i = 0; i < length; i++) {
      x ^= (x << 13) & _mask32;
      x ^= x >>> 17;
      x ^= (x << 5) & _mask32;
      x &= _mask32;
      out[i] = (x >>> 24) & 0xFF;
    }
    return out;
  }

  /// 32-bit FNV-1a. The prime 0x01000193 is 2^24 + 0x193; splitting the
  /// multiply keeps every intermediate below 2^53.
  static int _fnv1a(List<int> bytes, {int seed = 0x811C9DC5}) {
    var h = seed;
    for (final b in bytes) {
      h ^= b;
      h = (((h << 24) & _mask32) + h * 0x193) & _mask32;
    }
    return h;
  }

  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
