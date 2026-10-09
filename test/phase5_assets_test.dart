import 'package:flutter_test/flutter_test.dart';
import 'package:negosmint_wallet/core/assets/erc20_asset_service.dart';
import 'package:negosmint_wallet/core/assets/transaction_parser.dart';

void main() {
  group('ERC-20 unit formatting', () {
    test('formats values using token decimals without floating point', () {
      expect(Erc20Asset.formatUnits(BigInt.from(1234567), 6), '1.234567');
      expect(Erc20Asset.formatUnits(BigInt.from(1000000), 6), '1');
      expect(Erc20Asset.formatUnits(BigInt.from(123456789), 8), '1.234567');
      expect(Erc20Asset.formatUnits(BigInt.from(42), 0), '42');
      expect(Erc20Asset.formatUnits(BigInt.from(1), 18), '<0.000001');
    });

    test('rejects impossible decimal counts', () {
      expect(() => Erc20Asset.formatUnits(BigInt.one, 256),
          throwsArgumentError);
    });
  });

  group('TransactionParser', () {
    const wallet = '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const other = '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    const token = '0xcccccccccccccccccccccccccccccccccccccccc';
    const hash =
        '0xdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

    String topic(String address) => '0x${address.substring(2).padLeft(64, '0')}';

    test('parses a native ETH transfer and direction', () {
      final parsed = TransactionParser.parse(
        walletAddress: wallet,
        transaction: {
          'hash': hash,
          'from': wallet,
          'to': other,
          'value': '0xde0b6b3a7640000',
          'input': '0x',
        },
        receipt: {'status': '0x1', 'blockNumber': '0x10', 'logs': []},
      );
      expect(parsed, hasLength(1));
      expect(parsed.single.isNative, isTrue);
      expect(parsed.single.rawAmount, BigInt.from(1000000000000000000));
      expect(parsed.single.direction, AssetTransferDirection.sent);
      expect(parsed.single.blockNumber, 16);
      expect(parsed.single.failed, isFalse);
    });

    test('parses ERC-20 Transfer event from receipt logs', () {
      final parsed = TransactionParser.parse(
        walletAddress: wallet,
        transaction: {
          'hash': hash,
          'from': other,
          'to': token,
          'value': '0x0',
          'input': '0xa9059cbb',
        },
        receipt: {
          'status': '0x1',
          'blockNumber': '0x20',
          'logs': [
            {
              'address': token,
              'topics': [
                TransactionParser.transferTopic,
                topic(other),
                topic(wallet),
              ],
              'data': '0x${BigInt.from(2500000).toRadixString(16).padLeft(64, '0')}',
            }
          ],
        },
      );
      expect(parsed, hasLength(1));
      expect(parsed.single.isNative, isFalse);
      expect(parsed.single.tokenAddress, token);
      expect(parsed.single.rawAmount, BigInt.from(2500000));
      expect(parsed.single.direction, AssetTransferDirection.received);
    });

    test('marks reverted receipts as failed', () {
      final parsed = TransactionParser.parse(
        walletAddress: wallet,
        transaction: {
          'hash': hash,
          'from': wallet,
          'to': other,
          'value': '0x1',
          'input': '0x',
        },
        receipt: {'status': '0x0', 'blockNumber': '0x11', 'logs': []},
      );
      expect(parsed.single.failed, isTrue);
    });

    test('ignores malformed logs and missing transaction hashes', () {
      final malformed = TransactionParser.parse(
        walletAddress: wallet,
        transaction: {
          'from': wallet,
          'to': other,
          'value': '0x1',
          'input': '0x',
        },
      );
      expect(malformed, isEmpty);
    });
  });

  group('ExplorerLinks', () {
    test('builds Sepolia explorer URLs', () {
      expect(
        ExplorerLinks.transaction(
          '0x${'a' * 64}',
        ),
        'https://sepolia.etherscan.io/tx/0x${'a' * 64}',
      );
      expect(
        ExplorerLinks.address('0x${'b' * 40}'),
        'https://sepolia.etherscan.io/address/0x${'b' * 40}',
      );
      expect(
        ExplorerLinks.token('0x${'c' * 40}'),
        'https://sepolia.etherscan.io/token/0x${'c' * 40}',
      );
    });

    test('rejects malformed hashes and addresses', () {
      expect(() => ExplorerLinks.transaction('0x123'), throwsFormatException);
      expect(() => ExplorerLinks.address('not-an-address'),
          throwsFormatException);
    });
  });
}
