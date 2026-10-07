import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../wallet/connection/wallet_connection_manager.dart';
import '../wallet/connection/wallet_connection_request.dart';
import '../wallet/connection/wallet_connection_session.dart';
import '../wallet/connection/wallet_signing_request.dart';
import '../core/network/network_config.dart';

class SigningRequestScreen extends StatefulWidget {
  final WalletConnectionSession session;
  final WalletSigningRequest request;

  const SigningRequestScreen({
    super.key,
    required this.session,
    required this.request,
  });

  @override
  State<SigningRequestScreen> createState() => _SigningRequestScreenState();
}

class _SigningRequestScreenState extends State<SigningRequestScreen> {
  final _manager = WalletConnectionManager();
  bool _busy = false;
  String? _error;

  Future<void> _reviewAndAuthorize() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      widget.request.validate(const [
        // V1 signing is intentionally restricted to the wallet's configured network.
        SupportedNetworks.sepolia,
      ]);
      final signedTransaction = await _manager.signTransaction(widget.request);
      if (!mounted) return;
      Navigator.of(context).pop(signedTransaction);
    } on WalletConnectionException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'This signing request could not be authorized.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final networkName =
        widget.request.chainId == SupportedNetworks.sepolia.chainId
            ? SupportedNetworks.sepolia.name
            : 'Unsupported network';

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
            'The wallet will never send your private key to the requesting application. Signing happens locally after explicit approval.',
            style: TextStyle(height: 1.45),
          ),
          const SizedBox(height: 22),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _Row(label: 'Application', value: widget.session.appName),
                  const Divider(height: 26),
                  _Row(label: 'Network', value: networkName),
                  const Divider(height: 26),
                  _Row(
                    label: 'Action',
                    value: widget.request.actionDescription,
                  ),
                  const Divider(height: 26),
                  _Row(
                    label: 'Recipient',
                    value: widget.request.to ?? 'Not specified',
                  ),
                  if (widget.request.value != null) ...[
                    const Divider(height: 26),
                    _Row(
                      label: 'Value',
                      value: widget.request.value!,
                    ),
                  ],
                  if (widget.request.isContractInteraction) ...[
                    const Divider(height: 26),
                    const _Row(
                      label: 'Data',
                      value:
                          'Contract interaction — raw calldata requires detailed review.',
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
            onPressed: _busy ? null : () => Navigator.of(context).pop(false),
            child: const Text('Reject'),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _busy ? null : _reviewAndAuthorize,
            icon: const Icon(Icons.lock_outline_rounded),
            label: Text(
              _busy ? 'Signing locally…' : 'Confirm & Sign',
            ),
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
