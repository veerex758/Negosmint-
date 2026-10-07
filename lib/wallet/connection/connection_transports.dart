import 'wallet_connection_codec.dart';
import 'wallet_connection_request.dart';
import 'wallet_connection_result.dart';
import 'wallet_connection_transport.dart';
import 'wallet_signing_result.dart';

class NegosMintDeepLinkTransport implements DeepLinkTransport {
  @override
  Future<WalletConnectionRequest> receive(String payload) async =>
      WalletConnectionCodec.parseRequest(payload);

  @override
  Future<void> send(WalletConnectionResult result) async {
    // OS deep-link delivery will be added here. The result contains public
    // connection metadata only; never attach wallet secrets to the URI.
  }

  @override
  Future<void> sendSigningResult(WalletSigningResult result) async {
    // OS delivery will be added here. The signed transaction is intentionally
    // kept out of connection metadata and is only emitted as a signing result.
  }

  @override
  Future<void> sendSigningResult(WalletSigningResult result) async {
    // OS deep-link delivery will be added here. Never attach wallet secrets.
  }

  String encode(WalletConnectionRequest request) =>
      WalletConnectionCodec.encodeRequest(request);
}

class NegosMintQRCodeTransport implements QRCodeTransport {
  @override
  Future<WalletConnectionRequest> receive(String payload) async =>
      WalletConnectionCodec.parseRequest(payload);

  @override
  Future<void> send(WalletConnectionResult result) async {
    // A future QR response flow can render WalletConnectionCodec.encodeResult().
  }

  @override
  Future<void> sendSigningResult(WalletSigningResult result) async {
    // A future QR response flow can render WalletConnectionCodec.encodeSigningResult().
  }

  @override
  Future<void> sendSigningResult(WalletSigningResult result) async {
    // A future QR response flow can render WalletConnectionCodec.encodeSigningResult().
  }

  String encode(WalletConnectionRequest request) =>
      WalletConnectionCodec.encodeRequest(request);
}
