import 'wallet_connection_request.dart';

enum WalletConnectionStatus { pending, connected, revoked, expired }

class WalletConnectionSession {
  final String sessionId;
  final String appName;
  final String appIdentifier;
  final String walletAddress;
  final String network;
  final int chainId;
  final List<WalletConnectionPermission> permissions;
  final DateTime createdAt;
  final DateTime lastUsedAt;
  final DateTime expiresAt;
  final WalletConnectionStatus status;

  const WalletConnectionSession({
    required this.sessionId,
    required this.appName,
    required this.appIdentifier,
    required this.walletAddress,
    required this.network,
    required this.chainId,
    required this.permissions,
    required this.createdAt,
    required this.lastUsedAt,
    required this.expiresAt,
    required this.status,
  });

  bool get isActive =>
      status == WalletConnectionStatus.connected &&
      DateTime.now().toUtc().isBefore(expiresAt);

  bool hasPermission(WalletConnectionPermission permission) =>
      permissions.contains(permission);

  WalletConnectionSession copyWith({
    DateTime? lastUsedAt,
    DateTime? expiresAt,
    WalletConnectionStatus? status,
  }) =>
      WalletConnectionSession(
        sessionId: sessionId,
        appName: appName,
        appIdentifier: appIdentifier,
        walletAddress: walletAddress,
        network: network,
        chainId: chainId,
        permissions: permissions,
        createdAt: createdAt,
        lastUsedAt: lastUsedAt ?? this.lastUsedAt,
        expiresAt: expiresAt ?? this.expiresAt,
        status: status ?? this.status,
      );

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'appName': appName,
        'appIdentifier': appIdentifier,
        'walletAddress': walletAddress,
        'network': network,
        'chainId': chainId,
        'permissions': permissions.map((p) => p.wireName).toList(),
        'createdAt': createdAt.toUtc().toIso8601String(),
        'lastUsedAt': lastUsedAt.toUtc().toIso8601String(),
        'expiresAt': expiresAt.toUtc().toIso8601String(),
        'status': status.name,
      };

  static WalletConnectionSession fromJson(Map<String, dynamic> json) {
    final permissions = (json['permissions'] as List<dynamic>? ?? [])
        .map((value) =>
            WalletConnectionPermissionCodec.fromWire(value.toString()))
        .whereType<WalletConnectionPermission>()
        .toList(growable: false);
    final status = WalletConnectionStatus.values.firstWhere(
      (value) => value.name == json['status'],
      orElse: () => WalletConnectionStatus.revoked,
    );

    final session = WalletConnectionSession(
      sessionId: json['sessionId'] as String,
      appName: json['appName'] as String,
      appIdentifier: json['appIdentifier'] as String,
      walletAddress: json['walletAddress'] as String,
      network: json['network'] as String,
      chainId: json['chainId'] as int,
      permissions: List.unmodifiable(permissions),
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      lastUsedAt: DateTime.parse(json['lastUsedAt'] as String).toUtc(),
      expiresAt: DateTime.parse(json['expiresAt'] as String).toUtc(),
      status: status,
    );
    return session;
  }
}
