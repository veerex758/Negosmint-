import 'package:flutter_test/flutter_test.dart';
import 'package:negosmint_wallet/core/network/transaction_status.dart';

void main() {
  test('missing receipt means pending', () {
    expect(
      SepoliaTransactionStatusParser.parse(null),
      SepoliaTransactionStatus.pending,
    );
  });

  test('receipt status one means confirmed', () {
    expect(
      SepoliaTransactionStatusParser.parse({'status': '0x1'}),
      SepoliaTransactionStatus.confirmed,
    );
  });

  test('receipt status zero means failed', () {
    expect(
      SepoliaTransactionStatusParser.parse({'status': '0x0'}),
      SepoliaTransactionStatus.failed,
    );
  });

  test('unknown receipt status fails closed to pending', () {
    expect(
      SepoliaTransactionStatusParser.parse({'status': 'unknown'}),
      SepoliaTransactionStatus.pending,
    );
  });
}
