import 'package:flutter_test/flutter_test.dart';
import 'package:negosmint_wallet/core/security/wallet_security_service.dart';
import 'package:negosmint_wallet/core/wallet/mnemonic_service.dart';

void main() {
  group('WalletSecurityService policy', () {
    test('requires exactly six numeric PIN digits', () async {
      final service = WalletSecurityService();

      await expectLater(service.setPin('123'), throwsFormatException);
      await expectLater(service.setPin('12345a'), throwsFormatException);
      await expectLater(service.setPin('1234567'), throwsFormatException);
      await expectLater(service.setPin('１２３４５６'), throwsFormatException);
    });

    test('exposes only supported auto-lock durations', () {
      expect(
        WalletSecurityService.allowedAutoLockMinutes,
        equals([1, 5, 15, 30, 60]),
      );
    });

    test('rejects unsupported auto-lock durations before storage access',
        () async {
      final service = WalletSecurityService();

      await expectLater(service.setAutoLockMinutes(0), throwsArgumentError);
      await expectLater(service.setAutoLockMinutes(2), throwsArgumentError);
      await expectLater(service.setAutoLockMinutes(120), throwsArgumentError);
    });
  });

  group('Phase 6 backup and recovery safeguards', () {
    final mnemonics = MnemonicService();

    test('generated recovery phrase validates and derives a stable address', () {
      final phrase = mnemonics.generate();
      expect(phrase, hasLength(12));
      expect(mnemonics.validate(phrase), isTrue);

      final firstAddress = mnemonics.deriveEvmAddress(phrase);
      final restoredAddress = mnemonics.deriveEvmAddress(
        phrase.join(' ').trim().split(RegExp(r'\\s+')),
      );

      expect(firstAddress, matches(RegExp(r'^0x[0-9a-fA-F]{40}$')));
      expect(restoredAddress, firstAddress);
    });

    test('rejects malformed recovery phrase before deriving a wallet', () {
      expect(
        mnemonics.validate(['not', 'a', 'valid', 'recovery', 'phrase']),
        isFalse,
      );
    });

    test('private key derivation is stable for the same recovery phrase', () {
      final phrase = mnemonics.generate();
      final first = mnemonics.derivePrivateKeyHex(phrase);
      final second = mnemonics.derivePrivateKeyHex(List<String>.from(phrase));

      expect(first, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(second, first);
    });
  });
}
