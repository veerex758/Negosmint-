import 'wallet_connection_request.dart';
import 'wallet_connection_result.dart';

abstract interface class WalletConnectionTransport {
  Future<WalletConnectionRequest> receive(String payload);
  Future<void> send(WalletConnectionResult result);
}

/// Deep-link transport boundary. The OS integration is deliberately separate
/// from request validation and wallet/key management.
abstract interface class DeepLinkTransport extends WalletConnectionTransport {}

/// QR transport boundary. A scanner supplies the raw payload to receive().
abstract interface class QRCodeTransport extends WalletConnectionTransport {}
