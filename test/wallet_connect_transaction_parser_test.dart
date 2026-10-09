import 'package:flutter_test/flutter_test.dart';
import 'package:negosmint_wallet/wallet/connection/wallet_connect_bridge.dart';
import 'package:negosmint_wallet/wallet/connection/wallet_connect_transaction_parser.dart';
import 'package:negosmint_wallet/wallet/connection/wallet_connection_request.dart';

void main() {
  const validTo = '0x2222222222222222222222222222222222222222';
  const validFrom = '0x1111111111111111111111111111111111111111';

  Object validParams({
    String to = validTo,
    String from = validFrom,
    String value = '0x01',
    String data = '0x',
  }) =>
      [
        <String, dynamic>{
          'to': to,
          'from': from,
          'value': value,
          'data': data,
        },
      ];

  test('normalizes a valid Sepolia eth_sendTransaction request', () {
    final parsed = WalletConnectTransactionParser.parse(
      topic: 'topic-1',
      id: 42,
      chainId: WalletConnectTransactionParser.sepoliaCaip2,
      methodName: WalletConnectTransactionParser.method,
      params: validParams(),
      appName: 'Example dApp',
    );

    expect(parsed.from, validFrom);
    expect(parsed.signingRequest.to, validTo);
    expect(parsed.signingRequest.value, '0x01');
    expect(parsed.signingRequest.data, '0x');
    expect(parsed.signingRequest.chainId, 11155111);
    expect(parsed.signingRequest.sessionId, 'topic-1');
    expect(parsed.signingRequest.requestId, '42');
  });

  test('defaults omitted value and calldata safely', () {
    final parsed = WalletConnectTransactionParser.parse(
      topic: 'topic-2',
      id: 7,
      chainId: WalletConnectTransactionParser.sepoliaCaip2,
      methodName: WalletConnectTransactionParser.method,
      params: [
        <String, dynamic>{'to': validTo},
      ],
      appName: 'Example dApp',
    );

    expect(parsed.signingRequest.value, '0x0');
    expect(parsed.signingRequest.data, '0x');
  });

  test('rejects a non-Sepolia chain', () {
    expect(
      () => WalletConnectTransactionParser.parse(
        topic: 'topic',
        id: 1,
        chainId: 'eip155:1',
        methodName: WalletConnectTransactionParser.method,
        params: validParams(),
        appName: 'Example dApp',
      ),
      throwsA(isA<WalletConnectionException>()),
    );
  });

  test('rejects unsupported methods', () {
    expect(
      () => WalletConnectTransactionParser.parse(
        topic: 'topic',
        id: 1,
        chainId: WalletConnectTransactionParser.sepoliaCaip2,
        methodName: 'personal_sign',
        params: validParams(),
        appName: 'Example dApp',
      ),
      throwsA(isA<WalletConnectionException>()),
    );
  });

  test('rejects malformed transaction parameters', () {
    final malformed = <Object?>[
      null,
      <Object?>[],
      [<String, dynamic>{}, <String, dynamic>{}],
      [42],
    ];

    for (final params in malformed) {
      expect(
        () => WalletConnectTransactionParser.parse(
          topic: 'topic',
          id: 1,
          chainId: WalletConnectTransactionParser.sepoliaCaip2,
          methodName: WalletConnectTransactionParser.method,
          params: params,
          appName: 'Example dApp',
        ),
        throwsA(isA<WalletConnectionException>()),
      );
    }
  });

  test('rejects invalid sender and recipient addresses', () {
    expect(
      () => WalletConnectTransactionParser.parse(
        topic: 'topic',
        id: 1,
        chainId: WalletConnectTransactionParser.sepoliaCaip2,
        methodName: WalletConnectTransactionParser.method,
        params: validParams(from: '0x1234'),
        appName: 'Example dApp',
      ),
      throwsA(isA<WalletConnectionException>()),
    );

    expect(
      () => WalletConnectTransactionParser.parse(
        topic: 'topic',
        id: 2,
        chainId: WalletConnectTransactionParser.sepoliaCaip2,
        methodName: WalletConnectTransactionParser.method,
        params: validParams(to: 'not-an-address'),
        appName: 'Example dApp',
      ),
      throwsA(isA<WalletConnectionException>()),
    );
  });

  test('rejects invalid value encodings', () {
    for (final value in ['1', '0x', '0xgg', '-0x01']) {
      expect(
        () => WalletConnectTransactionParser.parse(
          topic: 'topic',
          id: 1,
          chainId: WalletConnectTransactionParser.sepoliaCaip2,
          methodName: WalletConnectTransactionParser.method,
          params: validParams(value: value),
          appName: 'Example dApp',
        ),
        throwsA(isA<WalletConnectionException>()),
      );
    }
  });

  test('rejects malformed and oversized calldata', () {
    expect(
      () => WalletConnectTransactionParser.parse(
        topic: 'topic',
        id: 1,
        chainId: WalletConnectTransactionParser.sepoliaCaip2,
        methodName: WalletConnectTransactionParser.method,
        params: validParams(data: '0xabc'),
        appName: 'Example dApp',
      ),
      throwsA(isA<WalletConnectionException>()),
    );

    expect(
      () => WalletConnectTransactionParser.parse(
        topic: 'topic',
        id: 2,
        chainId: WalletConnectTransactionParser.sepoliaCaip2,
        methodName: WalletConnectTransactionParser.method,
        params: validParams(data: '0xNaNaa'),
        appName: 'Example dApp',
      ),
      throwsA(isA<WalletConnectionException>()),
    );
  });

  test('does not carry wallet secrets in normalized requests', () {
    final parsed = WalletConnectTransactionParser.parse(
      topic: 'topic',
      id: 99,
      chainId: WalletConnectTransactionParser.sepoliaCaip2,
      methodName: WalletConnectTransactionParser.method,
      params: validParams(),
      appName: 'Example dApp',
    );

    final text = '${parsed.signingRequest.to}\n${parsed.signingRequest.value}\n${parsed.signingRequest.data}\n${parsed.from}';
    expect(text, isNot(contains('mnemonic')));
    expect(text, isNot(contains('privateKey')));
    expect(text, isNot(contains('seed')));
    expect(text, isNot(contains('pin')));
  });


  test('rejects empty transaction quantity', () {
    expect(
      () => WalletConnectTransactionParser.parse(
        topic: 'topic',
        id: 3,
        chainId: WalletConnectTransactionParser.sepoliaCaip2,
        methodName: WalletConnectTransactionParser.method,
        params: validParams(value: '0x'),
        appName: 'Example dApp',
      ),
      throwsA(isA<WalletConnectionException>()),
    );
  });

  test('accepts large valid hex quantity without parsing it', () {
    final parsed = WalletConnectTransactionParser.parse(
      topic: 'topic',
      id: 4,
      chainId: WalletConnectTransactionParser.sepoliaCaip2,
      methodName: WalletConnectTransactionParser.method,
      params: validParams(value: '0x${'f' * 64}'),
      appName: 'Example dApp',
    );
    expect(parsed.signingRequest.value, '0x${'f' * 64}');
  });

  test('proposal signing detection identifies transaction requests', () {
    final proposal = WalletConnectProposal(
      id: 1,
      appName: 'Example dApp',
      appDescription: 'Test',
      appUrl: 'https://example.com',
      pairingTopic: 'pairing-topic',
      requiredChains: const ['eip155:11155111'],
      requiredMethods: const ['eth_chainId', 'eth_sendTransaction'],
      requiredEvents: const ['accountsChanged'],
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
    );

    expect(proposal.requestsSigning, isTrue);
    expect(proposal.isExpired, isFalse);
  });

  test('expired proposal is detected', () {
    final proposal = WalletConnectProposal(
      id: 2,
      appName: 'Example dApp',
      appDescription: 'Test',
      appUrl: 'https://example.com',
      pairingTopic: 'pairing-topic',
      requiredChains: const ['eip155:11155111'],
      requiredMethods: const ['eth_chainId'],
      requiredEvents: const ['accountsChanged'],
      expiresAt: DateTime.now().toUtc().subtract(const Duration(seconds: 1)),
    );

    expect(proposal.isExpired, isTrue);
    expect(proposal.requestsSigning, isFalse);
  });
}
