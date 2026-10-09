import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/wallet/payment_uri.dart';
import '../theme/app_theme.dart';

/// Camera scanner for plain wallet addresses and supported Ethereum payment URIs.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  bool _handlingResult = false;
  String? _errorMessage;

  void _onDetect(BarcodeCapture capture) {
    if (_handlingResult) return;

    String? rawValue;
    for (final barcode in capture.barcodes) {
      final candidate = barcode.rawValue;
      if (candidate != null && candidate.trim().isNotEmpty) {
        rawValue = candidate;
        break;
      }
    }
    if (rawValue == null) return;

    _handlingResult = true;
    try {
      final request = PaymentUriParser.parse(rawValue);
      if (!mounted) return;
      Navigator.of(context).pop<PaymentRequest>(request);
    } on PaymentUriException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        setState(() {
          _errorMessage = null;
          _handlingResult = false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Scan payment QR')),
        body: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(onDetect: _onDetect),
            IgnorePointer(
              child: Center(
                child: Container(
                  width: 270,
                  height: 270,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.sage, width: 4),
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 22,
              right: 22,
              bottom: 28,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.charcoal.withValues(alpha: .92),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Scan an address or Ethereum payment request',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Ethereum Sepolia only • Chain ID 11155111',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFFFD2C7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}
