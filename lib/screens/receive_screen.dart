import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/app_theme.dart';
import '../core/network/network_config.dart';
import '../core/wallet/payment_uri.dart';

class ReceiveScreen extends StatelessWidget {
  final String address;
  const ReceiveScreen({super.key, required this.address});

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: address));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Address copied')),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Receive')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
          children: [
            const Row(
              children: [
                Icon(Icons.south_west_rounded, color: AppColors.forest),
                SizedBox(width: 10),
                Text(
                  'Receive crypto',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Share your EVM address to receive supported testnet assets.',
              style: TextStyle(color: Colors.black54, height: 1.4),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: AppColors.mist,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                children: [
                  Icon(Icons.public_rounded, color: AppColors.forest),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ethereum Sepolia',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Testnet • Chain ID ${SupportedNetworks.sepolia.chainId} • ETH',
                          style: TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.verified_rounded, color: AppColors.forest),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x18000000),
                      blurRadius: 24,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: PaymentUriParser.isValidAddress(address)
                    ? QrImageView(
                        data: PaymentUriParser.createSepoliaUri(address),
                        version: QrVersions.auto,
                        size: 230,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: AppColors.forest,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: AppColors.charcoal,
                        ),
                      )
                    : const SizedBox(
                        width: 230,
                        height: 230,
                        child: Center(
                          child: Text(
                            'Wallet address is invalid',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppColors.mist,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(Icons.qr_code_2_rounded, color: AppColors.forest),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Scan or copy this Sepolia address. Confirm the network before sending.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your address',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    SelectableText(
                      address,
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: _TactileCopyButton(
                        onPressed: () => _copy(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.mist,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.gold),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Testnet only. Do not send real funds to this wallet yet.',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _TactileCopyButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _TactileCopyButton({required this.onPressed});

  @override
  State<_TactileCopyButton> createState() => _TactileCopyButtonState();
}

class _TactileCopyButtonState extends State<_TactileCopyButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => AnimatedScale(
        scale: _pressed ? .98 : 1,
        duration: const Duration(milliseconds: 90),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          child: FilledButton.icon(
            onPressed: widget.onPressed,
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copy address'),
          ),
        ),
      );
}
