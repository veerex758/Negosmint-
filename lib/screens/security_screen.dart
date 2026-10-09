import 'package:flutter/material.dart';
import '../core/security/biometric_service.dart';
import '../core/security/wallet_security_service.dart';
import '../theme/app_theme.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _security = WalletSecurityService();
  final _biometrics = BiometricService();
  bool _loading = true;
  bool _hasPin = false;
  bool _biometricEnabled = true;
  bool _biometricAvailable = false;
  int _autoLockMinutes = 5;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final values = await Future.wait<Object>([
      _security.hasPin(),
      _security.biometricUnlockEnabled(),
      _security.autoLockMinutes(),
      _biometrics.canAuthenticate(),
    ]);
    if (!mounted) return;
    setState(() {
      _hasPin = values[0] as bool;
      _biometricEnabled = values[1] as bool;
      _autoLockMinutes = values[2] as int;
      _biometricAvailable = values[3] as bool;
      _loading = false;
    });
  }

  Future<String?> _askPin({
    required String title,
    required String message,
    required bool confirm,
  }) async {
    final first = TextEditingController();
    final second = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            TextField(
              controller: first,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: WalletSecurityService.pinLength,
              decoration: const InputDecoration(
                labelText: '6-digit PIN',
                counterText: '',
              ),
            ),
            if (confirm) ...[
              const SizedBox(height: 10),
              TextField(
                controller: second,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: WalletSecurityService.pinLength,
                decoration: const InputDecoration(
                  labelText: 'Confirm PIN',
                  counterText: '',
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!RegExp(r'^\d{6}$').hasMatch(first.text)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter exactly 6 digits.')),
                );
                return;
              }
              if (confirm && first.text != second.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PINs do not match.')),
                );
                return;
              }
              Navigator.pop(dialogContext, first.text);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    first.dispose();
    second.dispose();
    return result;
  }

  Future<bool> _verifyExistingPin() async {
    final pin = await _askPin(
      title: 'Verify current PIN',
      message: 'Confirm your current wallet PIN to change this setting.',
      confirm: false,
    );
    if (pin == null || !mounted) return false;
    final ok = await _security.verifyPin(pin);
    if (!ok && mounted) {
      final remaining = await _security.lockoutRemaining();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(remaining > Duration.zero
              ? 'Too many attempts. Try again in ${remaining.inSeconds} seconds.'
              : 'Incorrect PIN.'),
        ),
      );
    }
    return ok;
  }

  Future<void> _changePin() async {
    if (_hasPin && !await _verifyExistingPin()) return;
    final pin = await _askPin(
      title: _hasPin ? 'Change wallet PIN' : 'Set wallet PIN',
      message: 'Choose a 6-digit PIN. Avoid birthdays or repeated digits.',
      confirm: true,
    );
    if (pin == null) return;
    await _security.setPin(pin);
    if (!mounted) return;
    setState(() => _hasPin = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Wallet PIN saved securely.')),
    );
  }

  Future<void> _removePin() async {
    if (!await _verifyExistingPin()) return;
    if (!_biometricEnabled || !_biometricAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Keep your PIN unless device authentication is enabled and supported on this device.',
          ),
        ),
      );
      return;
    }
    await _security.removePin();
    if (mounted) setState(() => _hasPin = false);
  }

  Future<void> _setBiometrics(bool enabled) async {
    if (enabled && !_biometricAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No device authentication method is available.'),
        ),
      );
      return;
    }
    if (!enabled && !_hasPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Set a wallet PIN before disabling device authentication.'),
        ),
      );
      return;
    }
    if (!enabled && !await _verifyExistingPin()) return;
    if (enabled && !await _biometrics.authenticateForSigning()) return;
    await _security.setBiometricUnlockEnabled(enabled);
    if (mounted) setState(() => _biometricEnabled = enabled);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Security')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.mist,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, color: AppColors.forest, size: 30),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Wallet security',
                          style: TextStyle(
                              fontSize: 21, fontWeight: FontWeight.w800)),
                      SizedBox(height: 7),
                      Text(
                        'Your recovery phrase and keys stay on this device. Security settings are stored in platform secure storage.',
                        style: TextStyle(height: 1.45),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.pin_outlined),
                  title: Text(_hasPin ? 'Change wallet PIN' : 'Set wallet PIN'),
                  subtitle: Text(_hasPin
                      ? 'A 6-digit PIN is configured'
                      : 'Add a PIN as a local unlock option'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _changePin,
                ),
                if (_hasPin) ...[
                  const Divider(height: 1, indent: 72),
                  ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: const Text('Remove wallet PIN'),
                    subtitle: const Text('Requires your current PIN'),
                    onTap: _removePin,
                  ),
                ],
                const Divider(height: 1, indent: 72),
                SwitchListTile(
                  secondary: const Icon(Icons.fingerprint_rounded),
                  title: const Text('Device authentication'),
                  subtitle: Text(_biometricAvailable
                      ? 'Use biometrics or the device passcode to unlock'
                      : 'No supported device authentication detected'),
                  value: _biometricEnabled,
                  onChanged: _setBiometrics,
                ),
                const Divider(height: 1, indent: 72),
                ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: const Text('Auto-lock'),
                  subtitle: Text('Lock after $_autoLockMinutes minute(s) in background'),
                  trailing: DropdownButton<int>(
                    value: _autoLockMinutes,
                    underline: const SizedBox.shrink(),
                    items: WalletSecurityService.allowedAutoLockMinutes
                        .map((minutes) => DropdownMenuItem(
                              value: minutes,
                              child: Text('$minutes min'),
                            ))
                        .toList(),
                    onChanged: (value) async {
                      if (value == null) return;
                      await _security.setAutoLockMinutes(value);
                      if (mounted) setState(() => _autoLockMinutes = value);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _SecurityNote(
            icon: Icons.lock_outline_rounded,
            title: 'Failed-attempt protection',
            body:
                'After five incorrect PIN attempts, wallet PIN entry is temporarily delayed. Repeated failures increase the delay.',
          ),
          const SizedBox(height: 10),
          const _SecurityNote(
            icon: Icons.visibility_off_outlined,
            title: 'Sensitive-screen protection',
            body:
                'The wallet obscures its content while moving to the background. Auto-lock is applied when you return after the selected interval.',
          ),
          const SizedBox(height: 10),
          const _SecurityNote(
            icon: Icons.cloud_off_outlined,
            title: 'Backup and recovery',
            body:
                'The recovery phrase is not uploaded to a server. Keep an offline backup and verify it before changing or resetting devices.',
          ),
          const SizedBox(height: 10),
          const _SecurityNote(
            icon: Icons.science_outlined,
            title: 'Testnet only',
            body:
                'This build is for Ethereum Sepolia testing. Mainnet is disabled.',
          ),
        ],
      ),
    );
  }
}

class _SecurityNote extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _SecurityNote({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.forest, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    Text(body, style: const TextStyle(height: 1.45)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
