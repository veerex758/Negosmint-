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
    final result = await _call('eth_getBalance', [address, 'latest']);
    if (result is! String || !result.startsWith('0x')) {
      throw const EvmRpcException('Invalid balance returned by RPC.');
    }
    return result;
  }

  Future<BigInt> getNativeBalanceInWei(String address) async {
    final hex = await getNativeBalanceWei(address);
    return BigInt.parse(hex.substring(2), radix: 16);
  }

  Future<int> getChainId() async {
    final result = await _call('eth_chainId', const []);
    if (result is! String || !result.startsWith('0x')) {
      throw const EvmRpcException('Invalid chain ID returned by RPC.');
    }
    return int.parse(result.substring(2), radix: 16);
  }

  Future<dynamic> _call(String method, List<dynamic> params) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse(rpcUrl));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        'jsonrpc': '2.0',
        'id': DateTime.now().microsecondsSinceEpoch,
        'method': method,
        'params': params,
      }));
      final response = await request.close().timeout(const Duration(seconds: 12));
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != HttpStatus.ok) {
        throw EvmRpcException('RPC returned HTTP ${response.statusCode}.');
      }

      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const EvmRpcException('Malformed RPC response.');
      }
      if (decoded['error'] != null) {
        final error = decoded['error'];
        final message = error is Map ? error['message']?.toString() : null;
        throw EvmRpcException(message ?? 'RPC request failed.');
      }
      if (!decoded.containsKey('result')) {
        throw const EvmRpcException('RPC response has no result.');
      }
      return decoded['result'];
    } on SocketException {
      throw const EvmRpcException('Unable to reach the Sepolia network.');
    } on TimeoutException {
      throw const EvmRpcException('Sepolia network request timed out.');
    } on FormatException {
      throw const EvmRpcException('RPC returned invalid JSON.');
    } finally {
      client.close(force: true);
    }
  }
}
