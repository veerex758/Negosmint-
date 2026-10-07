import 'dart:convert';
import 'wallet_connection_request.dart';
import 'wallet_connection_result.dart';

class WalletConnectionCodec {
  static const scheme = 'negosmintwallet';

  static WalletConnectionRequest parseRequest(String payload) {
    if (payload.length > 8192) {
      throw const WalletConnectionException('Connection payload is too large.');
    }

    final trimmed = payload.trim();
    if (trimmed.startsWith('$scheme://connect')) {
      final uri = Uri.tryParse(trimmed);
      if (uri == null || uri.host != 'connect') {
        throw const WalletConnectionException('Malformed NegosMint connection link.');
      }
      final data = uri.queryParameters['request'];
      if (data == null || data.isEmpty) {
        throw const WalletConnectionException('Connection request is missing.');
      }
      try {
        return WalletConnectionRequest.fromJson(
          Map<String, dynamic>.from(jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(data))))),
        );
      } catch (_) {
        throw const WalletConnectionException('Malformed connection request.');
      }
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map<String, dynamic>) {
        throw const WalletConnectionException('QR payload must be a JSON object.');
      }
      return WalletConnectionRequest.fromJson(decoded);
    } catch (_) {
      throw const WalletConnectionException('Malformed QR connection request.');
    }
  }

  static String encodeRequest(WalletConnectionRequest request) {
    final bytes = utf8.encode(jsonEncode(request.toJson()));
    final encoded = base64UrlEncode(bytes).replaceAll('=', '');
    return Uri(
      scheme: scheme,
      host: 'connect',
      queryParameters: {'request': encoded},
    ).toString();
  }

  static String encodeResult(WalletConnectionResult result) =>
      jsonEncode(result.toJson());
}
