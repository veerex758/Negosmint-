import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:wallet/wallet.dart' as wallet;
import 'package:web3dart/web3dart.dart' as eth;

import '../network/evm_rpc_service.dart';
import '../security/biometric_service.dart';
import 'mnemonic_service.dart';
import 'secure_key_store.dart';

class WalletException implements Exception {
  final String message;
  const WalletException(this.message);
  @override
  String toString() => 'WalletException: $message';
}

class WalletSnapshot {
  final String address;
  final List<String> mnemonic;
  const WalletSnapshot({required this.address, required this.mnemonic});
}

class WalletService {
  static const _activityKey = 'wallet.activity.v1';

  final SecureKeyStore _keyStore;
  final MnemonicService _mnemonics;
  final BiometricService _biometrics;
  final FlutterSecureStorage _storage;

  WalletService({
    SecureKeyStore? keyStore,
    MnemonicService? mnemonics,
    BiometricService? biometrics,
    FlutterSecureStorage? storage,
  })  : _keyStore = keyStore ?? const SecureKeyStore(),
        _mnemonics = mnemonics ?? MnemonicService(),
        _biometrics = biometrics ?? BiometricService(),
        _storage = storage ?? const FlutterSecureStorage();

  /// Generates the recovery phrase in memory only.
  /// Persistence happens only after the user completes backup verification.
  Future<WalletSnapshot> createWallet() async {
    final mnemonic = _mnemonics.generate();
    final address = _mnemonics.deriveEvmAddress(mnemonic);
    return WalletSnapshot(address: address, mnemonic: mnemonic);
  }

  Future<void> finalizeWallet(WalletSnapshot snapshot) async {
    if (!_mnemonics.validate(snapshot.mnemonic)) {
      throw const WalletException('Invalid recovery phrase.');
    }
    final derived = _mnemonics.deriveEvmAddress(snapshot.mnemonic);
    if (derived.toLowerCase() != snapshot.address.toLowerCase()) {
      throw const WalletException('Wallet derivation verification failed.');
    }
    await _keyStore.saveMnemonic(snapshot.mnemonic);
    await _keyStore.saveAddress(snapshot.address);
  }

  Future<bool> hasWallet() => _keyStore.hasWallet();

  Future<WalletSnapshot?> restoreWallet() async {
    final mnemonic = await _keyStore.loadMnemonic();
    if (mnemonic == null || !_mnemonics.validate(mnemonic)) return null;
    final address = _mnemonics.deriveEvmAddress(mnemonic);
    await _keyStore.saveAddress(address);
    // The recovery phrase never leaves the secure storage boundary here.
    return WalletSnapshot(address: address, mnemonic: const []);
  }

  Future<String?> getPublicAddress() => _keyStore.loadAddress();

  Future<String> sendSepoliaEth({
    required String to,
    required BigInt valueWei,
  }) async {
    if (!await _biometrics.authenticateForSigning()) {
      throw const WalletException(
        'Authentication required to sign this transaction.',
      );
    }
    if (valueWei <= BigInt.zero) {
      throw const WalletException('Amount must be greater than zero.');
    }

    final mnemonic = await _keyStore.loadMnemonic();
    if (mnemonic == null || !_mnemonics.validate(mnemonic)) {
      throw const WalletException('Wallet is not initialized correctly.');
    }

    late final wallet.EthereumAddress recipient;
    try {
      recipient = wallet.EthereumAddress.fromHex(to);
    } on FormatException {
      throw const WalletException('Invalid recipient address.');
    }

    final rpc = EvmRpcService();
    if (await rpc.getChainId() != EvmRpcService.chainId) {
      throw const WalletException('Connected network is not Ethereum Sepolia.');
    }

    final privateKeyHex = _mnemonics.derivePrivateKeyHex(mnemonic);
    final client = eth.Web3Client(EvmRpcService.rpcUrl, http.Client());
    try {
      final credentials = eth.EthPrivateKey.fromHex(privateKeyHex);
      final sender = credentials.address;
      if (sender.eip55With0x.toLowerCase() ==
          recipient.eip55With0x.toLowerCase()) {
        throw const WalletException('Recipient cannot be the same as your wallet.');
      }

      final balance = await client.getBalance(sender);
      final gasPrice = await client.getGasPrice();
      final amount = wallet.EtherAmount.inWei(valueWei);
      final estimatedGas = await client.estimateGas(
        sender: sender,
        to: recipient,
        value: amount,
        gasPrice: gasPrice,
      );
      final gasCostWei = gasPrice.getInWei * estimatedGas;

      if (balance.getInWei < valueWei + gasCostWei) {
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
      throw const WalletException('Invalid transaction data.');
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
    await _keyStore.deleteWallet();
    await _storage.delete(key: _activityKey);
  }
}
