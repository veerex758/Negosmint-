import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores wallet access preferences and a salted, iterated PIN verifier.
/// The PIN itself is never persisted. All records stay in platform secure
/// storage, not SharedPreferences or an application database.
class WalletSecurityService {
  static const _pinSaltKey = 'wallet.security.pin.salt.v1';
  static const _pinHashKey = 'wallet.security.pin.hash.v1';
  static const _failedAttemptsKey = 'wallet.security.pin.failures.v1';
  static const _lockoutUntilKey = 'wallet.security.pin.lockout_until.v1';
  static const _biometricEnabledKey = 'wallet.security.biometric_enabled.v1';
  static const _autoLockMinutesKey = 'wallet.security.auto_lock_minutes.v1';

  static const int pinLength = 6;
  static const int _iterations = 100000;
  static const int _maxFailuresBeforeDelay = 5;
  static const List<int> allowedAutoLockMinutes = [1, 5, 15, 30, 60];

  final FlutterSecureStorage _storage;
  final Random _random;

  WalletSecurityService({
    FlutterSecureStorage? storage,
    Random? random,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _random = random ?? Random.secure();

  Future<bool> hasPin() async =>
      (await _storage.read(key: _pinSaltKey)) != null &&
      (await _storage.read(key: _pinHashKey)) != null;

  Future<void> setPin(String pin) async {
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      throw const FormatException('PIN must contain exactly 6 digits.');
    }
    final saltBytes = List<int>.generate(16, (_) => _random.nextInt(256));
    final salt = base64UrlEncode(saltBytes);
    final hash = _derivePinHash(pin, salt);
    await _storage.write(key: _pinSaltKey, value: salt);
    await _storage.write(key: _pinHashKey, value: hash);
    await _clearFailures();
  }

  Future<void> removePin() async {
    await _storage.delete(key: _pinSaltKey);
    await _storage.delete(key: _pinHashKey);
    await _clearFailures();
  }

  Future<bool> verifyPin(String pin) async {
    final lockout = await lockoutRemaining();
    if (lockout > Duration.zero) return false;

    final salt = await _storage.read(key: _pinSaltKey);
    final expected = await _storage.read(key: _pinHashKey);
    if (salt == null || expected == null) return false;

    final actual = _derivePinHash(pin, salt);
    if (_constantTimeEquals(actual, expected)) {
      await _clearFailures();
      return true;
    }

    final raw = await _storage.read(key: _failedAttemptsKey);
    final failures = (int.tryParse(raw ?? '') ?? 0) + 1;
    await _storage.write(key: _failedAttemptsKey, value: '$failures');
    if (failures >= _maxFailuresBeforeDelay) {
      final excess = failures - _maxFailuresBeforeDelay;
      final seconds = min(900, 30 * (1 << min(excess, 5)));
      final until = DateTime.now().add(Duration(seconds: seconds));
      await _storage.write(
        key: _lockoutUntilKey,
        value: '${until.millisecondsSinceEpoch}',
      );
    }
    return false;
  }

  Future<int> failedAttempts() async {
    final value = await _storage.read(key: _failedAttemptsKey);
    return int.tryParse(value ?? '') ?? 0;
  }

  Future<Duration> lockoutRemaining() async {
    final value = await _storage.read(key: _lockoutUntilKey);
    final epoch = int.tryParse(value ?? '');
    if (epoch == null) return Duration.zero;
    final remaining =
        DateTime.fromMillisecondsSinceEpoch(epoch).difference(DateTime.now());
    if (remaining <= Duration.zero) {
      await _storage.delete(key: _lockoutUntilKey);
      return Duration.zero;
    }
    return remaining;
  }

  Future<void> _clearFailures() async {
    await _storage.delete(key: _failedAttemptsKey);
    await _storage.delete(key: _lockoutUntilKey);
  }

  Future<bool> biometricUnlockEnabled() async {
    final value = await _storage.read(key: _biometricEnabledKey);
    return value == null || value == 'true';
  }

  Future<void> setBiometricUnlockEnabled(bool enabled) =>
      _storage.write(key: _biometricEnabledKey, value: '$enabled');

  Future<int> autoLockMinutes() async {
    final value = await _storage.read(key: _autoLockMinutesKey);
    final parsed = int.tryParse(value ?? '');
    return allowedAutoLockMinutes.contains(parsed) ? parsed! : 5;
  }

  Future<void> setAutoLockMinutes(int minutes) async {
    if (!allowedAutoLockMinutes.contains(minutes)) {
      throw ArgumentError.value(minutes, 'minutes');
    }
    await _storage.write(key: _autoLockMinutesKey, value: '$minutes');
  }

  String _derivePinHash(String pin, String salt) {
    final key = utf8.encode(pin);
    final saltBytes = utf8.encode(salt);
    var block = Hmac(sha256, key).convert([
      ...saltBytes,
      0,
      0,
      0,
      1,
    ]).bytes;
    final output = List<int>.from(block);
    for (var i = 1; i < _iterations; i++) {
      block = Hmac(sha256, key).convert(block).bytes;
      for (var j = 0; j < output.length; j++) {
        output[j] ^= block[j];
      }
    }
    return base64UrlEncode(output);
  }

  bool _constantTimeEquals(String left, String right) {
    final a = utf8.encode(left);
    final b = utf8.encode(right);
    var difference = a.length ^ b.length;
    final length = min(a.length, b.length);
    for (var i = 0; i < length; i++) {
      difference |= a[i] ^ b[i];
    }
    return difference == 0;
  }
}
