import 'package:flutter_test/flutter_test.dart';
import 'package:negosmint_wallet/core/network/evm_rpc_service.dart';
import 'package:negosmint_wallet/core/security/biometric_service.dart';
import 'package:negosmint_wallet/core/wallet/secure_key_store.dart';
import 'package:negosmint_wallet/core/wallet/wallet_service.dart';

const _validMnemonic = <String>[
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'about',
];

class _FakeKeyStore extends SecureKeyStore {
  _FakeKeyStore({List<String>? mnemonic, this.address})
      : storedMnemonic = mnemonic;

  List<String>? storedMnemonic;
  final String? address;
  String? savedAddress;

  @override
  Future<List<String>?> loadMnemonic() async => storedMnemonic;

  @override
  Future<void> saveMnemonic(List<String> value) async {
    storedMnemonic = List<String>.from(value);
  }

  @override
  Future<String?> loadAddress() async => savedAddress ?? address;

  @override
  Future<void> saveAddress(String value) async {
    savedAddress = value;
  }
}

class _WrongChainRpc extends EvmRpcService {
  @override
  Future<int> getChainId() async => 1;
}

class _FakeBiometricService extends BiometricService {
  _FakeBiometricService(this.allowed);

  final bool allowed;

  @override
  Future<bool> authenticateForSigning() async => allowed;
}

void main() {
  group('Phase 7 wallet lifecycle coverage', () {
    test('creates and finalizes a wallet only after phrase verification',
        () async {
      final store = _FakeKeyStore();
      final service = WalletService(
        keyStore: store,
        biometrics: _FakeBiometricService(true),
      );

      final snapshot = await service.createWallet();
      expect(snapshot.mnemonic, hasLength(12));
      expect(snapshot.address, matches(RegExp(r'^0x[0-9a-fA-F]{40}$')));
      expect(store.storedMnemonic, isNull);

      await service.finalizeWallet(snapshot);
      expect(store.storedMnemonic, snapshot.mnemonic);
      expect(store.savedAddress, snapshot.address);
    });

    test('restores the same address from a valid stored recovery phrase',
        () async {
      final store = _FakeKeyStore(mnemonic: _validMnemonic);
      final service = WalletService(
        keyStore: store,
        biometrics: _FakeBiometricService(true),
      );

      final restored = await service.restoreWallet();

      expect(restored, isNotNull);
      expect(restored!.address, matches(RegExp(r'^0x[0-9a-fA-F]{40}$')));
      expect(restored.address, store.savedAddress);
      expect(restored.mnemonic, isEmpty);
    });

    test('does not persist an invalid recovery phrase', () async {
      final store = _FakeKeyStore();
      final service = WalletService(
        keyStore: store,
        biometrics: _FakeBiometricService(true),
      );

      await expectLater(
        service.finalizeWallet(
          const WalletSnapshot(
            address: '0x0000000000000000000000000000000000000001',
            mnemonic: ['not', 'a', 'valid', 'recovery', 'phrase'],
          ),
        ),
        throwsA(isA<WalletException>()),
      );
      expect(store.storedMnemonic, isNull);
      expect(store.savedAddress, isNull);
    });
  });

  group('Phase 7 wallet transaction validation gates', () {
    test('requires authentication before signing a native transfer', () async {
      final service = WalletService(
        keyStore: _FakeKeyStore(mnemonic: _validMnemonic),
        biometrics: _FakeBiometricService(false),
      );

      await expectLater(
        service.sendSepoliaEth(
          to: '0x0000000000000000000000000000000000000001',
          valueWei: BigInt.one,
        ),
        throwsA(
          isA<WalletException>().having(
            (error) => error.message,
            'message',
            'Authentication required to sign this transaction.',
          ),
        ),
      );
    });

    test('rejects zero and negative native transfer amounts', () async {
      final service = WalletService(
        keyStore: _FakeKeyStore(mnemonic: _validMnemonic),
        biometrics: _FakeBiometricService(true),
      );

      for (final amount in [BigInt.zero, -BigInt.one]) {
        await expectLater(
          service.sendSepoliaEth(
            to: '0x0000000000000000000000000000000000000001',
            valueWei: amount,
          ),
          throwsA(
            isA<WalletException>().having(
              (error) => error.message,
              'message',
              'Amount is outside the supported ETH range.',
            ),
          ),
        );
      }
    });

    test('rejects malformed recipient before making a network request',
        () async {
      final service = WalletService(
        keyStore: _FakeKeyStore(mnemonic: _validMnemonic),
        biometrics: _FakeBiometricService(true),
      );

      await expectLater(
        service.sendSepoliaEth(to: 'not-an-address', valueWei: BigInt.one),
        throwsA(
          isA<WalletException>().having(
            (error) => error.message,
            'message',
            'Invalid recipient address.',
          ),
        ),
      );
    });

    test('accepts balance equal to amount plus fee', () {
      expect(
        () => WalletService.validateSufficientBalance(
          balanceWei: BigInt.from(150),
          valueWei: BigInt.from(100),
          gasCostWei: BigInt.from(50),
        ),
        returnsNormally,
      );
    });

    test('rejects balance below amount plus fee', () {
      expect(
        () => WalletService.validateSufficientBalance(
          balanceWei: BigInt.from(149),
          valueWei: BigInt.from(100),
          gasCostWei: BigInt.from(50),
        ),
        throwsA(
          isA<WalletException>().having(
            (error) => error.message,
            'message',
            'Insufficient Sepolia ETH balance for amount and network fee.',
          ),
        ),
      );
    });

    test('rejects a non-Sepolia chain before attempting to send', () async {
      final service = WalletService(
        keyStore: _FakeKeyStore(mnemonic: _validMnemonic),
        biometrics: _FakeBiometricService(true),
        rpcFactory: _WrongChainRpc.new,
      );

      await expectLater(
        service.sendSepoliaEth(
          to: '0x0000000000000000000000000000000000000001',
          valueWei: BigInt.one,
        ),
        throwsA(
          isA<WalletException>().having(
            (error) => error.message,
            'message',
            'Connected network is not Ethereum Sepolia.',
          ),
        ),
      );
    });

    test('refuses to sign when no recovery phrase is stored', () async {
      final service = WalletService(
        keyStore: _FakeKeyStore(),
        biometrics: _FakeBiometricService(true),
      );

      await expectLater(
        service.sendSepoliaTransaction(
          to: '0x0000000000000000000000000000000000000001',
          valueWei: BigInt.zero,
        ),
        throwsA(
          isA<WalletException>().having(
            (error) => error.message,
            'message',
            'Wallet is not initialized correctly.',
          ),
        ),
      );
    });

    test('rejects malformed transaction data before network access', () async {
      final service = WalletService(
        keyStore: _FakeKeyStore(mnemonic: _validMnemonic),
        biometrics: _FakeBiometricService(true),
      );

      await expectLater(
        service.signSepoliaTransaction(
          to: '0x0000000000000000000000000000000000000001',
          valueWei: BigInt.zero,
          data: '0x0g',
        ),
        throwsA(
          isA<WalletException>().having(
            (error) => error.message,
            'message',
            'Invalid transaction data.',
          ),
        ),
      );
    });
  });
}
