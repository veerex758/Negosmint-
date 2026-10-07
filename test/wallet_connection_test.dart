import 'package:flutter_test/flutter_test.dart';
import 'package:negosmint_wallet/core/network/network_config.dart';
import 'package:negosmint_wallet/wallet/connection/wallet_connection_codec.dart';
import 'package:negosmint_wallet/wallet/connection/wallet_connection_manager.dart';
import 'package:negosmint_wallet/wallet/connection/wallet_connection_request.dart';
import 'package:negosmint_wallet/wallet/connection/wallet_connection_session.dart';
import 'package:negosmint_wallet/wallet/connection/wallet_connection_storage.dart';
import 'package:negosmint_wallet/wallet/connection/wallet_signing_request.dart';
import 'package:negosmint_wallet/wallet/connection/wallet_signing_result.dart';
import 'package:negosmint_wallet/core/wallet/wallet_service.dart';

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

WalletConnectionRequest request({
  String id = 'req-1',
  List<WalletConnectionPermission> permissions = const [
    WalletConnectionPermission.readAddress,
    WalletConnectionPermission.readNetwork,
  ],
  int chainId = 11155111,
}) =>
    WalletConnectionRequest(
      requestId: id,
      appName: 'NegosMint Task Platform',
      appIdentifier: 'com.negosmint.taskplatform',
      permissions: permissions,
      chainId: chainId,
      callback: null,
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
    );

void main() {
  test('connection payload round trips without secrets', () {
    final original = request();
    final payload = WalletConnectionCodec.encodeRequest(original);
    final parsed = WalletConnectionCodec.parseRequest(payload);

    expect(parsed.requestId, original.requestId);
    expect(parsed.appIdentifier, original.appIdentifier);
    expect(parsed.permissions, original.permissions);
    expect(payload, isNot(contains('mnemonic')));
    expect(payload, isNot(contains('private')));
    expect(payload, isNot(contains('seed')));
  });

  test('malformed and unsupported connection requests are rejected', () {
    expect(
      () => WalletConnectionCodec.parseRequest('not-a-wallet-request'),
      throwsA(isA<WalletConnectionException>()),
    );

    final manager = WalletConnectionManager(
      wallet: FakeWalletService(),
      storage: FakeConnectionStorage(),
      networks: const [SupportedNetworks.sepolia],
    );

    expect(
      () => manager.handleIncomingRequest(request(chainId: 1)),
      throwsA(isA<WalletConnectionException>()),
    );
  });

  test('approval creates a public-only session and persists it', () async {
    final storage = FakeConnectionStorage();
    final manager = WalletConnectionManager(
      wallet: FakeWalletService(),
      storage: storage,
      networks: const [SupportedNetworks.sepolia],
    );

    final result = await manager.approveConnection(request());

    expect(result.walletAddress, '0x1111111111111111111111111111111111111111');
    expect(storage.sessions, hasLength(1));
    expect(storage.sessions.single.permissions,
        contains(WalletConnectionPermission.readAddress));
    expect(storage.sessions.single.toJson().toString(), isNot(contains('mnemonic')));
    expect(storage.sessions.single.toJson().toString(), isNot(contains('privateKey')));
  });

  test('duplicate request IDs are rejected', () async {
    final storage = FakeConnectionStorage();
    final manager = WalletConnectionManager(
      wallet: FakeWalletService(),
      storage: storage,
      networks: const [SupportedNetworks.sepolia],
    );

    await manager.approveConnection(request());
    expect(
      () => manager.handleIncomingRequest(request()),
      throwsA(isA<WalletConnectionException>()),
    );
  });

  test('revoked applications cannot reuse the connection', () async {
    final storage = FakeConnectionStorage();
    final manager = WalletConnectionManager(
      wallet: FakeWalletService(),
      storage: storage,
      networks: const [SupportedNetworks.sepolia],
    );

    await manager.approveConnection(request());
    await manager.revokeConnection(storage.sessions.single.sessionId);

    expect(
      () => manager.handleIncomingRequest(request(id: 'req-2')),
      throwsA(isA<WalletConnectionException>()),
    );
  });

  test('unauthorized signing permission is rejected', () async {
    final storage = FakeConnectionStorage();
    final manager = WalletConnectionManager(
      wallet: FakeWalletService(),
      storage: storage,
      networks: const [SupportedNetworks.sepolia],
    );

    final result = await manager.approveConnection(request());

    expect(
      () => manager.authorizeRequest(
        sessionId: result.sessionId!,
        permission: WalletConnectionPermission.requestTransaction,
        chainId: 11155111,
      ),
      throwsA(isA<WalletConnectionException>()),
    );
  });

  test('signing request validates chain and recipient', () {
    const signing = WalletSigningRequest(
      sessionId: 'session',
      requestId: 'request',
      chainId: 11155111,
      to: '0x2222222222222222222222222222222222222222',
      value: '0x01',
      data: '0x',
      actionDescription: 'Send test ETH',
    );

    expect(() => signing.validate(const [SupportedNetworks.sepolia]), returnsNormally);

    const wrongChain = WalletSigningRequest(
      sessionId: 'session',
      requestId: 'request',
      chainId: 1,
      to: '0x2222222222222222222222222222222222222222',
      value: '0x01',
      data: '0x',
      actionDescription: 'Send test ETH',
    );

    expect(
      () => wrongChain.validate(const [SupportedNetworks.sepolia]),
      throwsA(isA<WalletConnectionException>()),
    );
  });

  test('signing result contains only response data', () {
    const result = WalletSigningResult.approved(
      requestId: 'request-1',
      sessionId: 'session-1',
      signedTransaction: '0xdeadbeef',
    );
    final payload = WalletConnectionCodec.encodeSigningResult(result);

    expect(payload, contains('0xdeadbeef'));
    expect(payload, isNot(contains('privateKey')));
    expect(payload, isNot(contains('mnemonic')));
    expect(payload, isNot(contains('seed')));
  });

  test('expired sessions are not active', () {
    final now = DateTime.now().toUtc();
    final session = WalletConnectionSession(
      sessionId: 'session',
      appName: 'NegosMint Task Platform',
      appIdentifier: 'com.negosmint.taskplatform',
      walletAddress: '0x1111111111111111111111111111111111111111',
      network: 'Ethereum Sepolia',
      chainId: 11155111,
      permissions: const [WalletConnectionPermission.readAddress],
      createdAt: now.subtract(const Duration(days: 2)),
      lastUsedAt: now.subtract(const Duration(days: 2)),
      expiresAt: now.subtract(const Duration(minutes: 1)),
      status: WalletConnectionStatus.connected,
    );

    expect(session.isActive, isFalse);
  });
}
