import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../network/network_config.dart';

class IndexedTokenTransfer {
  final String transactionHash;
  final String tokenAddress;
  final String from;
  final String to;
  final BigInt rawAmount;
  final int blockNumber;
  final int logIndex;

  const IndexedTokenTransfer({
    required this.transactionHash,
    required this.tokenAddress,
    required this.from,
    required this.to,
    required this.rawAmount,
    required this.blockNumber,
    required this.logIndex,
  });

  bool involves(String wallet) =>
      from.toLowerCase() == wallet.toLowerCase() ||
      to.toLowerCase() == wallet.toLowerCase();

  Map<String, dynamic> toJson() => {
        'hash': transactionHash,
        'token': tokenAddress,
        'from': from,
        'to': to,
        'amount': rawAmount.toString(),
        'block': blockNumber,
        'logIndex': logIndex,
      };

  static IndexedTokenTransfer? fromLog(Map<String, dynamic> log) {
    final address = log['address'];
    final hash = log['transactionHash'];
    final topics = log['topics'];
    final data = log['data'];
    final block = _parseHexInt(log['blockNumber']);
    final logIndex = _parseHexInt(log['logIndex']);
    if (address is! String ||
        !_addressPattern.hasMatch(address) ||
        hash is! String ||
        !_hashPattern.hasMatch(hash) ||
        topics is! List ||
        topics.length < 3 ||
        topics[0]?.toString().toLowerCase() != transferTopic ||
        data is! String ||
        !RegExp(r'^0x[0-9a-fA-F]{64}$').hasMatch(data) ||
        block == null ||
        logIndex == null) {
      return null;
    }
    final from = _topicAddress(topics[1]);
    final to = _topicAddress(topics[2]);
    if (from == null || to == null) return null;
    return IndexedTokenTransfer(
      transactionHash: hash.toLowerCase(),
      tokenAddress: address.toLowerCase(),
      from: from,
      to: to,
      rawAmount: BigInt.parse(data.substring(2), radix: 16),
      blockNumber: block,
      logIndex: logIndex,
    );
  }

  static IndexedTokenTransfer? fromJson(dynamic value) {
    if (value is! Map<String, dynamic>) return null;
    final hash = value['hash'];
    final token = value['token'];
    final from = value['from'];
    final to = value['to'];
    final amount = value['amount'];
    final block = value['block'];
    final logIndex = value['logIndex'];
    if (hash is! String ||
        !_hashPattern.hasMatch(hash) ||
        token is! String ||
        !_addressPattern.hasMatch(token) ||
        from is! String ||
        !_addressPattern.hasMatch(from) ||
        to is! String ||
        !_addressPattern.hasMatch(to) ||
        amount is! String ||
        !RegExp(r'^[0-9]+$').hasMatch(amount) ||
        block is! int ||
        logIndex is! int ||
        block < 0 ||
        logIndex < 0) {
      return null;
    }
    return IndexedTokenTransfer(
      transactionHash: hash.toLowerCase(),
      tokenAddress: token.toLowerCase(),
      from: from.toLowerCase(),
      to: to.toLowerCase(),
      rawAmount: BigInt.parse(amount),
      blockNumber: block,
      logIndex: logIndex,
    );
  }

  static const transferTopic =
      '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef';
  static final _addressPattern = RegExp(r'^0x[0-9a-fA-F]{40}$');
  static final _hashPattern = RegExp(r'^0x[0-9a-fA-F]{64}$');

  static String? _topicAddress(dynamic topic) {
    if (topic is! String ||
        !RegExp(r'^0x[0-9a-fA-F]{64}$').hasMatch(topic)) {
      return null;
    }
    return '0x${topic.substring(topic.length - 40)}'.toLowerCase();
  }

  static int? _parseHexInt(dynamic value) {
    if (value is! String ||
        !RegExp(r'^0x[0-9a-fA-F]+$').hasMatch(value)) {
      return null;
    }
    try {
      final parsed = BigInt.parse(value.substring(2), radix: 16);
      if (parsed > BigInt.from(0x7fffffffffffffff)) return null;
      return parsed.toInt();
    } on FormatException {
      return null;
    }
  }
}

/// Incremental, persistent ERC-20 Transfer log index for a single wallet.
/// The initial scan is intentionally bounded; subsequent refreshes continue
/// from the saved cursor. RPC failures never advance the cursor past unscanned
/// blocks. This indexes token events, not arbitrary native ETH transfers.
class ActivityIndexer {
  static const _schemaVersion = 1;
  static const _initialLookbackBlocks = 5000;
  static const _chunkSize = 1000;
  static const _maxPersistedTransfers = 2000;

  final FlutterSecureStorage _storage;
  final http.Client _client;

  ActivityIndexer({
    FlutterSecureStorage? storage,
    http.Client? client,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _client = client ?? http.Client();

  String _key(String address, String suffix) =>
      'wallet.activity.index.v$_schemaVersion.${address.toLowerCase()}.$suffix';

  Future<List<IndexedTokenTransfer>> getTransfers(String walletAddress) async {
    final key = _key(walletAddress, 'transfers');
    final raw = await _storage.read(key: key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final transfers = decoded
          .map(IndexedTokenTransfer.fromJson)
          .whereType<IndexedTokenTransfer>()
          .where((transfer) => transfer.involves(walletAddress))
          .toList();
      transfers.sort((a, b) {
        final block = b.blockNumber.compareTo(a.blockNumber);
        return block != 0 ? block : b.logIndex.compareTo(a.logIndex);
      });
      return transfers;
    } on FormatException {
      return const [];
    }
  }

  Future<List<IndexedTokenTransfer>> sync(String walletAddress) async {
    final wallet = walletAddress.trim().toLowerCase();
    if (!RegExp(r'^0x[0-9a-f]{40}$').hasMatch(wallet)) {
      throw const FormatException('Invalid wallet address for activity scan.');
    }

    final chainId = await _rpc('eth_chainId', const []);
    if (_hexInt(chainId) != SupportedNetworks.sepolia.chainId) {
      throw StateError('Activity indexing is only enabled on Sepolia.');
    }
    final latest = _hexInt(await _rpc('eth_blockNumber', const []));
    if (latest == null) throw const FormatException('Invalid latest block.');

    final cursorKey = _key(wallet, 'cursor');
    final savedCursor = int.tryParse(await _storage.read(key: cursorKey) ?? '');
    var nextBlock = savedCursor == null
        ? (latest - _initialLookbackBlocks).clamp(0, latest).toInt()
        : savedCursor + 1;

    final existing = await getTransfers(wallet);
    final byId = <String, IndexedTokenTransfer>{
      for (final transfer in existing)
        '${transfer.transactionHash}:${transfer.logIndex}': transfer,
    };
    final addressTopic = '0x${wallet.substring(2).padLeft(64, '0')}';

    while (nextBlock <= latest) {
      final endBlock = (nextBlock + _chunkSize - 1).clamp(nextBlock, latest).toInt();
      // Query both indexed address positions. Each chunk is committed only
      // after both requests succeed, so transient RPC failures can be retried.
      final sent = await _getLogs(nextBlock, endBlock, [addressTopic, null]);
      final received = await _getLogs(nextBlock, endBlock, [null, addressTopic]);
      for (final rawLog in [...sent, ...received]) {
        if (rawLog is! Map<String, dynamic>) continue;
        final transfer = IndexedTokenTransfer.fromLog(rawLog);
        if (transfer == null || !transfer.involves(wallet)) continue;
        byId['${transfer.transactionHash}:${transfer.logIndex}'] = transfer;
      }
      final persisted = byId.values.toList()
        ..sort((a, b) {
          final block = b.blockNumber.compareTo(a.blockNumber);
          return block != 0 ? block : b.logIndex.compareTo(a.logIndex);
        });
      if (persisted.length > _maxPersistedTransfers) {
        persisted.removeRange(_maxPersistedTransfers, persisted.length);
      }
      await _storage.write(
        key: _key(wallet, 'transfers'),
        value: jsonEncode(
          persisted.map((transfer) => transfer.toJson()).toList(),
        ),
      );
      await _storage.write(key: cursorKey, value: endBlock.toString());
      nextBlock = endBlock + 1;
    }
    return getTransfers(wallet);
  }

  Future<List<dynamic>> _getLogs(
    int fromBlock,
    int toBlock,
    List<String?> indexedTopics,
  ) async {
    final result = await _rpc('eth_getLogs', [
      {
        'fromBlock': '0x${fromBlock.toRadixString(16)}',
        'toBlock': '0x${toBlock.toRadixString(16)}',
        'topics': [
          IndexedTokenTransfer.transferTopic,
          ...indexedTopics,
        ],
      },
    ]);
    if (result is! List) {
      throw const FormatException('Sepolia RPC returned invalid logs.');
    }
    return result;
  }

  int? _hexInt(dynamic value) {
    if (value is! String ||
        !RegExp(r'^0x[0-9a-fA-F]+$').hasMatch(value)) {
      return null;
    }
    try {
      final parsed = BigInt.parse(value.substring(2), radix: 16);
      if (parsed > BigInt.from(0x7fffffffffffffff)) return null;
      return parsed.toInt();
    } on FormatException {
      return null;
    }
  }

  Future<dynamic> _rpc(String method, List<dynamic> params) async {
    final response = await _client
        .post(
          Uri.parse(SupportedNetworks.sepolia.rpcUrl),
          headers: const {'content-type': 'application/json'},
          body: jsonEncode({
            'jsonrpc': '2.0',
            'id': DateTime.now().microsecondsSinceEpoch,
            'method': method,
            'params': params,
          }),
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw StateError('Sepolia RPC request failed (HTTP ${response.statusCode}).');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> ||
        decoded['error'] != null ||
        !decoded.containsKey('result')) {
      throw StateError('Sepolia RPC returned an error for $method.');
    }
    return decoded['result'];
  }

  void dispose() => _client.close();
}
