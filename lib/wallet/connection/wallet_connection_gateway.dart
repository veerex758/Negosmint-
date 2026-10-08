import 'wallet_connection_request.dart';
import 'wallet_connection_result.dart';
import 'wallet_connection_service.dart';
import 'wallet_connection_transport.dart';
import 'wallet_signing_request.dart';
import 'wallet_signing_result.dart';

/// Coordinates transport delivery with wallet authorization.
///
/// This layer never receives seed phrases, private keys, PINs, or decrypted
/// key material. It only moves validated connection/signing requests and their
/// public response data between a transport and the wallet service.
class WalletConnectionGateway {
  final WalletConnectionService service;
  final WalletConnectionTransport transport;

  WalletConnectionGateway({
    required this.transport,
    WalletConnectionService? service,
  }) : service = service ?? WalletConnectionService();

  Future<WalletConnectionRequest> receive(String payload) async {
    final request = await transport.receive(payload);
    return service.handleIncomingRequest(request);
  }

  Future<WalletConnectionResult> approve(
    WalletConnectionRequest request,
  ) async {
    final result = await service.approveConnection(request);
    await transport.send(result);
    return result;
  }

  Future<WalletConnectionResult> reject(
    WalletConnectionRequest request,
  ) async {
    final result = await service.rejectConnection(request);
    await transport.send(result);
    return result;
  }

  Future<WalletSigningResult> sign(
    WalletSigningRequest request,
  ) async {
    final result = await service.signTransactionResult(request);
    await transport.sendSigningResult(result);
    return result;
  }
}
