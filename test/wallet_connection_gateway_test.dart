import 'package:flutter_test/flutter_test.dart';
import 'package:negosmint_wallet/core/network/network_config.dart';
import 'package:negosmint_wallet/core/wallet/wallet_service.dart';
import 'package:negosmint_wallet/wallet/connection/wallet_connection_gateway.dart';
import 'package:negosmint_wallet/wallet/connection/wallet_connection_manager.dart';
import 'package:negosmint_wallet/wallet/connection/wallet_connection_service.dart';
import 'package:negosmint_wallet/wallet/connection/wallet_signing_request.dart';
import 'package:negosmint_wallet/wallet/connection/wallet_connection_request.dart';
import 'package:negosmint_wallet/wallet/connection/wallet_connection_result.dart';
import 'package:negosmint_wallet/wallet/connection/wallet_connection_session.dart';
import 'package:negosmint_wallet/wallet/connection/wallet_connection_storage.dart';
import 'package:negosmint_wallet/wallet/connection/wallet_connection_transport.dart';
import 'package:negosmint_wallet/wallet/connection/wallet_signing_result.dart';

class FakeWalletService extends WalletService {
  @override
  Future<String?> getPublicAddress() async =>
      '0x1111111111111111111111111111111111111111';
}

class FakeConnectionStorage extends WalletConnectionStorage {
  List<WalletConnectionSession> sessions = [];
  final Set<String> consumed = {};

  @override
  Future<List<WalletConnectionSession>> loadSessions() async =>
      List.unmodifiable(sessions);

  @override
  Future<void> saveSessions(List<WalletConnectionSession> value) async =>
      sessions = List.of(value);

  @override
  Future<bool> wasRequestConsumed(String requestId) async =>
      consumed.contains(requestId);

  @override
  Future<void> markRequestConsumed(String requestId) async =>
      consumed.add(requestId);
}

class FakeTransport implements WalletConnectionTransport {
  final WalletConnectionRequest request;
  WalletConnectionResult? connectionResult;
  WalletSigningResult? signingResult;

  FakeTransport(this.request);

  @override
  Future<WalletConnectionRequest> receive(String payload) async {
    expect(payload, 'incoming');
    return request;
  }

  @override
  Future<void> send(WalletConnectionResult result) async {
    connectionResult = result;
  }

  @override
  Future<void> sendSigningResult(WalletSigningResult result) async {
    signingResult = result;
  }
}

WalletConnectionRequest request() => WalletConnectionRequest(
      requestId: 'gateway-1',
      appName: 'NegosMint Task Platform',
      appIdentifier: 'com.negosmint.taskplatform',
      permissions: const [
        WalletConnectionPermission.readAddress,
        WalletConnectionPermission.readNetwork,
      ],
      chainId: SupportedNetworks.sepolia.chainId,
      callback: null,
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
    );

void main() {
  test('gateway validates an incoming payload before approval', () async {
    final transport = FakeTransport(request());
    final service = WalletConnectionService(
      manager: WalletConnectionManager(
        wallet: FakeWalletService(),
        storage: FakeConnectionStorage(),
        networks: const [SupportedNetworks.sepolia],
      ),
    );
    final gateway = WalletConnectionGateway(
      transport: transport,
      service: service,
    );

    final received = await gateway.receive('incoming');

    expect(received.requestId, 'gateway-1');
  });

  test('gateway sends only the public connection result after approval',
      () async {
    final transport = FakeTransport(request());
    final service = WalletConnectionService(
      manager: WalletConnectionManager(
        wallet: FakeWalletService(),
        storage: FakeConnectionStorage(),
        networks: const [SupportedNetworks.sepolia],
      ),
    );
    final gateway = WalletConnectionGateway(
      transport: transport,
      service: service,
    );

    final result = await gateway.approve(request());

    expect(result.status, WalletConnectionResultStatus.approved);
    expect(transport.connectionResult, isNotNull);
    expect(transport.connectionResult!.walletAddress,
        '0x1111111111111111111111111111111111111111');
    expect(transport.connectionResult!.toJson().toString(),
        isNot(contains('mnemonic')));
    expect(transport.connectionResult!.toJson().toString(),
        isNot(contains('privateKey')));
  });

  test('gateway sends signing rejection without secret material', () async {
    final transport = FakeTransport(request());
    final service = WalletConnectionService(
      manager: WalletConnectionManager(
        wallet: FakeWalletService(),
        storage: FakeConnectionStorage(),
        networks: const [SupportedNetworks.sepolia],
      ),
    );
    final gateway = WalletConnectionGateway(
      transport: transport,
      service: service,
    );

    final connection = await gateway.approve(request());
    final result = await gateway.sign(
      WalletSigningRequest(
        sessionId: connection.sessionId!,
        requestId: 'sign-gateway-1',
        chainId: SupportedNetworks.sepolia.chainId,
        to: '0x2222222222222222222222222222222222222222',
        value: '0x01',
        data: '0x',
        actionDescription: 'Send test ETH',
      ),
    );

    expect(result.status, WalletSigningResultStatus.rejected);
    expect(transport.signingResult, isNotNull);
    expect(transport.signingResult!.signedTransaction, isNull);
    expect(transport.signingResult!.toJson().toString(),
        isNot(contains('mnemonic')));
    expect(transport.signingResult!.toJson().toString(),
        isNot(contains('privateKey')));
  });
}
