import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'wallet_connection_session.dart';

/// Persists connection metadata only. No key material is accepted by this class.
class WalletConnectionStorage {
  static const _sessionsKey = 'wallet.connection.sessions.v1';
  final FlutterSecureStorage _storage;

  const WalletConnectionStorage({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  Future<List<WalletConnectionSession>> loadSessions() async {
    final raw = await _storage.read(key: _sessionsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) => WalletConnectionSession.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveSessions(List<WalletConnectionSession> sessions) =>
      _storage.write(
        key: _sessionsKey,
        value: jsonEncode(sessions.map((session) => session.toJson()).toList()),
      );

  Future<void> clear() => _storage.delete(key: _sessionsKey);
}
