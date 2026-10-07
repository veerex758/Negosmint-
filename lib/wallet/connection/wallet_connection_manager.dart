import 'dart:math';

import '../../core/network/network_config.dart';
import '../../core/wallet/wallet_service.dart';
import 'wallet_connection_request.dart';
import 'wallet_connection_result.dart';
import 'wallet_connection_session.dart';
import 'wallet_connection_storage.dart';

class WalletConnectionManager {
  final WalletService _wallet;
  final WalletConnectionStorage _storage;
  final List<NetworkConfig> _networks;

  WalletConnectionManager({
    WalletService? wallet,
    WalletConnectionStorage? storage,
    List<NetworkConfig>? networks,
  })  : _wallet = wallet ?? WalletService(),
        _storage = storage ?? const WalletConnectionStorage(),
        _networks = networks ?? const [SupportedNetworks.sepolia];

  Future<WalletConnectionRequest> handleIncomingRequest(
    WalletConnectionRequest request,
  ) async {
    if (request.isExpired) {
      throw const WalletConnectionException('Connection request has expired.');
    }
    request.validateNetwork(_networks);
    _validateApplication(request);
    final existing = await getActiveConnections();
    if (existing.any((session) => session.appIdentifier == request.appIdentifier)) {
      throw const WalletConnectionException('This application is already connected.');
    }
    return request;
  }

  Future<WalletConnectionResult> approveConnection(
    WalletConnectionRequest request,
  ) async {
    await handleIncomingRequest(request);
    final address = await _wallet.getPublicAddress();
    if (address == null || address.isEmpty) {
      throw const WalletConnectionException('Wallet is not initialized.');
    }
    final network = _networks.firstWhere((n) => n.chainId == request.chainId);
    final now = DateTime.now().toUtc();
    final session = WalletConnectionSession(
      sessionId: _sessionId(),
      appName: request.appName,
      appIdentifier: request.appIdentifier,
      walletAddress: address,
      network: network.name,
      chainId: network.chainId,
      permissions: request.permissions,
      createdAt: now,
      lastUsedAt: now,
      expiresAt: now.add(const Duration(days: 30)),
      status: WalletConnectionStatus.connected,
    );
    final sessions = await _storage.loadSessions();
    await _storage.saveSessions([
      ...sessions.where((s) => s.sessionId != session.sessionId),
      session,
    ]);
    return WalletConnectionResult.approved(session, requestId: request.requestId);
  }

  WalletConnectionResult rejectConnection(WalletConnectionRequest request) =>
      WalletConnectionResult.rejected(requestId: request.requestId);

  Future<List<WalletConnectionSession>> getActiveConnections() async {
    final sessions = await _storage.loadSessions();
    final now = DateTime.now().toUtc();
    final updated = sessions.map((session) {
      if (session.status == WalletConnectionStatus.connected &&
          !now.isBefore(session.expiresAt)) {
        return session.copyWith(status: WalletConnectionStatus.expired);
      }
      return session;
    }).toList();
    if (!_same(sessions, updated)) await _storage.saveSessions(updated);
    return updated
        .where((session) => session.status == WalletConnectionStatus.connected)
        .toList(growable: false);
  }

  Future<WalletConnectionSession?> findSession(String sessionId) async {
    final sessions = await _storage.loadSessions();
    for (final session in sessions) {
      if (session.sessionId == sessionId) return session;
    }
    return null;
  }

  Future<void> revokeConnection(String sessionId) async {
    final sessions = await _storage.loadSessions();
    final updated = sessions.map((session) => session.sessionId == sessionId
        ? session.copyWith(status: WalletConnectionStatus.revoked)
        : session).toList();
    await _storage.saveSessions(updated);
  }

  Future<void> disconnect(String sessionId) => revokeConnection(sessionId);

  Future<bool> isConnected(String appIdentifier) async =>
      (await getActiveConnections()).any((s) => s.appIdentifier == appIdentifier);

  Future<void> authorizeRequest({
    required String sessionId,
    required WalletConnectionPermission permission,
    required int chainId,
  }) async {
    final session = await findSession(sessionId);
    if (session == null || !session.isActive) {
      throw const WalletConnectionException('Connection is not active.');
    }
    if (session.chainId != chainId) {
      throw const WalletConnectionException('Signing request uses the wrong network.');
    }
    if (!session.hasPermission(permission)) {
      throw const WalletConnectionException('Application is not authorized for this request.');
    }
    if (permission == WalletConnectionPermission.requestTransaction) {
      if (!session.hasPermission(WalletConnectionPermission.requestSignature)) {
        throw const WalletConnectionException('Transaction signing permission is not authorized.');
      }
    }
  }

  void _validateApplication(WalletConnectionRequest request) {
    // V1 allowlist. This prevents arbitrary links from impersonating the Task Platform.
    const allowed = <String, String>{
      'com.negosmint.taskplatform': 'NegosMint Task Platform',
    };
    final expected = allowed[request.appIdentifier];
    if (expected == null || expected != request.appName) {
      throw const WalletConnectionException('Unknown requesting application.');
    }
  }

  String _sessionId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  bool _same(List<WalletConnectionSession> a, List<WalletConnectionSession> b) =>
      a.length == b.length &&
      List.generate(a.length, (i) => a[i].toJson().toString() == b[i].toJson().toString())
          .every((v) => v);
}
