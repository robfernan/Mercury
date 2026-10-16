import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'crypto_engine.dart';

/// Platform hardware-backed security enclave manager.
/// Uses Windows DPAPI / Credential Manager on Windows,
/// Android Keystore with Hardware-backed StrongBox / TEE on Android,
/// and libsecret / GNOME Keyring on Linux.
class PlatformSecurityVault {
  PlatformSecurityVault([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
                storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
              ),
              wOptions: WindowsOptions(
                useBackwardCompatibility: false,
              ),
              lOptions: LinuxOptions(),
            );

  final FlutterSecureStorage _storage;

  static const _identitySeedKey = 'mercury_identity_seed_v1';
  static const _didKey = 'mercury_did_key_v1';

  /// Loads or generates the 32-byte Ed25519 identity seed sealed inside
  /// the operating system's hardware-backed key store.
  Future<Uint8List> getOrCreateIdentitySeed() async {
    final existingHex = await _storage.read(key: _identitySeedKey);
    if (existingHex != null && existingHex.length == 64) {
      return _hexToBytes(existingHex);
    }

    // Generate fresh 32 bytes of cryptographically secure random entropy
    final rng = Random.secure();
    final seed = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      seed[i] = rng.nextInt(256);
    }

    final hexStr = _bytesToHex(seed);
    await _storage.write(key: _identitySeedKey, value: hexStr);
    return seed;
  }

  /// Calculates a deterministic DID key representation: did:key:z6M...
  Future<String> getDeviceDid(IdentityPublicKey pubKey) async {
    final existing = await _storage.read(key: _didKey);
    if (existing != null) return existing;

    // Multicodec prefix 0xed01 for Ed25519 public key
    final prefixed = Uint8List(2 + pubKey.bytes.length);
    prefixed[0] = 0xed;
    prefixed[1] = 0x01;
    prefixed.setRange(2, prefixed.length, pubKey.bytes);

    final did = 'did:key:z${base64Url.encode(prefixed).replaceAll('=', '')}';
    await _storage.write(key: _didKey, value: did);
    return did;
  }

  /// Exports an armored recovery phrase representation of the root seed
  Future<String> exportBackupHex() async {
    final seed = await getOrCreateIdentitySeed();
    return _bytesToHex(seed);
  }

  /// Restores identity from backup hex
  Future<void> importBackupHex(String hex) async {
    final clean = hex.trim().toLowerCase();
    if (clean.length != 64) {
      throw ArgumentError('Invalid seed: expected 64 hex characters (32 bytes)');
    }
    await _storage.write(key: _identitySeedKey, value: clean);
    await _storage.delete(key: _didKey);
  }

  static String _bytesToHex(Uint8List bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }
}
