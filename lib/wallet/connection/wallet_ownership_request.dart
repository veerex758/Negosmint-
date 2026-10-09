/// Strict, versioned envelope for the Task App -> Wallet App ownership handoff.
///
/// The envelope is untrusted input. The wallet must still show the exact
/// message and require local user approval before signing it.
class WalletOwnershipRequest {
  const WalletOwnershipRequest({
    required this.challengeId,
    required this.message,
    required this.chainId,
    required this.expiresAt,
  });

  static const protocol = 'negosmint.wallet_ownership_request.v1';
  static const sepoliaChainId = 11155111;
  static const purpose =
      'Purpose: Link this self-custody wallet to the signed-in NegosMint Task Platform account.';
  static const noTransaction =
      'This signature proves address control only. It does not authorize a transaction.';

  final String challengeId;
  final String message;
  final int chainId;
  final DateTime expiresAt;

  bool get isExpired => !DateTime.now().toUtc().isBefore(expiresAt);

  static WalletOwnershipRequest parse(
    Object? input, {
    DateTime? now,
  }) {
    if (input is! Map) {
      throw const FormatException('Invalid wallet ownership request.');
    }

    final envelope = Map<String, dynamic>.from(input);
    final type = envelope['type'];
    final challengeId = envelope['challengeId'];
    final message = envelope['message'];
    final chainId = envelope['chainId'];
    final expiryValue = envelope['expiresAt'];

    if (type != protocol ||
        challengeId is! String ||
        challengeId.trim().isEmpty ||
        challengeId.length > 64 ||
        message is! String ||
        message.isEmpty ||
        message.length > 2000 ||
        chainId is! int ||
        chainId != sepoliaChainId ||
        expiryValue is! String) {
      throw const FormatException('Invalid wallet ownership request.');
    }

    final expiresAt = DateTime.tryParse(expiryValue)?.toUtc();
    final currentTime = (now ?? DateTime.now()).toUtc();
    if (expiresAt == null || !currentTime.isBefore(expiresAt)) {
      throw const FormatException('Wallet ownership request has expired.');
    }

    final lines = message.split('\n');
    final userIdLine = lines.where((line) => line.startsWith('User ID: '));
    final nonceLine = lines.where((line) => line.startsWith('Nonce: '));
    final expiryLine = 'Expires At: ${expiresAt.toIso8601String()}';
    if (lines.length < 9 ||
        lines.first != 'NegosMint Wallet Ownership Verification' ||
        userIdLine.length != 1 ||
        userIdLine.single.substring('User ID: '.length).trim().isEmpty ||
        nonceLine.length != 1 ||
        nonceLine.single.substring('Nonce: '.length).trim().isEmpty ||
        !lines.contains('Challenge ID: $challengeId') ||
        !lines.contains('Chain ID: $sepoliaChainId') ||
        !lines.contains(expiryLine) ||
        !lines.contains(purpose) ||
        !lines.contains(noTransaction) ||
        !lines.contains('If you did not initiate this request, reject it.')) {
      throw const FormatException('Invalid wallet ownership message.');
    }

    return WalletOwnershipRequest(
      challengeId: challengeId,
      message: message,
      chainId: chainId,
      expiresAt: expiresAt,
    );
  }

  Map<String, dynamic> toEnvelope() => {
        'type': protocol,
        'challengeId': challengeId,
        'message': message,
        'chainId': chainId,
        'expiresAt': expiresAt.toUtc().toIso8601String(),
      };
}
