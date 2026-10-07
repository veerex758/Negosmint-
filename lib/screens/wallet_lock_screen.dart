import 'package:flutter/material.dart';

import '../core/security/biometric_service.dart';
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
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await _auth.authenticateForSigning();
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeScreen(address: widget.address)),
      );
    } else {
      setState(() {
        _busy = false;
        _error = 'Authentication was not completed. Your wallet remains locked.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
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
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Authenticate on this device to access your wallet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54, height: 1.45),
                  ),
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
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _unlock,
                      icon: const Icon(Icons.fingerprint_rounded),
                      label: Text(_busy ? 'Waiting for authentication…' : 'Unlock wallet'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
