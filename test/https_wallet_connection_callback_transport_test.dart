import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:negosmint_wallet/core/network/network_config.dart';
import 'package:negosmint_wallet/wallet/connection/https_wallet_connection_callback_transport.dart';
import 'package:negosmint_wallet/wallet/connection/wallet_connection_request.dart';
import 'package:negosmint_wallet/wallet/connection/wallet_connection_result.dart';
import 'package:negosmint_wallet/wallet/connection/wallet_signing_result.dart';

class FakeHttpClient extends http.BaseClient {
  http.BaseRequest? lastRequest;
  int statusCode = 200;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastRequest = request;
    return http.StreamedResponse(
      const Stream<List<int>>.empty(),
      statusCode,
      request: request,
    );
  }
}

WalletConnectionRequest callbackRequest({
  String id = 'callback-1',
  String callback = 'https://task.example/wallet/callback',
}) =>
    WalletConnectionRequest(
      requestId: id,
      appName: 'NegosMint Task Platform',
      appIdentifier: 'com.negosmint.taskplatform',
      permissions: const [
        WalletConnectionPermission.readAddress,
        WalletConnectionPermission.readNetwork,
      ],
      chainId: SupportedNetworks.sepolia.chainId,
      callback: callback,
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
    );

void main() {
  test('HTTPS callback transport posts connection results in the body',
      () async {
    final client = FakeHttpClient();
    final transport = HttpsWalletConnectionCallbackTransport(client: client);
    final request = callbackRequest();

    await transport.receive(
      jsonEncode(request.toJson()),
    );

    final result = WalletConnectionResult.rejected(
      requestId: request.requestId,
    );
    await transport.send(result);

    expect(client.lastRequest, isNotNull);
    expect(client.lastRequest!.url.toString(),
        'https://task.example/wallet/callback');
    expect(client.lastRequest!.headers['content-type'], 'application/json');
    expect(client.lastRequest!.headers['x-negosmint-request-id'],
        request.requestId);
    final body = (client.lastRequest! as http.Request).body;
    expect(body, contains('"requestId":"callback-1"'));
    expect(body, contains('"status":"rejected"'));
    expect(body, isNot(contains('privateKey')));
    expect(body, isNot(contains('mnemonic')));

    transport.dispose();
  });

  test('callback transport never follows redirects', () async {
    final client = FakeHttpClient();
    final transport = HttpsWalletConnectionCallbackTransport(client: client);

    await transport.receive(jsonEncode(callbackRequest().toJson()));
    await transport.sendSigningResult(
      WalletSigningResult.rejected(requestId: 'callback-1'),
    );

    final request = client.lastRequest! as http.Request;
    expect(request.followRedirects, isFalse);
    expect(request.maxRedirects, 0);

    transport.dispose();
  });

  test('callback transport rejects missing callback registrations', () async {
    final client = FakeHttpClient();
    final transport = HttpsWalletConnectionCallbackTransport(client: client);

    expect(
      () => transport.send(
        WalletConnectionResult.rejected(requestId: 'unknown-request'),
      ),
      throwsA(isA<WalletConnectionException>()),
    );

    transport.dispose();
  });

  test('callback transport rejects non-HTTPS callbacks', () async {
    final client = FakeHttpClient();
    final transport = HttpsWalletConnectionCallbackTransport(client: client);

    final request = callbackRequest(callback: 'negosmint://callback');
    expect(
      () => transport.receive(jsonEncode(request.toJson())),
      throwsA(isA<WalletConnectionException>()),
    );

    transport.dispose();
  });

  test('successful callback delivery removes the request registration',
      () async {
    final client = FakeHttpClient();
    final transport = HttpsWalletConnectionCallbackTransport(client: client);
    final request = callbackRequest();

    await transport.receive(jsonEncode(request.toJson()));
    await transport.send(
      WalletConnectionResult.rejected(requestId: request.requestId),
    );

    expect(
      () => transport.send(
        WalletConnectionResult.rejected(requestId: request.requestId),
      ),
      throwsA(isA<WalletConnectionException>()),
    );

    transport.dispose();
  });

  test('failed callback delivery keeps registration available for retry',
      () async {
    final client = FakeHttpClient()..statusCode = 503;
    final transport = HttpsWalletConnectionCallbackTransport(client: client);
    final request = callbackRequest();

    await transport.receive(jsonEncode(request.toJson()));

    expect(
      () => transport.send(
        WalletConnectionResult.rejected(requestId: request.requestId),
      ),
      throwsA(isA<WalletConnectionException>()),
    );

    client.statusCode = 200;
    await transport.send(
      WalletConnectionResult.rejected(requestId: request.requestId),
    );

    transport.dispose();
  });
}
