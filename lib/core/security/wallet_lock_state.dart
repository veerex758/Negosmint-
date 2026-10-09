import 'package:flutter/foundation.dart';

/// True while a wallet lock screen is active. Used to prevent the inactivity
/// timer from navigating over the lock screen itself.
final ValueNotifier<bool> walletLockActive = ValueNotifier<bool>(false);
