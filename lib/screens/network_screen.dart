import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class NetworkScreen extends StatelessWidget {
  const NetworkScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Network')),
    body: ListView(padding: const EdgeInsets.all(22), children: [
      Card(color: AppColors.mist, child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
        Icon(Icons.science_outlined, color: AppColors.forest, size: 34),
        SizedBox(height: 14), Text('Ethereum Sepolia', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        SizedBox(height: 7), Text('Testnet', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.forest)),
        SizedBox(height: 18), Text('Chain ID', style: TextStyle(color: Colors.black54)), SizedBox(height: 3), Text('11155111', style: TextStyle(fontWeight: FontWeight.w700)),
        SizedBox(height: 14), Text('Mainnet', style: TextStyle(color: Colors.black54)), SizedBox(height: 3), Text('Disabled in this build', style: TextStyle(fontWeight: FontWeight.w700)),
      ])),
    ]),
  );
}