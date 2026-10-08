import '../../core/network/network_config.dart';

enum WalletConnectionPermission {
  readAddress,
  readNetwork,
  requestSignature,
  requestTransaction,
}

extension WalletConnectionPermissionCodec on WalletConnectionPermission {
  String get wireName => switch (this) {
        WalletConnectionPermission.readAddress => 'READ_ADDRESS',
        WalletConnectionPermission.readNetwork => 'READ_NETWORK',
        WalletConnectionPermission.requestSignature => 'REQUEST_SIGNATURE',
        WalletConnectionPermission.requestTransaction => 'REQUEST_TRANSACTION',
      };

  String get label => switch (this) {
        WalletConnectionPermission.readAddress => 'View wallet address',
        WalletConnectionPermission.readNetwork => 'View supported network',
        WalletConnectionPermission.requestSignature =>
          'Request message signatures',
        WalletConnectionPermission.requestTransaction =>
          'Request transaction signatures',
      };

  static WalletConnectionPermission? fromWire(String value) {
    return WalletConnectionPermission.values
        .cast<WalletConnectionPermission?>()
        .firstWhere(
          (permission) => permission!.wireName == value,
          orElse: () => null,
        );
  }
}

class WalletConnectionRequest {
  final String requestId;
  final String appName;
  final String appIdentifier;
  final List<WalletConnectionPermission> permissions;
  final int chainId;
  final String? callback;
  final DateTime expiresAt;

  const WalletConnectionRequest({
    required this.requestId,
    required this.appName,
    required this.appIdentifier,
    required this.permissions,
    required this.chainId,
    required this.callback,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);

  bool get requestsSigning =>
      permissions.contains(WalletConnectionPermission.requestSignature) ||
      permissions.contains(WalletConnectionPermission.requestTransaction);

  NetworkConfig validateNetwork(Iterable<NetworkConfig> networks) {
    for (final network in networks) {
      if (network.chainId == chainId) return network;
    }
    throw const WalletConnectionException('Unsupported wallet network.');
  }

  Map<String, dynamic> toJson() => {
        'requestId': requestId,
        'appName': appName,
        'appIdentifier': appIdentifier,
        'permissions': permissions.map((p) => p.wireName).toList(),
        'chainId': chainId,
        'callback': callback,
        'expiresAt': expiresAt.toUtc().toIso8601String(),
      };

  static WalletConnectionRequest fromJson(Map<String, dynamic> json) {
    final requestId = _requiredString(json, 'requestId');
    final appName = _requiredString(json, 'appName');
    final appIdentifier = _requiredString(json, 'appIdentifier');
    final chainId = json['chainId'];
    final expiresAt = DateTime.tryParse(_requiredString(json, 'expiresAt'));

    if (requestId.length > 128 ||
        appName.length > 100 ||
        appIdentifier.length > 200 ||
        chainId is! int ||
        expiresAt == null ||
        expiresAt.isBefore(
            DateTime.now().toUtc().subtract(const Duration(minutes: 1)))) {
      throw const WalletConnectionException(
          'Invalid or expired connection request.');
    }

    final rawPermissions = json['permissions'];
    if (rawPermissions is! List ||
        rawPermissions.isEmpty ||
        rawPermissions.length > 4) {
      throw const WalletConnectionException('Invalid connection permissions.');
    }

    final permissions = <WalletConnectionPermission>[];
    for (final raw in rawPermissions) {
      if (raw is! String) {
        throw const WalletConnectionException('Invalid connection permission.');
      }
      final permission = WalletConnectionPermissionCodec.fromWire(raw);
      if (permission == null || permissions.contains(permission)) {
        throw const WalletConnectionException('Invalid connection permission.');
      }
      permissions.add(permission);
    }

    final callback = json['callback'];
    if (callback != null && callback is! String) {
      throw const WalletConnectionException('Invalid connection callback.');
    }
    if (callback is String) {
      if (callback.length > 2048) {
        throw const WalletConnectionException(
            'Connection callback is too long.');
      }
      _validateCallback(callback);
    }

    return WalletConnectionRequest(
      requestId: requestId,
      appName: appName,
      appIdentifier: appIdentifier,
      permissions: List.unmodifiable(permissions),
      chainId: chainId,
      callback: callback as String?,
      expiresAt: expiresAt.toUtc(),
    );
  }

  static void _validateCallback(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const WalletConnectionException('Invalid connection callback.');
    }

    if (uri.userInfo.isNotEmpty || uri.fragment.isNotEmpty) {
      throw const WalletConnectionException('Invalid connection callback.');
    }

    if (uri.scheme.toLowerCase() != 'https') {
      throw const WalletConnectionException(
        'Only HTTPS connection callbacks are supported.',
      );
    }
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw WalletConnectionException('Missing $key.');
    }
    return value.trim();
  }
}

class WalletConnectionException implements Exception {
  final String message;
  const WalletConnectionException(this.message);

  @override
  String toString() => 'WalletConnectionException: $message';
}
