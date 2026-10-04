import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class NetworkScreen extends StatelessWidget {
  const NetworkScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Network')),
        body: ListView(
          padding: const EdgeInsets.all(22),
          children: const [
            Card(
              color: AppColors.mist,
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.science_outlined,
                          color: AppColors.forest,
                          size: 32,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Ethereum Sepolia',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    _NetworkBadge(),
                    SizedBox(height: 22),
                    _NetworkRow(label: 'Chain ID', value: '11155111'),
                    SizedBox(height: 14),
                    _NetworkRow(
                      label: 'Mainnet',
                      value: 'Disabled in this build',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

class _NetworkBadge extends StatelessWidget {
  const _NetworkBadge();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.forest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Text(
          'TESTNET ONLY',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
          ),
        ),
      );
}

class _NetworkRow extends StatelessWidget {
  final String label;
  final String value;

  const _NetworkRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.black54),
            ),
          ),
        ],
      );
}
