import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Security')),
    body: ListView(padding: const EdgeInsets.all(22), children: [
      _Header(icon: Icons.shield_outlined, title: 'Wallet security', body: 'NegosMint Wallet is non-custodial. Your recovery phrase and private keys stay on your device.'),
      const SizedBox(height: 18),
      const _Item(icon: Icons.lock_outline, title: 'Local key protection', body: 'Wallet secrets are stored using the device secure storage layer.'),
      const _Item(icon: Icons.cloud_off_outlined, title: 'No server backup', body: 'Your recovery phrase is not uploaded to NegosMint servers.'),
      const _Item(icon: Icons.warning_amber_rounded, title: 'Stay protected', body: 'Never share your recovery phrase or private key, even with someone claiming to be support.'),
      const SizedBox(height: 12),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: const [
        Icon(Icons.science_outlined, color: AppColors.forest), SizedBox(width: 12),
        Expanded(child: Text('This build is for Ethereum Sepolia testnet use. Mainnet is disabled.', style: TextStyle(height: 1.45, fontWeight: FontWeight.w600))),
      ]))),
    ]),
  );
}
class _Header extends StatelessWidget {
  final IconData icon; final String title, body;
  const _Header({required this.icon, required this.title, required this.body});
  @override Widget build(BuildContext context) => Card(color: AppColors.mist, child: Padding(padding: const EdgeInsets.all(18), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(icon, color: AppColors.forest, size: 30), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)), const SizedBox(height: 7), Text(body, style: const TextStyle(height: 1.45))]))
  ])));
}
class _Item extends StatelessWidget {
  final IconData icon; final String title, body;
  const _Item({required this.icon, required this.title, required this.body});
  @override Widget build(BuildContext context) => ListTile(contentPadding: const EdgeInsets.symmetric(vertical: 5), leading: Icon(icon, color: AppColors.forest), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Text(body)));
}