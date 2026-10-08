import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'wallet_connection_codec.dart';
import 'wallet_connection_request.dart';
import 'wallet_connection_result.dart';
import 'wallet_connection_transport.dart';
import 'wallet_signing_result.dart';

/// HTTPS callback transport for response delivery.
///
/// Requests are still received through the wallet's deep-link/QR transport.
/// When a request contains an HTTPS callback, this transport sends the
/// response as a JSON POST body instead of putting response data in a URL.
/// That keeps signed transaction payloads out of URL query strings, browser
/// history, and common URL logging paths.
class HttpsWalletConnectionCallbackTransport
    implements WalletConnectionTransport {
  final http.Client _client;
  final Map<String, Uri> _callbacks = {};

  HttpsWalletConnectionCallbackTransport({http.Client? client})
      : _client = client ?? http.Client();

  @override
  Future<WalletConnectionRequest> receive(String payload) async {
    final request = WalletConnectionCodec.parseRequest(payload);
    register(request);
    return request;
  }

  /// Registers a validated request for a later response.
  void register(WalletConnectionRequest request) {
    final callback = request.callback;
    if (callback == null) return;

    final uri = Uri.tryParse(callback);
    if (uri == null || uri.scheme.toLowerCase() != 'https') {
      throw const WalletConnectionException(
        'Only HTTPS callbacks are supported for response delivery.',
      );
    }
    if (_callbacks.containsKey(request.requestId)) {
      throw const WalletConnectionException(
        'A response callback is already registered for this request.',
      );
    }
    if (_callbacks.length >= 32) {
      throw const WalletConnectionException(
        'Too many pending wallet response callbacks.',
      );
    }
    _callbacks[request.requestId] = uri;
  }

  @override
  Future<void> send(WalletConnectionResult result) =>
      _post(result.requestId, result.toJson());

  @override
  Future<void> sendSigningResult(WalletSigningResult result) =>
      _post(result.requestId, result.toJson());

  Future<void> _post(String requestId, Map<String, dynamic> body) async {
    final callback = _callbacks[requestId];
    if (callback == null) {
      throw const WalletConnectionException(
        'No HTTPS response callback is registered for this request.',
      );
    }

    final request = http.Request('POST', callback)
      ..followRedirects = false
      ..maxRedirects = 0
      ..headers['content-type'] = 'application/json'
      ..headers['accept'] = 'application/json'
      ..headers['x-negosmint-request-id'] = requestId
      ..body = jsonEncode(body);

    try {
      final response =
          await _client.send(request).timeout(const Duration(seconds: 10));
      await response.stream.drain();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw WalletConnectionException(
          'Response callback failed with HTTP ${response.statusCode}.',
        );
      }
      _callbacks.remove(requestId);
    } on TimeoutException {
      throw const WalletConnectionException(
        'Response callback timed out.',
      );
    }
  }

  void dispose() {
    _callbacks.clear();
    _client.close();
  }
}
