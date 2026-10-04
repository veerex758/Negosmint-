import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class NetworkScreen extends StatelessWidget {
  const NetworkScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Network')),
    body: ListView(padding: const EdgeInsets.all(22), children: [
      Card(
        color: AppColors.mist,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            Row(children: [
              Icon(Icons.science_outlined, color: AppColors.forest, size: 32),
              SizedBox(width: 12),
              Expanded(child: Text('Ethereum Sepolia', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
            ]),
            SizedBox(height: 10),
            _NetworkBadge(),
            SizedBox(height: 22),
            _NetworkRow(label: 'Chain ID', value: '11155111'),
            SizedBox(height: 14),
            _NetworkRow(label: 'Mainnet', value: 'Disabled in this build'),
          ]),
        ),
      ),
    ]),
  );
}