import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:wallet/wallet.dart' as wallet;
import 'package:web3dart/web3dart.dart' as eth;

import '../network/evm_rpc_service.dart';

class WalletException implements Exception {
  final String message;

  const WalletException(this.message);

  @override
  String toString() => 'WalletException: $message';
}

class WalletSnapshot {
  final String address;
  final List<String> mnemonic;

  const WalletSnapshot({
    required this.address,
    required this.mnemonic,
  });
}

class WalletService {
  static const _mnemonicKey = 'wallet.mnemonic';
  static const _addressKey = 'wallet.address';
  static const _activityKey = 'wallet.activity';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<String?> getRecoveryPhrase() => _storage.read(key: _mnemonicKey);

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

    return WalletSnapshot(
      address: address,
      mnemonic: mnemonic,
    );
  }

  Future<String> sendSepoliaEth({
    required String to,
    required BigInt valueWei,
  }) async {
    final stored = await _storage.read(key: _mnemonicKey);
    if (stored == null || stored.trim().isEmpty) {
      throw const WalletException('Wallet is not initialized.');
    }

    if (valueWei <= BigInt.zero) {
      throw const WalletException('Amount must be greater than zero.');
    }

    final mnemonic = stored.split(' ');
    if (!wallet.validateMnemonic(mnemonic)) {
      throw const WalletException('Stored recovery phrase is invalid.');
    }

    late final eth.EthereumAddress recipient;
    try {
      recipient = eth.EthereumAddress.fromHex(to);
    } on FormatException {
      throw const WalletException('Invalid recipient address.');
    }

    final rpc = EvmRpcService();
    final connectedChainId = await rpc.getChainId();
    if (connectedChainId != EvmRpcService.chainId) {
      throw const WalletException('Connected network is not Ethereum Sepolia.');
    }

    final seed = wallet.mnemonicToSeed(mnemonic);
    final master = wallet.ExtendedPrivateKey.master(seed, wallet.xprv);
    final child =
        master.forPath("m/44'/60'/0'/0/0") as wallet.ExtendedPrivateKey;
    final privateKeyHex = child.key.toRadixString(16).padLeft(64, '0');

    final client = eth.Web3Client(EvmRpcService.rpcUrl, http.Client());
    try {
      final credentials = eth.EthPrivateKey.fromHex(privateKeyHex);
      final sender = credentials.address;

      if (sender.hexEip55.toLowerCase() == recipient.hexEip55.toLowerCase()) {
        throw const WalletException(
          'Recipient cannot be the same as your wallet.',
        );
      }

      final balance = await client.getBalance(sender);
      final gasPrice = await client.getGasPrice();
      final amount = eth.EtherAmount.inWei(valueWei);

      final estimatedGas = await client.estimateGas(
        sender: sender,
        to: recipient,
        value: amount,
        gasPrice: gasPrice,
      );

      final gasCostWei = gasPrice.getInWei * estimatedGas;
      final totalRequiredWei = valueWei + gasCostWei;

      if (balance.getInWei < totalRequiredWei) {
        throw const WalletException(
          'Insufficient Sepolia ETH balance for amount and network fee.',
        );
      }

      final maxGas = estimatedGas > BigInt.from(0x7fffffffffffffff)
          ? 0x7fffffffffffffff
          : estimatedGas.toInt();

      final hash = await client.sendTransaction(
        credentials,
        eth.Transaction(
          to: recipient,
          value: amount,
          gasPrice: gasPrice,
          maxGas: maxGas,
        ),
        chainId: EvmRpcService.chainId,
      );

      await _saveActivity(hash);
      return hash;
    } on WalletException {
      rethrow;
    } on FormatException {
      throw const WalletException('Invalid recipient address.');
    } finally {
      await client.dispose();
    }
  }

  Future<List<String>> getActivity() async {
    final raw = await _storage.read(key: _activityKey);
    if (raw == null || raw.isEmpty) return const [];

    return raw.split('|').where((value) => value.isNotEmpty).toList();
  }

  Future<void> _saveActivity(String hash) async {
    final current = await getActivity();
    final updated = <String>[
      hash,
      ...current.where((value) => value != hash),
    ];

    await _storage.write(
      key: _activityKey,
      value: updated.take(20).join('|'),
    );
  }

  Future<void> clearWallet() async {
    await _storage.delete(key: _mnemonicKey);
    await _storage.delete(key: _addressKey);
    await _storage.delete(key: _activityKey);
  }

  Future<WalletSnapshot> _persistWallet(List<String> mnemonic) async {
    final address = await _deriveAddress(mnemonic);

    await _storage.write(
      key: _mnemonicKey,
      value: mnemonic.join(' '),
    );
    await _storage.write(
      key: _addressKey,
      value: address,
    );

    return WalletSnapshot(
      address: address,
      mnemonic: mnemonic,
    );
  }

  Future<String> _deriveAddress(List<String> mnemonic) async {
    final seed = wallet.mnemonicToSeed(mnemonic);
    final master = wallet.ExtendedPrivateKey.master(seed, wallet.xprv);
    final child =
        master.forPath("m/44'/60'/0'/0/0") as wallet.ExtendedPrivateKey;
    final privateKey = wallet.PrivateKey(child.key);
    final publicKey = wallet.ethereum.createPublicKey(privateKey);

    return wallet.EthereumAddress.fromPublicKey(publicKey).hexEip55;
  }
}
