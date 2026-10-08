import 'package:flutter/material.dart';

import '../core/wallet/wallet_service.dart';
import '../theme/app_theme.dart';
import '../wallet/connection/wallet_connect_bridge.dart';
import '../wallet/connection/wallet_signing_request.dart';

class WalletConnectSigningRequestScreen extends StatefulWidget {
  final WalletConnectBridge bridge;
  final WalletConnectSessionRequest request;
  final WalletService walletService;

  const WalletConnectSigningRequestScreen({
    super.key,
    required this.bridge,
    required this.request,
    required this.walletService,
  });

  @override
  State<WalletConnectSigningRequestScreen> createState() =>
      _WalletConnectSigningRequestScreenState();
}

class _WalletConnectSigningRequestScreenState
    extends State<WalletConnectSigningRequestScreen> {
  bool _busy = false;
  String? _error;

  WalletSigningRequest get signing => widget.request.signingRequest!;

  Future<void> _approve() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final to = signing.to;
      if (to == null || to.isEmpty) {
        throw const WalletException('Transaction recipient is missing.');
      }

      final value = _parseHexBigInt(signing.value ?? '0x0');
      final signed = await widget.walletService.signSepoliaTransaction(
        to: to,
        valueWei: value,
        data: signing.data ?? '0x',
      );
      await widget.bridge.respondSigned(widget.request, signed);
      if (mounted) Navigator.of(context).pop(true);
    } on WalletException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'This transaction could not be authorized.';
      });
    }
  }

  Future<void> _reject() async {
    setState(() => _busy = true);
    try {
      await widget.bridge.respondRejected(widget.request);
      if (mounted) Navigator.of(context).pop(false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Unable to reject this request.';
      });
    }
  }

  static BigInt _parseHexBigInt(String value) {
    final normalized = value.trim().toLowerCase();
    if (!RegExp(r'^0x[0-9a-f]+$').hasMatch(normalized)) {
      throw const WalletException('Invalid transaction value.');
    }
    return BigInt.parse(normalized.substring(2), radix: 16);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Transaction')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
        children: [
          const Icon(
            Icons.edit_note_rounded,
            size: 48,
            color: AppColors.forest,
          ),
          const SizedBox(height: 16),
          const Text(
            'Review before signing',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'The requesting app never receives your private key. '
            'Signing happens locally only after you confirm this exact transaction.',
            style: TextStyle(height: 1.45),
          ),
          const SizedBox(height: 22),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _Row(label: 'Application', value: widget.request.appName),
                  const Divider(height: 26),
                  const _Row(label: 'Network', value: 'Sepolia'),
                  const Divider(height: 26),
                  _Row(label: 'Action', value: signing.actionDescription),
                  const Divider(height: 26),
                  _Row(label: 'Recipient', value: signing.to ?? 'Missing'),
                  const Divider(height: 26),
                  _Row(label: 'Value', value: signing.value ?? '0x0'),
                  if (signing.isContractInteraction) ...[
                    const Divider(height: 26),
                    const _Row(
                      label: 'Data',
                      value: 'Contract interaction — review calldata carefully.',
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 26),
          OutlinedButton(
            onPressed: _busy ? null : _reject,
            child: const Text('Reject'),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _busy ? null : _approve,
            icon: const Icon(Icons.lock_outline_rounded),
            label: Text(_busy ? 'Signing locally…' : 'Confirm & Sign'),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;

  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      );
}
