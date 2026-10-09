import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../network/network_config.dart';

class Erc20Asset {
  final String address;
  final String name;
  final String symbol;
  final int decimals;
  final BigInt rawBalance;

  const Erc20Asset({
    required this.address,
    required this.name,
    required this.symbol,
    required this.decimals,
    required this.rawBalance,
  });

  String get formattedBalance => formatUnits(rawBalance, decimals);

  static String formatUnits(BigInt value, int decimals, {int maxFraction = 6}) {
    if (decimals < 0 || decimals > 255) {
      throw ArgumentError.value(decimals, 'decimals');
    }
    if (maxFraction < 1) {
      throw ArgumentError.value(maxFraction, 'maxFraction');
    }
    final negative = value.isNegative;
    final digits = value.abs().toString().padLeft(decimals + 1, '0');
    if (decimals == 0) return '${negative ? '-' : ''}$digits';
    final whole = digits.substring(0, digits.length - decimals);
    final fraction = digits
        .substring(digits.length - decimals)
        .replaceFirst(RegExp(r'0+$'), '');
    final shown = fraction.length > maxFraction
        ? fraction.substring(0, maxFraction)
        : fraction;
    if (whole == '0' &&
        fraction.length > maxFraction &&
        RegExp(r'^0+$').hasMatch(shown)) {
      final zeros = List<String>.filled(maxFraction - 1, '0').join();
      final threshold = '<0.${zeros}1';
      return negative ? '-$threshold' : threshold;
    }
    return '${negative ? '-' : ''}$whole${shown.isEmpty ? '' : '.$shown'}';
  }
}

class Erc20AssetException implements Exception {
  final String message;
  const Erc20AssetException(this.message);

  @override
  String toString() => 'Erc20AssetException: $message';
}

/// User-selected ERC-20 contracts on Sepolia. Tokens are never discovered by
/// symbol alone; the contract address is the identity and is always displayed.
class Erc20AssetService {
  static const _registryKey = 'wallet.erc20.registry.v1';
  static final _addressPattern = RegExp(r'^0x[0-9a-fA-F]{40}$');
  static final BigInt _maxUint256 = (BigInt.one << 256) - BigInt.one;

  final FlutterSecureStorage _storage;
  final http.Client _client;

  Erc20AssetService({
    FlutterSecureStorage? storage,
    http.Client? client,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _client = client ?? http.Client();

  Future<List<String>> getRegisteredAddresses() async {
    final raw = await _storage.read(key: _registryKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<String>()
          .where((value) => _addressPattern.hasMatch(value))
          .map((value) => value.toLowerCase())
          .toSet()
          .toList(growable: false);
    } on FormatException {
      return const [];
    }
  }

  Future<void> addToken(String address) async {
    final normalized = _normalizeAddress(address);
    // Read metadata first. This rejects contracts that do not expose the
    // minimum ERC-20 read methods before persisting them.
    await loadAsset(normalized, '0x0000000000000000000000000000000000000001');
    final addresses = await getRegisteredAddresses();
    if (addresses.contains(normalized)) return;
    await _storage.write(
      key: _registryKey,
      value: jsonEncode([...addresses, normalized]),
    );
  }

  Future<void> removeToken(String address) async {
    final normalized = _normalizeAddress(address);
    final addresses = await getRegisteredAddresses();
    addresses.removeWhere((value) => value == normalized);
    await _storage.write(key: _registryKey, value: jsonEncode(addresses));
  }

  Future<List<Erc20Asset>> loadAssets(String walletAddress) async {
    final owner = _normalizeAddress(walletAddress);
    final addresses = await getRegisteredAddresses();
    final assets = <Erc20Asset>[];
    for (final address in addresses) {
      assets.add(await loadAsset(address, owner));
    }
    return assets;
  }

  Future<Erc20Asset> loadAsset(String tokenAddress, String ownerAddress) async {
    final token = _normalizeAddress(tokenAddress);
    final owner = _normalizeAddress(ownerAddress);
    final chainId = await _rpc('eth_chainId', const []);
    if (_hexToBigInt(chainId) != BigInt.from(SupportedNetworks.sepolia.chainId)) {
      throw const Erc20AssetException('RPC is not connected to Sepolia.');
    }

    final nameResult = await _ethCall(token, '0x06fdde03');
    final symbolResult = await _ethCall(token, '0x95d89b41');
    final decimalsResult = await _ethCall(token, '0x313ce567');
    final balanceResult = await _ethCall(token, '0x70a08231${owner.substring(2).toLowerCase().padLeft(64, '0')}');

    final name = _decodeString(nameResult);
    final symbol = _decodeString(symbolResult);
    final decimalsValue = _hexToBigInt(decimalsResult);
    final balance = _hexToBigInt(balanceResult);
    if (name.isEmpty || symbol.isEmpty || decimalsValue > BigInt.from(255)) {
      throw const Erc20AssetException('Token returned invalid ERC-20 metadata.');
    }
    if (balance > _maxUint256) {
      throw const Erc20AssetException('Token balance exceeds uint256.');
    }
    return Erc20Asset(
      address: token,
      name: name,
      symbol: symbol,
      decimals: decimalsValue.toInt(),
      rawBalance: balance,
    );
  }

  String explorerTokenUrl(String address) =>
      '${SupportedNetworks.sepolia.explorerUrl}/token/${_normalizeAddress(address)}';

  String _normalizeAddress(String address) {
    final value = address.trim();
    if (!_addressPattern.hasMatch(value) ||
        value.toLowerCase() == '0x0000000000000000000000000000000000000000') {
      throw const Erc20AssetException('Enter a valid non-zero EVM address.');
    }
    return value.toLowerCase();
  }

  Future<String> _ethCall(String address, String data) async {
    final result = await _rpc('eth_call', [
      {'to': address, 'data': data},
      'latest',
    ]);
    if (result is! String ||
        !RegExp(r'^0x(?:[0-9a-fA-F]{2})+$').hasMatch(result)) {
      throw const Erc20AssetException('Contract returned invalid data.');
    }
    return result;
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
      throw const Erc20AssetException('Sepolia RPC request failed.');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['error'] != null ||
        !decoded.containsKey('result')) {
      throw const Erc20AssetException('Sepolia RPC returned an error.');
    }
    return decoded['result'];
  }

  BigInt _hexToBigInt(dynamic value) {
    if (value is! String || !RegExp(r'^0x[0-9a-fA-F]+$').hasMatch(value)) {
      throw const Erc20AssetException('Contract returned an invalid number.');
    }
    return BigInt.parse(value.substring(2), radix: 16);
  }

  String _decodeString(String hex) {
    final bytes = hex.substring(2);
    // Standard ABI dynamic string: offset, byte length, then UTF-8 data.
    if (bytes.length >= 128) {
      try {
        final offset = BigInt.parse(bytes.substring(0, 64), radix: 16).toInt();
        final lengthStart = offset * 2;
        if (lengthStart + 64 <= bytes.length) {
          final length = BigInt.parse(
            bytes.substring(lengthStart, lengthStart + 64),
            radix: 16,
          ).toInt();
          final start = lengthStart + 64;
          final end = start + length * 2;
          if (length >= 0 && end <= bytes.length) {
            return utf8.decode(
              List<int>.generate(length, (i) => int.parse(
                bytes.substring(start + i * 2, start + i * 2 + 2),
                radix: 16,
              )),
              allowMalformed: false,
            ).trim();
          }
        }
      } on FormatException {
        // Try bytes32 metadata used by a small number of older tokens.
      } on RangeError {
        // Invalid offsets are rejected below.
      }
    }
    // Legacy bytes32 string metadata.
    final word = bytes.length >= 64 ? bytes.substring(0, 64) : bytes;
    final decoded = <int>[];
    for (var i = 0; i + 2 <= word.length; i += 2) {
      final byte = int.parse(word.substring(i, i + 2), radix: 16);
      if (byte == 0) break;
      decoded.add(byte);
    }
    try {
      return utf8.decode(decoded, allowMalformed: false).trim();
    } on FormatException {
      throw const Erc20AssetException('Token metadata is not valid UTF-8.');
    }
  }

  void dispose() => _client.close();
}
).hasMatch(shown)) {
      final threshold = '<0.${List<String>.filled(maxFraction - 1, '0').join()}1';
      return negative ? '-$threshold' : threshold;
    }
    return '${negative ? '-' : ''}$whole${shown.isEmpty ? '' : '.$shown'}';
  }
}

class Erc20AssetException implements Exception {
  final String message;
  const Erc20AssetException(this.message);

  @override
  String toString() => 'Erc20AssetException: $message';
}

/// User-selected ERC-20 contracts on Sepolia. Tokens are never discovered by
/// symbol alone; the contract address is the identity and is always displayed.
class Erc20AssetService {
  static const _registryKey = 'wallet.erc20.registry.v1';
  static final _addressPattern = RegExp(r'^0x[0-9a-fA-F]{40}$');
  static final BigInt _maxUint256 = (BigInt.one << 256) - BigInt.one;

  final FlutterSecureStorage _storage;
  final http.Client _client;

  Erc20AssetService({
    FlutterSecureStorage? storage,
    http.Client? client,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _client = client ?? http.Client();

  Future<List<String>> getRegisteredAddresses() async {
    final raw = await _storage.read(key: _registryKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<String>()
          .where((value) => _addressPattern.hasMatch(value))
          .map((value) => value.toLowerCase())
          .toSet()
          .toList(growable: false);
    } on FormatException {
      return const [];
    }
  }

  Future<void> addToken(String address) async {
    final normalized = _normalizeAddress(address);
    // Read metadata first. This rejects contracts that do not expose the
    // minimum ERC-20 read methods before persisting them.
    await loadAsset(normalized, '0x0000000000000000000000000000000000000001');
    final addresses = await getRegisteredAddresses();
    if (addresses.contains(normalized)) return;
    await _storage.write(
      key: _registryKey,
      value: jsonEncode([...addresses, normalized]),
    );
  }

  Future<void> removeToken(String address) async {
    final normalized = _normalizeAddress(address);
    final addresses = await getRegisteredAddresses();
    addresses.removeWhere((value) => value == normalized);
    await _storage.write(key: _registryKey, value: jsonEncode(addresses));
  }

  Future<List<Erc20Asset>> loadAssets(String walletAddress) async {
    final owner = _normalizeAddress(walletAddress);
    final addresses = await getRegisteredAddresses();
    final assets = <Erc20Asset>[];
    for (final address in addresses) {
      assets.add(await loadAsset(address, owner));
    }
    return assets;
  }

  Future<Erc20Asset> loadAsset(String tokenAddress, String ownerAddress) async {
    final token = _normalizeAddress(tokenAddress);
    final owner = _normalizeAddress(ownerAddress);
    final chainId = await _rpc('eth_chainId', const []);
    if (_hexToBigInt(chainId) != BigInt.from(SupportedNetworks.sepolia.chainId)) {
      throw const Erc20AssetException('RPC is not connected to Sepolia.');
    }

    final nameResult = await _ethCall(token, '0x06fdde03');
    final symbolResult = await _ethCall(token, '0x95d89b41');
    final decimalsResult = await _ethCall(token, '0x313ce567');
    final balanceResult = await _ethCall(token, '0x70a08231${owner.substring(2).toLowerCase().padLeft(64, '0')}');

    final name = _decodeString(nameResult);
    final symbol = _decodeString(symbolResult);
    final decimalsValue = _hexToBigInt(decimalsResult);
    final balance = _hexToBigInt(balanceResult);
    if (name.isEmpty || symbol.isEmpty || decimalsValue > BigInt.from(255)) {
      throw const Erc20AssetException('Token returned invalid ERC-20 metadata.');
    }
    if (balance > _maxUint256) {
      throw const Erc20AssetException('Token balance exceeds uint256.');
    }
    return Erc20Asset(
      address: token,
      name: name,
      symbol: symbol,
      decimals: decimalsValue.toInt(),
      rawBalance: balance,
    );
  }

  String explorerTokenUrl(String address) =>
      '${SupportedNetworks.sepolia.explorerUrl}/token/${_normalizeAddress(address)}';

  String _normalizeAddress(String address) {
    final value = address.trim();
    if (!_addressPattern.hasMatch(value) ||
        value.toLowerCase() == '0x0000000000000000000000000000000000000000') {
      throw const Erc20AssetException('Enter a valid non-zero EVM address.');
    }
    return value.toLowerCase();
  }

  Future<String> _ethCall(String address, String data) async {
    final result = await _rpc('eth_call', [
      {'to': address, 'data': data},
      'latest',
    ]);
    if (result is! String ||
        !RegExp(r'^0x(?:[0-9a-fA-F]{2})+$').hasMatch(result)) {
      throw const Erc20AssetException('Contract returned invalid data.');
    }
    return result;
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
      throw const Erc20AssetException('Sepolia RPC request failed.');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['error'] != null ||
        !decoded.containsKey('result')) {
      throw const Erc20AssetException('Sepolia RPC returned an error.');
    }
    return decoded['result'];
  }

  BigInt _hexToBigInt(dynamic value) {
    if (value is! String || !RegExp(r'^0x[0-9a-fA-F]+$').hasMatch(value)) {
      throw const Erc20AssetException('Contract returned an invalid number.');
    }
    return BigInt.parse(value.substring(2), radix: 16);
  }

  String _decodeString(String hex) {
    final bytes = hex.substring(2);
    // Standard ABI dynamic string: offset, byte length, then UTF-8 data.
    if (bytes.length >= 128) {
      try {
        final offset = BigInt.parse(bytes.substring(0, 64), radix: 16).toInt();
        final lengthStart = offset * 2;
        if (lengthStart + 64 <= bytes.length) {
          final length = BigInt.parse(
            bytes.substring(lengthStart, lengthStart + 64),
            radix: 16,
          ).toInt();
          final start = lengthStart + 64;
          final end = start + length * 2;
          if (length >= 0 && end <= bytes.length) {
            return utf8.decode(
              List<int>.generate(length, (i) => int.parse(
                bytes.substring(start + i * 2, start + i * 2 + 2),
                radix: 16,
              )),
              allowMalformed: false,
            ).trim();
          }
        }
      } on FormatException {
        // Try bytes32 metadata used by a small number of older tokens.
      } on RangeError {
        // Invalid offsets are rejected below.
      }
    }
    // Legacy bytes32 string metadata.
    final word = bytes.length >= 64 ? bytes.substring(0, 64) : bytes;
    final decoded = <int>[];
    for (var i = 0; i + 2 <= word.length; i += 2) {
      final byte = int.parse(word.substring(i, i + 2), radix: 16);
      if (byte == 0) break;
      decoded.add(byte);
    }
    try {
      return utf8.decode(decoded, allowMalformed: false).trim();
    } on FormatException {
      throw const Erc20AssetException('Token metadata is not valid UTF-8.');
    }
  }

  void dispose() => _client.close();
}
