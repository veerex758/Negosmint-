import 'package:flutter_test/flutter_test.dart';
import 'package:negosmint_wallet/core/wallet/mnemonic_service.dart';

void main() {
  group('Phase 6 backup and recovery safeguards', () {
    final mnemonics = MnemonicService();

    test('generated recovery phrase validates and derives a stable address', () {
      final phrase = mnemonics.generate();
      expect(phrase, hasLength(12));
      expect(mnemonics.validate(phrase), isTrue);

      final firstAddress = mnemonics.deriveEvmAddress(phrase);
      final restoredAddress = mnemonics.deriveEvmAddress(
        phrase.join(' ').trim().split(RegExp(r'\s+')),
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
