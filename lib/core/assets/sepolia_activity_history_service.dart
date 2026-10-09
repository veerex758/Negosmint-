import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// A page of indexed Sepolia activity returned by Blockscout's public explorer
/// API. The RPC endpoint itself cannot enumerate transactions sent to an
/// address, so this read-only explorer API supplements the local RPC indexer.
class SepoliaActivityPage {
  final List<String> transactionHashes;
  final Map<String, dynamic>? transactionCursor;
  final Map<String, dynamic>? tokenTransferCursor;

  const SepoliaActivityPage({
    required this.transactionHashes,
    required this.transactionCursor,
    required this.tokenTransferCursor,
  });

  bool get hasMore =>
      transactionCursor != null || tokenTransferCursor != null;
}

class SepoliaActivityHistoryService {
  static const _host = 'eth-sepolia.blockscout.com';
  static final _addressPattern = RegExp(r'^0x[0-9a-fA-F]{40}$');
  static final _hashPattern = RegExp(r'^0x[0-9a-fA-F]{64}$');

  final http.Client _client;

  SepoliaActivityHistoryService({http.Client? client})
      : _client = client ?? http.Client();

  Future<SepoliaActivityPage> fetchPage(
    String address, {
    Map<String, dynamic>? transactionCursor,
    Map<String, dynamic>? tokenTransferCursor,
  }) async {
    final wallet = address.trim().toLowerCase();
    if (!_addressPattern.hasMatch(wallet)) {
      throw const FormatException('Invalid wallet address for activity history.');
    }

    final responses = await Future.wait([
      _getPage('/api/v2/addresses/$wallet/transactions', transactionCursor),
      _getPage('/api/v2/addresses/$wallet/token-transfers', tokenTransferCursor),
    ]);

    final hashes = <String>{};
    final transactions = responses[0]['items'];
    if (transactions is List) {
      for (final item in transactions) {
        if (item is Map) _addHash(hashes, item['hash']);
      }
    }

    final tokenTransfers = responses[1]['items'];
    if (tokenTransfers is List) {
      for (final item in tokenTransfers) {
        if (item is Map) _addHash(hashes, item['transaction_hash']);
      }
    }

    return SepoliaActivityPage(
      transactionHashes: hashes.toList(growable: false),
      transactionCursor: _cursor(responses[0]['next_page_params']),
      tokenTransferCursor: _cursor(responses[1]['next_page_params']),
    );
  }

  Future<Map<String, dynamic>> _getPage(
    String path,
    Map<String, dynamic>? cursor,
  ) async {
    final query = <String, String>{};
    cursor?.forEach((key, value) {
      if (value != null) query[key] = value.toString();
    });
    final uri = Uri.https(_host, path, query.isEmpty ? null : query);
    final response = await _client
        .get(uri, headers: const {'accept': 'application/json'})
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError('Sepolia activity provider returned HTTP ${response.statusCode}.');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['items'] is! List) {
      throw const FormatException('Sepolia activity provider returned invalid data.');
    }
    return decoded;
  }

  static Map<String, dynamic>? _cursor(dynamic value) {
    if (value is! Map) return null;
    final result = <String, dynamic>{};
    for (final entry in value.entries) {
      if (entry.key is String &&
          (entry.value is String || entry.value is num || entry.value == null)) {
        result[entry.key as String] = entry.value;
      }
    }
    return result.isEmpty ? null : result;
  }

  static void _addHash(Set<String> hashes, dynamic value) {
    if (value is String && _hashPattern.hasMatch(value)) {
      hashes.add(value.toLowerCase());
    }
  }

  void dispose() => _client.close();
}
