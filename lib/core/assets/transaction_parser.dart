import '../network/network_config.dart';

enum AssetTransferDirection { sent, received, self, unknown }

class ParsedAssetTransfer {
  final String transactionHash;
  final String tokenAddress;
  final String from;
  final String to;
  final BigInt rawAmount;
  final AssetTransferDirection direction;
  final int? blockNumber;
  final bool failed;

  const ParsedAssetTransfer({
    required this.transactionHash,
    required this.tokenAddress,
    required this.from,
    required this.to,
    required this.rawAmount,
    required this.direction,
    required this.blockNumber,
    required this.failed,
  });

  bool get isNative => tokenAddress.isEmpty;
}

class TransactionParser {
  static const transferTopic =
      '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef';

  /// Parses an RPC transaction and optional receipt. The parser never treats
  /// arbitrary contract calldata as a token transfer; ERC-20 transfers must
  /// be backed by a Transfer event emitted in the receipt.
  static List<ParsedAssetTransfer> parse({
    required Map<String, dynamic> transaction,
    Map<String, dynamic>? receipt,
    required String walletAddress,
  }) {
    final hash = transaction['hash'];
    final from = _address(transaction['from']);
    final to = _address(transaction['to']);
    final wallet = _address(walletAddress);
    if (hash is! String || from.isEmpty || wallet.isEmpty) {
      return const [];
    }

    final result = <ParsedAssetTransfer>[];
    final failed = receipt != null &&
        receipt['status'] is String &&
        _hexInt(receipt['status']) == 0;
    final value = _hexBigInt(transaction['value']);
    final input = transaction['input'];
    final nativeTransfer = to.isNotEmpty &&
        value > BigInt.zero &&
        (input == null || input == '0x');
    if (nativeTransfer) {
      result.add(ParsedAssetTransfer(
        transactionHash: hash,
        tokenAddress: '',
        from: from,
        to: to,
        rawAmount: value,
        direction: _direction(from, to, wallet),
        blockNumber: _hexInt(receipt?['blockNumber']),
        failed: failed,
      ));
    }

    final logs = receipt?['logs'];
    if (logs is List) {
      for (final item in logs) {
        if (item is! Map) continue;
        final topics = item['topics'];
        final data = item['data'];
        final contract = _address(item['address']);
        if (topics is! List ||
            topics.length < 3 ||
            topics[0]?.toString().toLowerCase() != transferTopic ||
            data is! String ||
            !RegExp(r'^0x[0-9a-fA-F]{64}$').hasMatch(data) ||
            contract.isEmpty) {
          continue;
        }
        final tokenFrom = _topicAddress(topics[1]);
        final tokenTo = _topicAddress(topics[2]);
        if (tokenFrom.isEmpty || tokenTo.isEmpty) continue;
        result.add(ParsedAssetTransfer(
          transactionHash: hash,
          tokenAddress: contract,
          from: tokenFrom,
          to: tokenTo,
          rawAmount: _hexBigInt(data),
          direction: _direction(tokenFrom, tokenTo, wallet),
          blockNumber: _hexInt(receipt?['blockNumber']),
          failed: failed,
        ));
      }
    }
    return result;
  }

  static AssetTransferDirection _direction(
      String from, String to, String wallet) {
    if (from == wallet && to == wallet) return AssetTransferDirection.self;
    if (from == wallet) return AssetTransferDirection.sent;
    if (to == wallet) return AssetTransferDirection.received;
    return AssetTransferDirection.unknown;
  }

  static String _topicAddress(dynamic topic) {
    if (topic is! String ||
        !RegExp(r'^0x[0-9a-fA-F]{64}$').hasMatch(topic)) {
      return '';
    }
    return '0x${topic.substring(topic.length - 40)}'.toLowerCase();
  }

  static String _address(dynamic value) {
    if (value is! String ||
        !RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(value)) {
      return '';
    }
    return value.toLowerCase();
  }

  static BigInt _hexBigInt(dynamic value) {
    if (value is! String ||
        !RegExp(r'^0x[0-9a-fA-F]+$').hasMatch(value)) {
      return BigInt.zero;
    }
    return BigInt.parse(value.substring(2), radix: 16);
  }

  static int? _hexInt(dynamic value) {
    final parsed = _hexBigInt(value);
    if (parsed > BigInt.from(0x7fffffffffffffff)) return null;
    return parsed.toInt();
  }
}

class ExplorerLinks {
  static String transaction(String hash) =>
      '${SupportedNetworks.sepolia.explorerUrl}/tx/${_validateHash(hash)}';

  static String address(String address) =>
      '${SupportedNetworks.sepolia.explorerUrl}/address/${_validateAddress(address)}';

  static String token(String address) =>
      '${SupportedNetworks.sepolia.explorerUrl}/token/${_validateAddress(address)}';

  static String _validateHash(String hash) {
    if (!RegExp(r'^0x[0-9a-fA-F]{64}$').hasMatch(hash)) {
      throw const FormatException('Invalid transaction hash.');
    }
    return hash;
  }

  static String _validateAddress(String address) {
    if (!RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(address)) {
      throw const FormatException('Invalid EVM address.');
    }
    return address;
  }
}
