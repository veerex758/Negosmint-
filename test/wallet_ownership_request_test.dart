import 'package:flutter_test/flutter_test.dart';
import 'package:negosmint_wallet/wallet/connection/wallet_ownership_request.dart';

void main() {
  final now = DateTime.utc(2026, 10, 9, 12);
  final expiry = now.add(const Duration(minutes: 2));
  const challengeId = 'challenge-123';
  final message = [
    'NegosMint Wallet Ownership Verification',
    'Purpose: Link this self-custody wallet to the signed-in NegosMint Task Platform account.',
    'User ID: user-123',
    'Challenge ID: challenge-123',
    'Nonce: random-nonce',
    'Chain ID: 11155111',
    'Expires At: 2026-10-09T12:02:00.000Z',
    'This signature proves address control only. It does not authorize a transaction.',
    'If you did not initiate this request, reject it.',
  ].join('\n');

  Map<String, dynamic> validEnvelope() => {
        'type': WalletOwnershipRequest.protocol,
        'challengeId': challengeId,
        'message': message,
        'chainId': WalletOwnershipRequest.sepoliaChainId,
        'expiresAt': expiry.toIso8601String(),
      };

  test('parses a valid versioned ownership request', () {
    final request = WalletOwnershipRequest.parse(validEnvelope(), now: now);

    expect(request.challengeId, challengeId);
    expect(request.message, message);
    expect(request.chainId, WalletOwnershipRequest.sepoliaChainId);
    expect(request.expiresAt, expiry);
  });

  test('rejects unknown protocol versions', () {
    final envelope = validEnvelope()..['type'] = 'negosmint.unknown';
    expect(
      () => WalletOwnershipRequest.parse(envelope, now: now),
      throwsFormatException,
    );
  });

  test('rejects a chain other than Sepolia', () {
    final envelope = validEnvelope()..['chainId'] = 1;
    expect(
      () => WalletOwnershipRequest.parse(envelope, now: now),
      throwsFormatException,
    );
  });

  test('rejects an expired request', () {
    final envelope = validEnvelope()
      ..['expiresAt'] = now.toIso8601String();
    expect(
      () => WalletOwnershipRequest.parse(envelope, now: now),
      throwsFormatException,
    );
  });

  test('rejects a message whose challenge ID does not match the envelope', () {
    final envelope = validEnvelope()
      ..['message'] = message.replaceFirst(challengeId, 'other-challenge');
    expect(
      () => WalletOwnershipRequest.parse(envelope, now: now),
      throwsFormatException,
    );
  });

  test('rejects requests that omit the no-transaction warning', () {
    final envelope = validEnvelope()
      ..['message'] = message.replaceFirst(
        WalletOwnershipRequest.noTransaction,
        'Sign this.',
      );
    expect(
      () => WalletOwnershipRequest.parse(envelope, now: now),
      throwsFormatException,
    );
  });


  test('rejects an envelope expiry that differs from the signed message', () {
    final envelope = validEnvelope()
      ..['expiresAt'] = now.add(const Duration(minutes: 4)).toIso8601String();
    expect(
      () => WalletOwnershipRequest.parse(envelope, now: now),
      throwsFormatException,
    );
  });

  test('rejects a request without an account binding line', () {
    final envelope = validEnvelope()
      ..['message'] = message.replaceFirst('User ID: user-123\n', '');
    expect(
      () => WalletOwnershipRequest.parse(envelope, now: now),
      throwsFormatException,
    );
  });

  test('round-trips the request through an ownership deep link', () {
    final request = WalletOwnershipRequest.parse(validEnvelope(), now: now);
    final uri = Uri.parse(request.toDeepLink());
    final restored = WalletOwnershipRequest.parseDeepLink(uri, now: now);

    expect(uri.scheme, 'negosmintwallet');
    expect(uri.host, 'ownership');
    expect(restored.challengeId, request.challengeId);
    expect(restored.message, request.message);
    expect(restored.chainId, request.chainId);
    expect(restored.expiresAt, request.expiresAt);
  });

  test('rejects ownership links with the wrong host', () {
    final uri = Uri.parse('negosmintwallet://connect?request=eyJ0eXBlIjoi');
    expect(
      () => WalletOwnershipRequest.parseDeepLink(uri, now: now),
      throwsFormatException,
    );
  });

  test('serializes a parsed request using the versioned envelope', () {
    final request = WalletOwnershipRequest.parse(validEnvelope(), now: now);
    expect(request.toEnvelope()['type'], WalletOwnershipRequest.protocol);
    expect(request.toEnvelope()['challengeId'], challengeId);
  });
}
