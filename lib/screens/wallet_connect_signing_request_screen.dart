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
  late final Future<WalletTransactionFeePreview> _feePreview;

  WalletSigningRequest get signing => widget.request.signingRequest!;

  @override
  void initState() {
    super.initState();
    _feePreview = _loadFeePreview();
  }

  Future<WalletTransactionFeePreview> _loadFeePreview() {
    final to = signing.to;
    if (to == null || to.isEmpty) {
      return Future<WalletTransactionFeePreview>.error(
        const WalletException('Transaction recipient is missing.'),
      );
    }
    return widget.walletService.estimateSepoliaTransactionFee(
      to: to,
      valueWei: _parseHexBigInt(signing.value ?? '0x0'),
      data: signing.data ?? '0x',
    );
  }

  Future<void> _approve() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final from = widget.request.from;
      final walletAddress = await widget.walletService.getPublicAddress();
      if (from != null &&
          (walletAddress == null ||
              from.toLowerCase() != walletAddress.toLowerCase())) {
        throw const WalletException(
            'The transaction sender does not match this wallet.');
      }
      final to = signing.to;
      if (to == null || to.isEmpty) {
        throw const WalletException('Transaction recipient is missing.');
      }
      final transactionHash = await widget.walletService.sendSepoliaTransaction(
        to: to,
        valueWei: _parseHexBigInt(signing.value ?? '0x0'),
        data: signing.data ?? '0x',
      );
      await widget.bridge
          .respondTransactionHash(widget.request, transactionHash);
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
    if (!RegExp(r'^0x[0-9a-f]+
    return BigInt.parse(normalized.substring(2), radix: 16);
  }

  static String _formatEth(BigInt wei) {
    const base = 1000000000000000000;
    final whole = wei ~/ BigInt.from(base);
    final remainder = (wei % BigInt.from(base))
        .toString()
        .padLeft(18, '0')
        .replaceFirst(RegExp(r'0+$'), '');
    return remainder.isEmpty ? '$whole ETH' : '$whole.$remainder ETH';
  }

  static String _shortenAddress(String address) {
    if (address.length < 12) return address;
    return '${address.substring(0, 8)}…${address.substring(address.length - 6)}';
  }

  @override
  Widget build(BuildContext context) {
    final valueWei = _parseHexBigInt(signing.value ?? '0x0');
    return Scaffold(
      appBar: AppBar(title: const Text('Review Transaction')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
        children: [
          const Icon(Icons.verified_user_outlined,
              size: 48, color: AppColors.forest),
          const SizedBox(height: 16),
          const Text('Review before sending',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text(
              'Your private key stays inside NegosWallet. Nothing is sent to the requesting application.',
              style: TextStyle(height: 1.45)),
          const SizedBox(height: 22),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(children: [
                    _Row(label: 'Application', value: widget.request.appName),
                    const Divider(height: 26),
                    const _Row(label: 'Network', value: 'Ethereum Sepolia'),
                    const Divider(height: 26),
                    _Row(
                        label: 'Sender',
                        value: widget.request.from == null
                            ? 'This wallet'
                            : _shortenAddress(widget.request.from!)),
                    const Divider(height: 26),
                    _Row(
                        label: 'Recipient',
                        value: signing.to == null
                            ? 'Missing'
                            : _shortenAddress(signing.to!)),
                    const Divider(height: 26),
                    _Row(label: 'Amount', value: _formatEth(valueWei)),
                    const Divider(height: 26),
                    FutureBuilder<WalletTransactionFeePreview>(
                      future: _feePreview,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const _Row(
                              label: 'Network fee', value: 'Estimating…');
                        }
                        if (snapshot.hasError) {
                          return const _Row(
                              label: 'Network fee',
                              value: 'Unable to estimate');
                        }
                        final fee = snapshot.data!;
                        return Column(children: [
                          _Row(
                              label: 'Gas limit',
                              value: fee.gasLimit.toString()),
                          const Divider(height: 26),
                          _Row(
                              label: 'Network fee',
                              value: _formatEth(fee.feeWei)),
                          const Divider(height: 26),
                          _Row(
                              label: 'Maximum total',
                              value: _formatEth(valueWei + fee.feeWei)),
                        ]);
                      },
                    ),
                    if (signing.isContractInteraction) ...[
                      const Divider(height: 26),
                      const _Row(
                          label: 'Warning',
                          value:
                              'Contract interaction. Only confirm if you trust the application and understand the action.'),
                    ],
                  ]))),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!,
                style: const TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 26),
          OutlinedButton(
              onPressed: _busy ? null : _reject, child: const Text('Reject')),
          const SizedBox(height: 10),
          FilledButton.icon(
              onPressed: _busy ? null : _approve,
              icon: const Icon(Icons.lock_outline_rounded),
              label: Text(_busy ? 'Authorizing…' : 'Confirm & Send')),
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
).hasMatch(normalized)) {
      throw const WalletException('Invalid transaction value.');
    }
    return BigInt.parse(normalized.substring(2), radix: 16);
  }

  static String _formatEth(BigInt wei) {
    const base = 1000000000000000000;
    final whole = wei ~/ BigInt.from(base);
    final remainder = (wei % BigInt.from(base))
        .toString()
        .padLeft(18, '0')
        .replaceFirst(RegExp(r'0+$'), '');
    return remainder.isEmpty ? '$whole ETH' : '$whole.$remainder ETH';
  }

  static String _shortenAddress(String address) {
    if (address.length < 12) return address;
    return '${address.substring(0, 8)}…${address.substring(address.length - 6)}';
  }

  @override
  Widget build(BuildContext context) {
    final valueWei = _parseHexBigInt(signing.value ?? '0x0');
    return Scaffold(
      appBar: AppBar(title: const Text('Review Transaction')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
        children: [
          const Icon(Icons.verified_user_outlined,
              size: 48, color: AppColors.forest),
          const SizedBox(height: 16),
          const Text('Review before sending',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text(
              'Your private key stays inside NegosWallet. Nothing is sent to the requesting application.',
              style: TextStyle(height: 1.45)),
          const SizedBox(height: 22),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(children: [
                    _Row(label: 'Application', value: widget.request.appName),
                    const Divider(height: 26),
                    const _Row(label: 'Network', value: 'Ethereum Sepolia'),
                    const Divider(height: 26),
                    _Row(
                        label: 'Sender',
                        value: widget.request.from == null
                            ? 'This wallet'
                            : _shortenAddress(widget.request.from!)),
                    const Divider(height: 26),
                    _Row(
                        label: 'Recipient',
                        value: signing.to == null
                            ? 'Missing'
                            : _shortenAddress(signing.to!)),
                    const Divider(height: 26),
                    _Row(label: 'Amount', value: _formatEth(valueWei)),
                    const Divider(height: 26),
                    FutureBuilder<WalletTransactionFeePreview>(
                      future: _feePreview,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done)
                          return const _Row(
                              label: 'Network fee', value: 'Estimating…');
                        if (snapshot.hasError)
                          return const _Row(
                              label: 'Network fee',
                              value: 'Unable to estimate');
                        final fee = snapshot.data!;
                        return Column(children: [
                          _Row(
                              label: 'Gas limit',
                              value: fee.gasLimit.toString()),
                          const Divider(height: 26),
                          _Row(
                              label: 'Network fee',
                              value: _formatEth(fee.feeWei)),
                          const Divider(height: 26),
                          _Row(
                              label: 'Maximum total',
                              value: _formatEth(valueWei + fee.feeWei)),
                        ]);
                      },
                    ),
                    if (signing.isContractInteraction) ...[
                      const Divider(height: 26),
                      const _Row(
                          label: 'Warning',
                          value:
                              'Contract interaction. Only confirm if you trust the application and understand the action.'),
                    ],
                  ]))),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!,
                style: const TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 26),
          OutlinedButton(
              onPressed: _busy ? null : _reject, child: const Text('Reject')),
          const SizedBox(height: 10),
          FilledButton.icon(
              onPressed: _busy ? null : _approve,
              icon: const Icon(Icons.lock_outline_rounded),
              label: Text(_busy ? 'Authorizing…' : 'Confirm & Send')),
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
