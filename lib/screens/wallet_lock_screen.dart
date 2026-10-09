import 'package:flutter/material.dart';

import '../core/security/biometric_service.dart';
import '../core/security/wallet_security_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class WalletLockScreen extends StatefulWidget {
  final String address;
  const WalletLockScreen({super.key, required this.address});

  @override
  State<WalletLockScreen> createState() => _WalletLockScreenState();
}

class _WalletLockScreenState extends State<WalletLockScreen> {
  final _auth = BiometricService();
  final _security = WalletSecurityService();
  final _pinController = TextEditingController();
  bool _busy = false;
  bool _hasPin = false;
  bool _biometricEnabled = true;
  String? _error;
  Duration _lockout = Duration.zero;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final hasPin = await _security.hasPin();
    final biometricEnabled = await _security.biometricUnlockEnabled();
    final lockout = await _security.lockoutRemaining();
    if (!mounted) return;
    setState(() {
      _hasPin = hasPin;
      _biometricEnabled = biometricEnabled;
      _lockout = lockout;
    });
    if (biometricEnabled) await _unlockWithDevice();
  }

  void _finishUnlock() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => HomeScreen(address: widget.address)),
    );
  }

  Future<void> _unlockWithDevice() async {
    if (_busy || !_biometricEnabled) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await _auth.authenticateForSigning();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      _finishUnlock();
    } else {
      setState(() {
        _error = _hasPin
            ? 'Device authentication was not completed. Enter your wallet PIN instead.'
            : 'Authentication was not completed. Your wallet remains locked.';
      });
    }
  }

  Future<void> _unlockWithPin() async {
    if (_busy || !_hasPin) return;
    final remaining = await _security.lockoutRemaining();
    if (remaining > Duration.zero) {
      if (mounted) {
        setState(() {
          _lockout = remaining;
          _error = 'Too many attempts. Try again in ${remaining.inSeconds} seconds.';
        });
      }
      return;
    }
    final pin = _pinController.text;
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      setState(() => _error = 'Enter your 6-digit wallet PIN.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await _security.verifyPin(pin);
    _pinController.clear();
    if (!mounted) return;
    final nextLockout = await _security.lockoutRemaining();
    setState(() {
      _busy = false;
      _lockout = nextLockout;
      _error = ok
          ? null
          : nextLockout > Duration.zero
              ? 'Too many attempts. Try again in ${nextLockout.inSeconds} seconds.'
              : 'Incorrect PIN. Please try again.';
    });
    if (ok) _finishUnlock();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        color: AppColors.forest,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Wallet locked',
                      style:
                          TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Authenticate on this device to access your wallet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54, height: 1.45),
                    ),
                    if (_hasPin) ...[
                      const SizedBox(height: 24),
                      TextField(
                        controller: _pinController,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        maxLength: WalletSecurityService.pinLength,
                        enabled: !_busy && _lockout == Duration.zero,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          labelText: 'Wallet PIN',
                          counterText: '',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _unlockWithPin(),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _busy || _lockout > Duration.zero
                              ? null
                              : _unlockWithPin,
                          child: Text(_busy ? 'Checking…' : 'Unlock with PIN'),
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 18),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (_biometricEnabled) ...[
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _unlockWithDevice,
                          icon: const Icon(Icons.fingerprint_rounded),
                          label: Text(_busy
                              ? 'Waiting for authentication…'
                              : 'Unlock with device authentication'),
                        ),
                      ),
                    ],
                    if (!_hasPin && !_biometricEnabled)
                      const Padding(
                        padding: EdgeInsets.only(top: 18),
                        child: Text(
                          'No unlock method is configured. Contact support before continuing; do not uninstall the app because that may remove local wallet data.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
