/// A validated request to receive/send native ETH on the wallet's supported network.
class PaymentRequest {
  final String address;
  final int chainId;
  final BigInt? amountWei;

  const PaymentRequest({
    required this.address,
    required this.chainId,
    this.amountWei,
  });
}

class PaymentUriException implements Exception {
  final String message;
  const PaymentUriException(this.message);

  @override
  String toString() => message;
}

/// Parses a plain EVM address or a limited, native-ETH EIP-681 URI.
///
/// Token-transfer paths, unknown query parameters, unsupported chains, and
/// amounts with more precision than ETH supports are deliberately rejected.
class PaymentUriParser {
  static const int sepoliaChainId = 11155111;
  static const int _weiDecimals = 18;
  static final RegExp _addressPattern = RegExp(r'^0x[0-9a-fA-F]{40}$');
  static final RegExp _uriPattern = RegExp(
    r'^ethereum:(0x[0-9a-fA-F]{40})(?:@([0-9]+))?(?:\?(.+))?$',
    caseSensitive: false,
  );

  static bool isValidAddress(String value) =>
      _addressPattern.hasMatch(value.trim());

  /// Encodes the supported network into a receive QR payload.
  static String createSepoliaUri(String address) {
    final normalized = address.trim();
    if (!isValidAddress(normalized)) {
      throw const PaymentUriException('Invalid wallet address.');
    }
    return 'ethereum:$normalized@$sepoliaChainId';
  }

  static PaymentRequest parse(String input) {
    final value = input.trim();
    if (value.isEmpty) {
      throw const PaymentUriException('The QR code is empty.');
    }
    if (value.length > 2048) {
      throw const PaymentUriException('The QR payload is too large.');
    }

    if (isValidAddress(value)) {
      return PaymentRequest(
        address: value,
        chainId: sepoliaChainId,
      );
    }

    final match = _uriPattern.firstMatch(value);
    if (match == null) {
      throw const PaymentUriException(
        'Unsupported QR code. Scan an EVM address or Ethereum payment URI.',
      );
    }

    final address = match.group(1)!;
    final chainText = match.group(2);
    final chainId =
        chainText == null ? sepoliaChainId : int.tryParse(chainText);
    if (chainId != sepoliaChainId) {
      throw const PaymentUriException(
        'This payment request is for an unsupported network. Use Ethereum Sepolia.',
      );
    }

    BigInt? amountWei;
    final rawQuery = match.group(3);
    if (rawQuery != null) {
      final parameters = Uri(query: rawQuery).queryParametersAll;
      if (parameters.keys.any((key) => key != 'value') ||
          parameters.length != 1 ||
          parameters['value']?.length != 1) {
        throw const PaymentUriException(
          'The payment URI contains unsupported or duplicate parameters.',
        );
      }
      amountWei = _parseEthAmount(parameters['value']!.single);
    }

    return PaymentRequest(
      address: address,
      chainId: chainId!,
      amountWei: amountWei,
    );
  }

  static BigInt _parseEthAmount(String value) {
    if (!RegExp(r'^\d+(?:\.\d{1,18})?$').hasMatch(value)) {
      throw const PaymentUriException('The requested ETH amount is invalid.');
    }

    final parts = value.split('.');
    final whole = BigInt.tryParse(parts.first);
    if (whole == null) {
      throw const PaymentUriException('The requested ETH amount is invalid.');
    }
    final fraction = parts.length == 2 ? parts[1] : '';
    final paddedFraction = fraction.padRight(_weiDecimals, '0');
    final wei = whole * BigInt.from(10).pow(_weiDecimals) +
        BigInt.parse(paddedFraction);
    if (wei <= BigInt.zero) {
      throw const PaymentUriException(
        'The requested ETH amount must be greater than zero.',
      );
    }
    return wei;
  }
}
