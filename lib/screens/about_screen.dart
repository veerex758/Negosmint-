import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('About')),
    body: ListView(padding: const EdgeInsets.all(22), children: [
      Center(child: Container(width: 72, height: 72, decoration: BoxDecoration(color: AppColors.forest, borderRadius: BorderRadius.circular(22)), child: const Center(child: Text('NM', style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900))))),
      const SizedBox(height: 18),
      const Center(child: Text('NegosMint Wallet', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800))),
      const SizedBox(height: 8),
      const Center(child: Text('Non-custodial • Sepolia testnet', style: TextStyle(color: Colors.black54))),
      const SizedBox(height: 26),
      const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('A security-first wallet for the NegosMint ecosystem. This build is intentionally limited to Ethereum Sepolia testnet while wallet functionality is being developed.', style: TextStyle(height: 1.5)))),
    ]),
  );
}