import '../../core/network/network_config.dart';
import '../../core/wallet/wallet_service.dart';
import 'wallet_connection_manager.dart';
import 'wallet_connection_request.dart';
import 'wallet_connection_result.dart';
import 'wallet_connection_session.dart';
import 'wallet_signing_request.dart';
import 'wallet_signing_result.dart';

class WalletConnectionService {
  final WalletConnectionManager manager;

  WalletConnectionService({WalletConnectionManager? manager})
      : manager = manager ?? WalletConnectionManager();

  Future<WalletConnectionRequest> handleIncomingRequest(
    WalletConnectionRequest request,
  ) =>
      manager.handleIncomingRequest(request);

  Future<WalletConnectionResult> approveConnection(
    WalletConnectionRequest request,
  ) =>
      manager.approveConnection(request);

  Future<WalletConnectionResult> rejectConnection(
    WalletConnectionRequest request,
  ) =>
      manager.rejectConnection(request);

  Future<List<WalletConnectionSession>> getActiveConnections() =>
      manager.getActiveConnections();

  Future<void> revokeConnection(String sessionId) =>
      manager.revokeConnection(sessionId);

  Future<bool> isConnected(String appIdentifier) =>
      manager.isConnected(appIdentifier);

  Future<String> signTransaction(WalletSigningRequest request) =>
      manager.signTransaction(request);

  Future<WalletSigningResult> signTransactionResult(
    WalletSigningRequest request,
  ) =>
      manager.signTransactionResult(request);

  Future<void> authorizeRequest({
    required String sessionId,
    required WalletConnectionPermission permission,
    required int chainId,
  }) =>
      manager.authorizeRequest(
        sessionId: sessionId,
        permission: permission,
        chainId: chainId,
      );

  Future<String> getPublicAddress() async {
    final address = await WalletService().getPublicAddress();
    if (address == null || address.isEmpty) {
      throw const WalletConnectionException('Wallet is not initialized.');
    }
    return address;
  }

  NetworkConfig networkFor(int chainId) {
    const networks = [SupportedNetworks.sepolia];
    return networks.firstWhere(
      (network) => network.chainId == chainId,
      orElse: () => throw const WalletConnectionException(
        'Unsupported wallet network.',
      ),
    );
  }
}
