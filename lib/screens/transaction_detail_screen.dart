import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/network/evm_rpc_service.dart';
import '../core/network/transaction_status.dart';
import '../theme/app_theme.dart';

class TransactionDetailScreen extends StatefulWidget {
  final String hash;

  const TransactionDetailScreen({super.key, required this.hash});

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  final _rpc = EvmRpcService();
  Map<String, dynamic>? _tx, _receipt;
  int? _timestamp;
  bool _loading = true;
  Object? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _load(silent: true),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    try {
      if (!silent && mounted) {
        setState(() => _loading = true);
      }
      final tx = await _rpc.getTransactionByHash(widget.hash);
      final receipt = await _rpc.getTransactionReceipt(widget.hash);
      int? time;
      final block = receipt?['blockNumber'];
      if (block is String && block != '0x') {
        time = await _rpc.getBlockTimestamp(block);
      }
      if (mounted) {
        setState(() {
          _tx = tx;
          _receipt = receipt;
          _timestamp = time;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  String _hex(dynamic v) {
    if (v is! String || !v.startsWith('0x')) return '-';
    try {
      return BigInt.parse(v.substring(2), radix: 16).toString();
    } catch (_) {
      return '-';
    }
  }

  String _eth(dynamic v) {
    if (v is! String || !v.startsWith('0x')) return '-';
    try {
      final w = BigInt.parse(v.substring(2), radix: 16);
      final whole = w ~/ BigInt.from(1000000000000000000);
      final f = (w % BigInt.from(1000000000000000000))
          .toString()
          .padLeft(18, '0')
          .replaceFirst(RegExp(r'0+$'), '');
      return '$whole.${f.isEmpty ? '0' : f.substring(0, f.length > 6 ? 6 : f.length)} ETH';
    } catch (_) {
      return '-';
    }
  }

  String _status() => switch (SepoliaTransactionStatusParser.parse(_receipt)) {
        SepoliaTransactionStatus.pending => 'Pending',
        SepoliaTransactionStatus.confirmed => 'Confirmed',
        SepoliaTransactionStatus.failed => 'Failed',
      };

  String _date() {
    if (_timestamp == null) return 'Pending confirmation';
    final d = DateTime.fromMillisecondsSinceEpoch(_timestamp! * 1000).toLocal();
    return '${d.day}/${d.month}/${d.year}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction hash copied')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Transaction details')),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _loading
              ? const Center(
                  key: ValueKey('loading'),
                  child: CircularProgressIndicator(),
                )
              : _error != null
                  ? Center(
                      key: const ValueKey('error'),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_off_outlined, size: 48),
                            const SizedBox(height: 12),
                            const Text(
                              'Unable to load transaction',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Network request failed. Check your connection and retry.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _load,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      key: const ValueKey('details'),
                      padding: const EdgeInsets.all(20),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: AppColors.mist,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                _status() == 'Confirmed'
                                    ? Icons.check_circle_rounded
                                    : _status() == 'Failed'
                                        ? Icons.error_rounded
                                        : Icons.hourglass_top_rounded,
                                color: AppColors.forest,
                                size: 46,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _status(),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _date(),
                                style: const TextStyle(color: Colors.black54),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Sepolia testnet',
                                style: TextStyle(color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.mist,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _status() == 'Confirmed'
                                    ? Icons.check_circle_rounded
                                    : _status() == 'Failed'
                                        ? Icons.error_outline_rounded
                                        : Icons.schedule_rounded,
                                color: AppColors.forest,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _status() == 'Confirmed'
                                      ? 'Transaction confirmed on Sepolia'
                                      : _status() == 'Failed'
                                          ? 'Transaction failed on Sepolia'
                                          : 'Waiting for Sepolia confirmation',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Card(
                          child: Column(
                            children: [
                              _row('Amount', _eth(_tx?['value'])),
                              _row('From', _tx?['from']?.toString() ?? '-'),
                              _row('To', _tx?['to']?.toString() ?? '-'),
                              _row('Nonce', _hex(_tx?['nonce'])),
                              _row('Gas limit', _hex(_tx?['gas'])),
                              _row(
                                'Gas used',
                                _receipt == null
                                    ? '-'
                                    : _hex(_receipt!['gasUsed']),
                              ),
                              _row(
                                'Block',
                                _receipt == null
                                    ? 'Pending'
                                    : _hex(_receipt!['blockNumber']),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'Transaction hash',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => _copy(widget.hash),
                                      icon: const Icon(Icons.copy_rounded),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                SelectableText(
                                  widget.hash,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
        ),
      );

  Widget _row(String l, String v) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 90,
              child: Text(
                l,
                style: const TextStyle(color: Colors.black54),
              ),
            ),
            Expanded(
              child: SelectableText(
                v,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
}
