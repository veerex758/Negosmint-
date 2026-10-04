import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:wallet/wallet.dart' as wallet;

class WalletSnapshot {
  final String address;
  final List<String> mnemonic;
  const WalletSnapshot({required this.address, required this.mnemonic});
}

class WalletService {
  static const _mnemonicKey = 'wallet.mnemonic';
  static const _addressKey = 'wallet.address';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<WalletSnapshot> createWallet() async {
    final mnemonic = wallet.generateMnemonic(strength: 128);
    return _persistWallet(mnemonic);
  }

  Future<bool> hasWallet() async {
    final value = await _storage.read(key: _mnemonicKey);
    return value != null && value.trim().isNotEmpty;
  }

  Future<WalletSnapshot?> restoreWallet() async {
    final stored = await _storage.read(key: _mnemonicKey);
    if (stored == null || stored.trim().isEmpty) return null;
    final mnemonic = stored.split(' ');
    if (!wallet.validateMnemonic(mnemonic)) return null;
    final address = await _deriveAddress(mnemonic);
    await _storage.write(key: _addressKey, value: address);
    return WalletSnapshot(address: address, mnemonic: mnemonic);
  }

  Future<void> clearWallet() async {
    await _storage.delete(key: _mnemonicKey);
    await _storage.delete(key: _addressKey);
  }

  Future<WalletSnapshot> _persistWallet(List<String> mnemonic) async {
    final address = await _deriveAddress(mnemonic);
    await _storage.write(key: _mnemonicKey, value: mnemonic.join(' '));
    await _storage.write(key: _addressKey, value: address);
    return WalletSnapshot(address: address, mnemonic: mnemonic);
  }

  Future<String> _deriveAddress(List<String> mnemonic) async {
    final seed = wallet.mnemonicToSeed(mnemonic);
    final master = wallet.ExtendedPrivateKey.master(seed, wallet.xprv);
    final child = master.forPath("m/44'/60'/0'/0/0") as wallet.ExtendedPrivateKey;
    final privateKey = wallet.PrivateKey(child.key);
    final publicKey = wallet.ethereum.createPublicKey(privateKey);
    return wallet.EthereumAddress.fromPublicKey(publicKey).eip55With0x;
  }
}
