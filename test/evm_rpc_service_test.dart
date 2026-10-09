import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:negosmint_wallet/core/network/evm_rpc_service.dart';

void main() {
  group('EvmRpcService testnet failure handling', () {
    late HttpServer server;
    late StreamSubscription<HttpRequest> subscription;

    Future<void> respond(
      HttpRequest request, {
      required String body,
      int statusCode = HttpStatus.ok,
    }) async {
      request.response.statusCode = statusCode;
      request.response.headers.contentType = ContentType.json;
      request.response.write(body);
      await request.response.close();
    }

    Future<void> startServer(
      Future<void> Function(HttpRequest request) handler,
    ) async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      subscription = server.listen(handler);
    }

    tearDown(() async {
      await subscription.cancel();
      await server.close(force: true);
    });

    test('parses the Sepolia chain ID from a valid JSON-RPC response', () async {
      await startServer((request) async {
        final raw = await utf8.decoder.bind(request).join();
        final payload = jsonDecode(raw) as Map<String, dynamic>;
        expect(payload['method'], 'eth_chainId');
        await respond(
          request,
          body: jsonEncode({
            'jsonrpc': '2.0',
            'id': payload['id'],
            'result': '0xaa36a7',
          }),
        );
      });

      final service = EvmRpcService(endpoint: 'http://127.0.0.1:${server.port}');
      expect(await service.getChainId(), EvmRpcService.chainId);
    });

    test('rejects a response with a mismatched request ID', () async {
      await startServer((request) async {
        await utf8.decoder.bind(request).join();
        await respond(
          request,
          body: jsonEncode({
            'jsonrpc': '2.0',
            'id': -1,
            'result': '0xaa36a7',
          }),
        );
      });

      final service = EvmRpcService(endpoint: 'http://127.0.0.1:${server.port}');
      await expectLater(
        service.getChainId(),
        throwsA(
          isA<EvmRpcException>().having(
            (error) => error.message,
            'message',
            'RPC response does not match the request.',
          ),
        ),
      );
    });

    test('surfaces JSON-RPC error messages', () async {
      await startServer((request) async {
        final raw = await utf8.decoder.bind(request).join();
        final payload = jsonDecode(raw) as Map<String, dynamic>;
        await respond(
          request,
          body: jsonEncode({
            'jsonrpc': '2.0',
            'id': payload['id'],
            'error': {'code': -32000, 'message': 'upstream unavailable'},
          }),
        );
      });

      final service = EvmRpcService(endpoint: 'http://127.0.0.1:${server.port}');
      await expectLater(
        service.getChainId(),
        throwsA(
          isA<EvmRpcException>().having(
            (error) => error.message,
            'message',
            'upstream unavailable',
          ),
        ),
      );
    });

    test('reports HTTP gateway failures', () async {
      await startServer((request) async {
        await respond(
          request,
          body: '{"error":"maintenance"}',
          statusCode: HttpStatus.serviceUnavailable,
        );
      });

      final service = EvmRpcService(endpoint: 'http://127.0.0.1:${server.port}');
      await expectLater(
        service.getChainId(),
        throwsA(
          isA<EvmRpcException>().having(
            (error) => error.message,
            'message',
            'RPC returned HTTP 503.',
          ),
        ),
      );
    });

    test('converts a network outage into a stable RPC exception', () async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final endpoint = 'http://127.0.0.1:${server.port}';
      subscription = server.listen((request) async {
        await request.response.close();
      });
      await subscription.cancel();
      await server.close(force: true);

      final service = EvmRpcService(endpoint: endpoint);
      await expectLater(
        service.getChainId(),
        throwsA(
          isA<EvmRpcException>().having(
            (error) => error.message,
            'message',
            'Unable to reach the Sepolia network.',
          ),
        ),
      );
    });

    test('times out when the RPC response body stalls', () async {
      await startServer((request) async {
        await utf8.decoder.bind(request).join();
        await Future<void>.delayed(const Duration(milliseconds: 150));
        try {
          await respond(
            request,
            body: jsonEncode({'jsonrpc': '2.0', 'id': 1, 'result': '0xaa36a7'}),
          );
        } on HttpException {
          // The client has already timed out and closed the connection.
        } on SocketException {
          // The client has already timed out and closed the connection.
        }
      });

      final service = EvmRpcService(
        endpoint: 'http://127.0.0.1:${server.port}',
        requestTimeout: const Duration(milliseconds: 20),
      );
      await expectLater(
        service.getChainId(),
        throwsA(
          isA<EvmRpcException>().having(
            (error) => error.message,
            'message',
            'Sepolia network request timed out.',
          ),
        ),
      );
    });

    test('reports malformed JSON and missing result fields', () async {
      await startServer((request) async {
        await respond(request, body: 'not-json');
      });
      final malformed = EvmRpcService(
        endpoint: 'http://127.0.0.1:${server.port}',
      );
      await expectLater(
        malformed.getChainId(),
        throwsA(
          isA<EvmRpcException>().having(
            (error) => error.message,
            'message',
            'RPC returned invalid JSON.',
          ),
        ),
      );

      await subscription.cancel();
      await server.close(force: true);
      await startServer((request) async {
        final raw = await utf8.decoder.bind(request).join();
        final payload = jsonDecode(raw) as Map<String, dynamic>;
        await respond(
          request,
          body: jsonEncode({'jsonrpc': '2.0', 'id': payload['id']}),
        );
      });
      final missingResult = EvmRpcService(
        endpoint: 'http://127.0.0.1:${server.port}',
      );
      await expectLater(
        missingResult.getChainId(),
        throwsA(
          isA<EvmRpcException>().having(
            (error) => error.message,
            'message',
            'RPC response has no result.',
          ),
        ),
      );
    });
  });
}
