import 'wallet_connection_session.dart';

enum WalletConnectionResultStatus { approved, rejected }

class WalletConnectionResult {
  final WalletConnectionResultStatus status;
  final String requestId;
  final String? sessionId;
  final String? walletAddress;
  final String? network;
  final int? chainId;
  final List<String> permissions;
  final String? errorCode;

  const WalletConnectionResult({
    required this.status,
    required this.requestId,
    required this.sessionId,
    required this.walletAddress,
    required this.network,
    required this.chainId,
    required this.permissions,
    required this.errorCode,
  });

  factory WalletConnectionResult.approved(WalletConnectionSession session, {required String requestId}) =>
      WalletConnectionResult(
        status: WalletConnectionResultStatus.approved,
        requestId: requestId,
        sessionId: session.sessionId,
        walletAddress: session.walletAddress,
        network: session.network,
        chainId: session.chainId,
        permissions: session.permissions.map((p) => p.wireName).toList(),
        errorCode: null,
      );

  factory WalletConnectionResult.rejected({
    required String requestId,
    String errorCode = 'USER_REJECTED',
  }) =>
      WalletConnectionResult(
        status: WalletConnectionResultStatus.rejected,
        requestId: requestId,
        sessionId: null,
        walletAddress: null,
        network: null,
        chainId: null,
        permissions: const [],
        errorCode: errorCode,
      );

  Map<String, dynamic> toJson() => {
        'status': status.name,
        'requestId': requestId,
        'sessionId': sessionId,
        'walletAddress': walletAddress,
        'network': network,
        'chainId': chainId,
        'permissions': permissions,
        'errorCode': errorCode,
      };
}
