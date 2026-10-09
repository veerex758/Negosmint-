import 'package:flutter_test/flutter_test.dart';
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
  _FakeKeyStore({this.mnemonic, this.address});

  final List<String>? mnemonic;
  final String? address;
  String? savedAddress;

  @override
  Future<List<String>?> loadMnemonic() async => mnemonic;

  @override
  Future<String?> loadAddress() async => savedAddress ?? address;

  @override
  Future<void> saveAddress(String value) async {
    savedAddress = value;
  }
}

class _FakeBiometricService extends BiometricService {
  _FakeBiometricService(this.allowed);

  final bool allowed;

  @override
  Future<bool> authenticateForSigning() async => allowed;
}

void main() {
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

    test('rejects malformed recipient before making a network request', () async {
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
