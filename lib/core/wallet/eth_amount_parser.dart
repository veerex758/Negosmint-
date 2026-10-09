/// Strict decimal ETH parsing for native Sepolia transactions.
///
/// Rejects signs, exponent notation, over-precision, zero/negative
/// amounts, and values that exceed the EVM uint256 range.
class EthAmountParser {
  static final BigInt maxUint256 = (BigInt.one << 256) - BigInt.one;
  static final BigInt weiPerEth = BigInt.from(1000000000000000000);

  static BigInt? parse(String input) {
    final value = input.trim();
    if (!RegExp(r'^(?:0|[1-9][0-9]*)(?:\.[0-9]{0,18})?$').hasMatch(value)) {
      return null;
    }
    final parts = value.split('.');
    final whole = BigInt.tryParse(parts.first);
    if (whole == null) return null;
    final fractionText = parts.length == 2 ? parts[1] : '';
    final fraction = fractionText.isEmpty
        ? BigInt.zero
        : BigInt.parse(fractionText.padRight(18, '0'));
    final wei = whole * weiPerEth + fraction;
    if (wei <= BigInt.zero || wei > maxUint256) return null;
    return wei;
  }

  static String format(BigInt wei, {int maxFractionDigits = 18}) {
    if (wei < BigInt.zero || maxFractionDigits < 0 || maxFractionDigits > 18) {
      throw ArgumentError('Invalid wei amount or precision.');
    }
    final whole = wei ~/ weiPerEth;
    final fraction = (wei % weiPerEth)
        .toString()
        .padLeft(18, '0')
        .replaceFirst(RegExp(r'0+$'), '');
    if (fraction.isEmpty || maxFractionDigits == 0) return whole.toString();
    final visible = fraction.substring(
      0,
      fraction.length < maxFractionDigits ? fraction.length : maxFractionDigits,
    );
    return '$whole.$visible';
  }
}
