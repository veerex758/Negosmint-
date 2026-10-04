import 'dart:async';
import 'dart:convert';
import 'dart:io';

class EvmRpcException implements Exception {
  final String message;
  const EvmRpcException(this.message);
  @override
  String toString() => 'EvmRpcException: $message';
}

class EvmRpcService {
  static const rpcUrl = 'https://ethereum-sepolia-rpc.publicnode.com';
  static const chainId = 11155111;
  Future<String> getNativeBalanceWei(String address) async {
    final r = await _call('eth_getBalance', [address, 'latest']);
    if (r is! String || !r.startsWith('0x')) {
      throw const EvmRpcException('Invalid balance returned by RPC.');
    }
    return r;
  }

  Future<BigInt> getNativeBalanceInWei(String a) async =>
      BigInt.parse((await getNativeBalanceWei(a)).substring(2), radix: 16);
  Future<int> getTransactionCount(String a) async => _parseHexInt(
      await _call('eth_getTransactionCount', [a, 'pending']),
      'Invalid nonce returned by RPC.');
  Future<BigInt> estimateNativeTransferGas(
      {required String from,
      required String to,
      required BigInt valueWei}) async {
    final r = await _call('eth_estimateGas', [
      {'from': from, 'to': to, 'value': '0x${valueWei.toRadixString(16)}'},
      'latest'
    ]);
    return BigInt.from(
        _parseHexInt(r, 'Invalid gas estimate returned by RPC.'));
  }

  Future<Map<String, dynamic>?> getTransactionReceipt(String h) async {
    final r = await _call('eth_getTransactionReceipt', [h]);
    if (r == null) return null;
    if (r is! Map<String, dynamic>) {
      throw const EvmRpcException('Invalid transaction receipt.');
    }
    return r;
  }

  Future<Map<String, dynamic>?> getTransactionByHash(String h) async {
    final r = await _call('eth_getTransactionByHash', [h]);
    if (r == null) return null;
    if (r is! Map<String, dynamic>) {
      throw const EvmRpcException('Invalid transaction returned by RPC.');
    }
    return r;
  }

  Future<int?> getBlockTimestamp(String blockNumber) async {
    final r = await _call('eth_getBlockByNumber', [blockNumber, false]);
    if (r == null) return null;
    if (r is! Map<String, dynamic>) {
      throw const EvmRpcException('Invalid block returned by RPC.');
    }
    final t = r['timestamp'];
    return t is String && t.startsWith('0x')
        ? int.parse(t.substring(2), radix: 16)
        : null;
  }

  Future<BigInt> getGasPriceWei() async {
    final r = await _call('eth_gasPrice', const []);
    if (r is! String || !r.startsWith('0x')) {
      throw const EvmRpcException('Invalid gas price returned by RPC.');
    }
    return BigInt.parse(r.substring(2), radix: 16);
  }

  int _parseHexInt(dynamic r, String e) {
    if (r is! String || !r.startsWith('0x')) throw EvmRpcException(e);
    return int.parse(r.substring(2), radix: 16);
  }

  Future<int> getChainId() async {
    final r = await _call('eth_chainId', const []);
    if (r is! String || !r.startsWith('0x')) {
      throw const EvmRpcException('Invalid chain ID returned by RPC.');
    }
    return int.parse(r.substring(2), radix: 16);
  }

  Future<dynamic> _call(String method, List<dynamic> params) async {
    final c = HttpClient();
    try {
      final q = await c.postUrl(Uri.parse(rpcUrl));
      q.headers.contentType = ContentType.json;
      q.write(jsonEncode({
        'jsonrpc': '2.0',
        'id': DateTime.now().microsecondsSinceEpoch,
        'method': method,
        'params': params
      }));
      final res = await q.close().timeout(const Duration(seconds: 12));
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode != HttpStatus.ok) {
        throw EvmRpcException('RPC returned HTTP ${res.statusCode}.');
      }
      final d = jsonDecode(body);
      if (d is! Map<String, dynamic>) {
        throw const EvmRpcException('Malformed RPC response.');
      }
      if (d['error'] != null) {
        final e = d['error'];
        final m = e is Map ? e['message']?.toString() : null;
        throw EvmRpcException(m ?? 'RPC request failed.');
      }
      if (!d.containsKey('result')) {
        throw const EvmRpcException('RPC response has no result.');
      }
      return d['result'];
    } on SocketException {
      throw const EvmRpcException('Unable to reach the Sepolia network.');
    } on TimeoutException {
      throw const EvmRpcException('Sepolia network request timed out.');
    } on FormatException {
      throw const EvmRpcException('RPC returned invalid JSON.');
    } finally {
      c.close(force: true);
    }
  }
}
