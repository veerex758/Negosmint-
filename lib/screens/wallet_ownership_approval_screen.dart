import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/wallet/wallet_service.dart';

/// Explicit approval screen for the Task App's short-lived wallet-link proof.
///
/// This screen signs only a server-issued NegosMint ownership challenge. It
/// does not sign arbitrary dapp messages or transactions and does not transmit
/// the signature; the caller receives it as a Navigator result and must submit
/// it over an authenticated HTTPS request.
class WalletOwnershipApprovalScreen extends StatefulWidget {
  const WalletOwnershipApprovalScreen({
    super.key,
    required this.challengeId,
    required this.message,
    required this.chainId,
    required this.expiresAt,
    this.walletService,
  });

  final String challengeId;
  final String message;
  final int chainId;
  final DateTime expiresAt;
  final WalletService? walletService;

  @override
  State<WalletOwnershipApprovalScreen> createState() =>
      _WalletOwnershipApprovalScreenState();
}

class _WalletOwnershipApprovalScreenState
    extends State<WalletOwnershipApprovalScreen> {
  static const _sepoliaChainId = 11155111;
  late final WalletService _wallet = widget.walletService ?? WalletService();

  static const _ownershipChannel =
      MethodChannel('com.negosmint.wallet/ownership_result');

  bool _confirmed = false;
  bool _busy = false;
  String? _error;

  bool get _isValidChallenge {
    final lines = widget.message.split('\n');
    final userIdLines = lines.where((line) => line.startsWith('User ID: '));
    final nonceLines = lines.where((line) => line.startsWith('Nonce: '));
    final expectedExpiry =
        'Expires At: ${widget.expiresAt.toUtc().toIso8601String()}';
    return widget.challengeId.isNotEmpty &&
        widget.challengeId.length <= 64 &&
        widget.chainId == _sepoliaChainId &&
        widget.expiresAt.isAfter(DateTime.now().toUtc()) &&
        widget.message.length <= 2000 &&
        lines.length >= 9 &&
        lines.first == 'NegosMint Wallet Ownership Verification' &&
        userIdLines.length == 1 &&
        userIdLines.single.substring('User ID: '.length).trim().isNotEmpty &&
        nonceLines.length == 1 &&
        nonceLines.single.substring('Nonce: '.length).trim().isNotEmpty &&
        lines.contains('Challenge ID: ${widget.challengeId}') &&
        lines.contains('Chain ID: $_sepoliaChainId') &&
        lines.contains(expectedExpiry) &&
        lines.contains(
          'Purpose: Link this self-custody wallet to the signed-in NegosMint Task Platform account.',
        ) &&
        lines.contains(
          'This signature proves address control only. It does not authorize a transaction.',
        ) &&
        lines.contains('If you did not initiate this request, reject it.');
  }

  Future<void> _approve() async {
    if (_busy || !_confirmed) return;
    if (!_isValidChallenge) {
      setState(() {
        _error = 'This request is invalid or has expired. Return to the Task App and try again.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final signature =
          await _wallet.signWalletOwnershipMessage(widget.message);
      final address = await _wallet.getPublicAddress();
      if (address == null ||
          !RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(address)) {
        throw const WalletException('Wallet address is unavailable.');
      }
      await _ownershipChannel.invokeMethod<bool>(
        'completeOwnershipHandoff',
        <String, dynamic>{
          'challengeId': widget.challengeId,
          'walletAddress': address,
          'chainId': widget.chainId,
          'signature': signature,
        },
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is WalletException
            ? error.message
            : 'Could not approve this verification request.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    if (_busy) return;
    try {
      await _ownershipChannel.invokeMethod<bool>('rejectOwnershipHandoff');
    } on PlatformException {
      if (mounted) {
        setState(() {
          _error = 'Could not safely return to the Task App. Close this screen and try again.';
        });
      }
    } on MissingPluginException {
      if (mounted) {
        setState(() {
          _error = 'Secure app handoff is unavailable in this build.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final expired = !widget.expiresAt.isAfter(DateTime.now().toUtc());
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _reject();
      },
      child: Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Reject request',
          onPressed: _reject,
          icon: const Icon(Icons.close),
        ),
        title: const Text('Verify wallet ownership'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(Icons.verified_user_outlined, size: 54),
            const SizedBox(height: 16),
            Text(
              'NegosMint Task Platform wants to verify this wallet',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'This proves you control the public address. It does not send funds, approve a transaction, or reveal your recovery phrase.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Network'),
                    const SizedBox(height: 4),
                    const Text('Ethereum Sepolia (test network)'),
                    const SizedBox(height: 12),
                    const Text('Request expires'),
                    const SizedBox(height: 4),
                    Text(widget.expiresAt.toLocal().toString()),
                    const SizedBox(height: 12),
                    const Text('Exact message to be signed'),
                    const SizedBox(height: 8),
                    SelectableText(
                      widget.message,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _confirmed,
              onChanged: _busy || expired
                  ? null
                  : (value) => setState(() => _confirmed = value ?? false),
              title: const Text(
                'I started this request and understand it does not authorize a transaction.',
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            if (expired || !_isValidChallenge)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'This verification request is invalid or expired. Start a new request in the Task App.',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            FilledButton(
              onPressed: _busy || !_confirmed || expired || !_isValidChallenge
                  ? null
                  : _approve,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Approve and verify'),
            ),
            TextButton(
              onPressed: _busy ? null : _reject,
              child: const Text('Reject request'),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
