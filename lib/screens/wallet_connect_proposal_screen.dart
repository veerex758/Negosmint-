import 'package:flutter/material.dart';

import '../core/wallet/wallet_service.dart';
import '../wallet/connection/wallet_connect_bridge.dart';
import '../wallet/connection/wallet_connection_request.dart';

/// Explicit approval screen for a WalletConnect session proposal.
class WalletConnectProposalScreen extends StatefulWidget {
  final WalletConnectBridge bridge;
  final WalletConnectProposal proposal;
  final WalletService walletService;
  final String walletAddress;

  const WalletConnectProposalScreen({
    super.key,
    required this.bridge,
    required this.proposal,
    required this.walletService,
    required this.walletAddress,
  });

  @override
  State<WalletConnectProposalScreen> createState() =>
      _WalletConnectProposalScreenState();
}

class _WalletConnectProposalScreenState
    extends State<WalletConnectProposalScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _approve() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.bridge.approve(
        proposal: widget.proposal,
        walletService: widget.walletService,
      );
      if (mounted) Navigator.of(context).pop(true);
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
        _error = 'Unable to approve this wallet connection.';
      });
    }
  }

  Future<void> _reject() async {
    setState(() => _busy = true);
    try {
      await widget.bridge.reject(widget.proposal.id);
      if (mounted) Navigator.of(context).pop(false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Unable to reject this wallet connection.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final proposal = widget.proposal;
    return Scaffold(
      appBar: AppBar(title: const Text('WalletConnect Request')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 30),
        children: [
          CircleAvatar(
            radius: 32,
            child: Text(
              proposal.appName.isEmpty
                  ? '?'
                  : proposal.appName[0].toUpperCase(),
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            proposal.appName,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
          ),
          if (proposal.appUrl.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              proposal.appUrl,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _InfoRow(
                      label: 'Wallet', value: _shorten(widget.walletAddress)),
                  const Divider(height: 26),
                  const _InfoRow(label: 'Network', value: 'Sepolia'),
                  const Divider(height: 26),
                  _InfoRow(
                    label: 'Chain',
                    value: proposal.requiredChains.join(', '),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Requested capabilities',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: proposal.requiredMethods
                  .map(
                    (method) => ListTile(
                      leading: Icon(
                        proposal.requestsSigning
                            ? Icons.edit_document
                            : Icons.visibility_outlined,
                      ),
                      title: Text(method),
                    ),
                  )
                  .toList(),
            ),
          ),
          if (proposal.requiredEvents.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.sync_alt),
                title: const Text('Events'),
                subtitle: Text(proposal.requiredEvents.join(', ')),
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Text(
            'Connecting does not give this app your recovery phrase or private key. '
            'Transactions and signatures must be reviewed by NegosWallet before authorization.',
            style: TextStyle(fontWeight: FontWeight.w600, height: 1.45),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(
              _error!,
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 26),
          FilledButton(
            onPressed: _busy ? null : _approve,
            child: Text(_busy ? 'Connecting…' : 'Approve connection'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _busy ? null : _reject,
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}

String _shorten(String address) => address.length > 12
    ? '${address.substring(0, 8)}…${address.substring(address.length - 6)}'
    : address;

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(color: Colors.black54),
            ),
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
