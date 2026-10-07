enum WalletSigningResultStatus { approved, rejected }

class WalletSigningResult {
  final WalletSigningResultStatus status;
  final String requestId;
  final String? sessionId;
  final String? signedTransaction;
  final String? errorCode;

  const WalletSigningResult({
    required this.status,
    required this.requestId,
    required this.sessionId,
    required this.signedTransaction,
    required this.errorCode,
  });

  const WalletSigningResult.approved({
    required String requestId,
    required String sessionId,
    required String signedTransaction,
  }) : this(
          status: WalletSigningResultStatus.approved,
          requestId: requestId,
          sessionId: sessionId,
          signedTransaction: signedTransaction,
          errorCode: null,
        );

  const WalletSigningResult.rejected({
    required String requestId,
    String errorCode = 'USER_REJECTED',
  }) : this(
          status: WalletSigningResultStatus.rejected,
          requestId: requestId,
          sessionId: null,
          signedTransaction: null,
          errorCode: errorCode,
        );

  Map<String, dynamic> toJson() => {
        'status': status.name,
        'requestId': requestId,
        'sessionId': sessionId,
        'signedTransaction': signedTransaction,
        'errorCode': errorCode,
      };
}
