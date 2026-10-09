import 'package:flutter_test/flutter_test.dart';
import 'package:negosmint_wallet/core/wallet/eth_amount_parser.dart';

void main() {
  group('EthAmountParser.parse', () {
    test('converts decimal ETH to exact wei', () {
      expect(EthAmountParser.parse('1'), BigInt.from(1000000000000000000));
      expect(EthAmountParser.parse('0.25'), BigInt.from(250000000000000000));
      expect(
        EthAmountParser.parse('1.000000000000000001'),
        BigInt.from(1000000000000000001),
      );
    });

    test('rejects empty, zero, and malformed amounts', () {
      for (final value in [
        '',
        '0',
        '0.0',
        '-1',
        '+1',
        '.5',
        '1e-3',
        '1,000',
        '01',
        '1.0000000000000000001',
        '1.2.3',
        'NaN',
      ]) {
        expect(EthAmountParser.parse(value), isNull, reason: value);
      }
    });

    test('rejects values larger than uint256', () {
      final tooLargeEth = EthAmountParser.maxUint256 ~/ EthAmountParser.weiPerEth + BigInt.one;
      expect(EthAmountParser.parse(tooLargeEth.toString()), isNull);
    });
  });

  group('EthAmountParser.format', () {
    test('formats wei without floating point rounding', () {
      expect(EthAmountParser.format(BigInt.from(1000000000000000000)), '1');
      expect(
        EthAmountParser.format(BigInt.from(1000000000000000001)),
        '1.000000000000000001',
      );
      expect(
        EthAmountParser.format(BigInt.from(1234567890123456789), maxFractionDigits: 6),
        '1.234567',
      );
    });
  });
}
