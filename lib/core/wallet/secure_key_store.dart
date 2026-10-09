import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The only persistence boundary for wallet secrets.
///
/// flutter_secure_storage delegates secret protection to platform secure
/// facilities. No mnemonic/private key is written to SharedPreferences,
/// Supabase, analytics, logs, or application databases.
class SecureKeyStore {
  static const _mnemonicKey = 'wallet.mnemonic.v1';
  static const _addressKey = 'wallet.address.v1';

  const SecureKeyStore();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  Future<bool> hasWallet() async {
    final mnemonic = await _storage.read(key: _mnemonicKey);
    return mnemonic != null && mnemonic.trim().isNotEmpty;
  }

  Future<void> saveMnemonic(List<String> mnemonic) async {
    if (mnemonic.isEmpty) {
      throw StateError('Cannot store an empty recovery phrase.');
    }
    await _storage.write(key: _mnemonicKey, value: mnemonic.join(' '));
  }

  Future<List<String>?> loadMnemonic() async {
    final value = await _storage.read(key: _mnemonicKey);
    if (value == null || value.trim().isEmpty) return null;
    return value.trim().split(RegExp(r'\s+'));
  }

  Future<void> saveAddress(String address) =>
      _storage.write(key: _addressKey, value: address);

  Future<String?> loadAddress() => _storage.read(key: _addressKey);

  Future<void> deleteWallet() async {
    await _storage.delete(key: _mnemonicKey);
    await _storage.delete(key: _addressKey);
  }
}
