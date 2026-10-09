import 'wallet_connection_request.dart';
import 'wallet_signing_request.dart';

/// Validates and normalizes an untrusted WalletConnect transaction payload.
///
/// This class is deliberately independent from Reown WalletKit so the
/// security boundary can be unit-tested without a live WalletConnect client.
class WalletConnectTransactionParseResult {
  final WalletSigningRequest signingRequest;
  final String? from;

  const WalletConnectTransactionParseResult({
    required this.signingRequest,
    required this.from,
  });
}

class WalletConnectTransactionParser {
  static const int sepoliaChainId = 11155111;
  static const String sepoliaCaip2 = 'eip155:11155111';
  static const String method = 'eth_sendTransaction';
  static const int maxDataLength = 100000;

  static WalletConnectTransactionParseResult parse({
    required String topic,
    required int id,
    required String chainId,
    required String methodName,
    required Object? params,
    required String appName,
  }) {
    if (chainId != sepoliaCaip2) {
      throw const WalletConnectionException(
        'Unsupported WalletConnect network.',
      );
    }
    if (methodName != method) {
      throw const WalletConnectionException(
        'Unsupported WalletConnect method.',
      );
    }
    if (params is! List || params.length != 1 || params.first is! Map) {
      throw const WalletConnectionException(
        'Malformed transaction parameters.',
      );
    }

    final tx = Map<String, dynamic>.from(params.first as Map);
    final to = _optionalString(tx['to']);
    final from = _optionalString(tx['from']);
    final value = _optionalString(tx['value']) ?? '0x0';
    final data = _optionalString(tx['data']) ?? '0x';

    if (to == null || !_isEvmAddress(to)) {
      throw const WalletConnectionException(
        'Invalid transaction recipient.',
      );
    }
    if (from != null && !_isEvmAddress(from)) {
      throw const WalletConnectionException(
        'Invalid transaction sender.',
      );
    }

    _validateHexQuantity(value, 'transaction value');
    _validateHexData(data);

    return WalletConnectTransactionParseResult(
      signingRequest: WalletSigningRequest(
        sessionId: topic,
        requestId: id.toString(),
        chainId: sepoliaChainId,
        to: to,
        value: value,
        data: data,
        actionDescription: 'Send transaction',
      ),
      from: from,
    );
  }

  static String? _optionalString(Object? value) {
    if (value == null) return null;
    if (value is! String || value.isEmpty) {
      throw const WalletConnectionException(
        'Transaction fields must be strings.',
      );
    }
    return value;
  }

  static bool _isEvmAddress(String value) =>
      RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(value);

  static void _validateHexQuantity(String value, String field) {
    // Ethereum transaction quantities are uint256 values. Bound the input
    // before BigInt parsing or RPC calls to reject oversized hostile payloads.
    if (!RegExp(r'^0x[0-9a-fA-F]+$').hasMatch(value) || value.length > 66) {
      throw WalletConnectionException('Invalid $field.');
    }
  }

  static void _validateHexData(String data) {
    if (data.length > maxDataLength) {
      throw const WalletConnectionException(
        'Transaction data is too large.',
      );
    }
    if (!RegExp(r'^0x[0-9a-fA-F]*$').hasMatch(data) ||
        (data.length - 2).isOdd) {
      throw const WalletConnectionException(
        'Invalid transaction data.',
      );
    }
  }
}
