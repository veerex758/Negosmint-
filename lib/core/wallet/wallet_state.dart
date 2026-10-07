import 'package:flutter/foundation.dart';

enum WalletStatus { uninitialized, locked, unlocked }

class WalletState extends ChangeNotifier {
  WalletStatus _status = WalletStatus.uninitialized;
  String? _address;

  WalletStatus get status => _status;
  String? get address => _address;
  bool get isInitialized => _status != WalletStatus.uninitialized;
  bool get isLocked => _status == WalletStatus.locked;
  bool get isUnlocked => _status == WalletStatus.unlocked;

  void initialized({required String address}) {
    _address = address;
    _status = WalletStatus.locked;
    notifyListeners();
  }

  void unlock() {
    if (_address == null) return;
    _status = WalletStatus.unlocked;
    notifyListeners();
  }

  void lock() {
    _status = isInitialized ? WalletStatus.locked : WalletStatus.uninitialized;
    notifyListeners();
  }

  void reset() {
    _address = null;
    _status = WalletStatus.uninitialized;
    notifyListeners();
  }
}
