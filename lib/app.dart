import 'dart:async';

import 'package:flutter/material.dart';

import 'core/security/wallet_security_service.dart';
import 'core/security/biometric_service.dart';
import 'core/security/wallet_lock_state.dart';
import 'core/wallet/wallet_service.dart';
import 'screens/splash_screen.dart';
import 'screens/wallet_lock_screen.dart';
import 'theme/app_theme.dart';

final GlobalKey<NavigatorState> walletNavigatorKey = GlobalKey<NavigatorState>();

class NegosMintWalletApp extends StatelessWidget {
  const NegosMintWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: walletNavigatorKey,
      title: 'NegosMint Wallet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppColors.dark,
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
      builder: (context, child) => _SensitiveScreenGuard(
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}

class _SensitiveScreenGuard extends StatefulWidget {
  final Widget child;
  const _SensitiveScreenGuard({required this.child});

  @override
  State<_SensitiveScreenGuard> createState() => _SensitiveScreenGuardState();
}

class _SensitiveScreenGuardState extends State<_SensitiveScreenGuard>
    with WidgetsBindingObserver {
  final _security = WalletSecurityService();
  Timer? _inactivityTimer;
  DateTime? _backgroundedAt;
  bool _obscured = false;
  bool _locking = false;
  bool _isInBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    walletLockActive.addListener(_onLockStateChanged);
    _scheduleAutoLock();
  }

  Future<void> _scheduleAutoLock() async {
    _inactivityTimer?.cancel();
    try {
      final address = await WalletService().getPublicAddress();
      if (!mounted || address == null || address.isEmpty || _locking || walletLockActive.value) return;
      final minutes = await _security.autoLockMinutes();
      _inactivityTimer = Timer(Duration(minutes: minutes), _lockWallet);
    } catch (_) {
      // A storage failure must not expose a secret; the background overlay
      // still activates independently of the inactivity timer.
    }
  }

  void _onLockStateChanged() {
    if (walletLockActive.value) {
      _inactivityTimer?.cancel();
    } else {
      _scheduleAutoLock();
    }
  }

  void _onUserActivity(PointerEvent _) {
    if (_obscured || _locking || _isInBackground) return;
    _scheduleAutoLock();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _isInBackground = true;
      _backgroundedAt ??= DateTime.now();
      if (mounted) setState(() => _obscured = true);
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _isInBackground = false;
      _resumeSecurely();
    }
  }

  Future<void> _resumeSecurely() async {
    final backgroundedAt = _backgroundedAt;
    _backgroundedAt = null;
    final minutes = await _security.autoLockMinutes();
    final elapsed = backgroundedAt == null
        ? Duration.zero
        : DateTime.now().difference(backgroundedAt);
    // A lock screen may itself trigger a lifecycle transition while the OS
    // authentication prompt is visible. Never stack a second lock route.
    if (walletLockActive.value) {
      if (mounted) setState(() => _obscured = false);
      return;
    }
    if (backgroundedAt != null && elapsed >= Duration(minutes: minutes)) {
      await _lockWallet();
    } else {
      if (mounted) setState(() => _obscured = false);
      _scheduleAutoLock();
    }
  }

  Future<void> _lockWallet() async {
    if (_locking || !mounted) return;
    _inactivityTimer?.cancel();
    final address = await WalletService().getPublicAddress();
    if (!mounted || address == null || address.isEmpty) {
      if (mounted) setState(() => _obscured = false);
      return;
    }

    // Do not navigate to an unrecoverable lock screen if neither a PIN nor
    // supported device authentication is configured on this device.
    final hasPin = await _security.hasPin();
    final biometricEnabled = await _security.biometricUnlockEnabled();
    final canAuthenticate =
        biometricEnabled && await BiometricService().canAuthenticate();
    if (!mounted) return;
    if (!hasPin && !canAuthenticate) {
      setState(() => _obscured = false);
      _scheduleAutoLock();
      return;
    }

    _locking = true;
    walletLockActive.value = true;
    setState(() => _obscured = true);
    walletNavigatorKey.currentState?.pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(
        builder: (_) => WalletLockScreen(address: address),
      ),
      (_) => false,
    );
    // Keep the privacy overlay up until the lock route is established.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (mounted) setState(() => _obscured = false);
    _locking = false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    walletLockActive.removeListener(_onLockStateChanged);
    _inactivityTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onUserActivity,
        onPointerSignal: _onUserActivity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (_obscured)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0xFF03140D),
                  child: Center(
                    child: Icon(
                      Icons.lock_rounded,
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}
