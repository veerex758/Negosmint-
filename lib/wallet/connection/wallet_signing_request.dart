import '../../core/network/network_config.dart';
import 'wallet_connection_request.dart';

class WalletSigningRequest {
  final String sessionId;
  final String requestId;
  final int chainId;
  final String? to;
  final String? value;
  final String? data;
  final String actionDescription;

  const WalletSigningRequest({
    required this.sessionId,
    required this.requestId,
    required this.chainId,
    required this.to,
    required this.value,
    required this.data,
    required this.actionDescription,
  });

  void validate(Iterable<NetworkConfig> networks) {
    final network = networks.where((n) => n.chainId == chainId);
    if (network.isEmpty) {
      throw const WalletConnectionException('Unsupported signing network.');
    }
    if (to != null && !_isEvmAddress(to!)) {
      throw const WalletConnectionException('Invalid transaction recipient.');
    }
    if (data != null && data!.length > 100000) {
      throw const WalletConnectionException('Transaction data is too large.');
    }
  }

  bool get isContractInteraction => data != null && data != '0x';

  static bool _isEvmAddress(String value) =>
      RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(value);
}
