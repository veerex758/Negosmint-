import 'package:flutter_test/flutter_test.dart';
import 'package:negosmint_wallet/core/wallet/payment_uri.dart';

void main() {
  const address = '0x1111111111111111111111111111111111111111';

  test('accepts a plain EVM address as a Sepolia recipient', () {
    final request = PaymentUriParser.parse(address);
    expect(request.address, address);
    expect(request.chainId, PaymentUriParser.sepoliaChainId);
    expect(request.amountWei, isNull);
  });

  test('builds and parses a network-labelled Sepolia URI', () {
    final uri = PaymentUriParser.createSepoliaUri(address);
    expect(uri, 'ethereum:$address@11155111');
    final request = PaymentUriParser.parse(uri);
    expect(request.address, address);
    expect(request.chainId, 11155111);
    expect(request.amountWei, isNull);
  });

  test('parses an exact ETH amount from a payment URI', () {
    final request = PaymentUriParser.parse(
      'ethereum:$address@11155111?value=1.000000000000000001',
    );
    expect(request.amountWei, BigInt.from(1000000000000000001));
  });

  test('accepts a URI without explicit chain ID as Sepolia-only input', () {
    final request = PaymentUriParser.parse('ethereum:$address?value=0.25');
    expect(request.chainId, 11155111);
    expect(request.amountWei, BigInt.from(250000000000000000));
  });

  test('rejects a mainnet or otherwise unsupported chain', () {
    expect(
      () => PaymentUriParser.parse('ethereum:$address@1'),
      throwsA(isA<PaymentUriException>()),
    );
  });

  test('rejects malformed addresses and unsupported URI schemes', () {
    for (final payload in [
      '0x1234',
      'https://example.com/$address',
      'bitcoin:$address',
      'ethereum:0x1234@11155111',
    ]) {
      expect(
        () => PaymentUriParser.parse(payload),
        throwsA(isA<PaymentUriException>()),
      );
    }
  });

  test('rejects contract transfer paths and unknown parameters', () {
    expect(
      () => PaymentUriParser.parse('ethereum:$address@11155111/transfer?value=1'),
      throwsA(isA<PaymentUriException>()),
    );
    expect(
      () => PaymentUriParser.parse('ethereum:$address@11155111?gas=21000'),
      throwsA(isA<PaymentUriException>()),
    );
  });

  test('rejects duplicate, zero, negative, exponent, and over-precision amounts', () {
    for (final payload in [
      'ethereum:$address?value=1&value=2',
      'ethereum:$address?value=0',
      'ethereum:$address?value=-1',
      'ethereum:$address?value=1e-3',
      'ethereum:$address?value=0.0000000000000000001',
    ]) {
      expect(
        () => PaymentUriParser.parse(payload),
        throwsA(isA<PaymentUriException>()),
      );
    }
  });

  test('rejects oversized QR payloads', () {
    expect(
      () => PaymentUriParser.parse(List.filled(2049, 'x').join()),
      throwsA(isA<PaymentUriException>()),
    );
  });

  test('rejects invalid addresses when creating a receive URI', () {
    expect(
      () => PaymentUriParser.createSepoliaUri('0x1234'),
      throwsA(isA<PaymentUriException>()),
    );
  });
}
