import 'dart:async';
import 'package:flutter/material.dart';
import '../core/network/evm_rpc_service.dart';
import '../core/network/transaction_status.dart';
import '../core/wallet/wallet_service.dart';
import '../theme/app_theme.dart';
import 'transaction_detail_screen.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});
  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final _wallet = WalletService();
  final _rpc = EvmRpcService();
  Timer? _timer;
  List<String> _hashes = const [];
  final Map<String, Map<String, dynamic>> _details = {};
  String? _address;
  bool _loading = true;
  bool _refreshing = false;
  bool _loadingDetails = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _loadDetails());
  }

  Future<void> _load() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final hashes = await _wallet.getActivity();
      final snapshot = await _wallet.restoreWallet();
      if (!mounted) return;
      setState(() {
        _hashes = hashes;
        _address = snapshot?.address;
        _loading = false;
        _error = null;
      });
      await _loadDetails();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load activity. Pull to retry.';
      });
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _loadDetails() async {
    if (_loadingDetails || _hashes.isEmpty) return;
    _loadingDetails = true;
    try {
      for (final hash in List<String>.from(_hashes)) {
        if (!mounted) return;
        try {
          final tx = await _rpc.getTransactionByHash(hash);
          final receipt = await _rpc.getTransactionReceipt(hash);
          if (tx == null && receipt == null) {
            if (mounted) {
              setState(() => _details[hash] = {
                    'tx': null,
                    'receipt': null,
                    'timestamp': null,
                  });
            }
            continue;
          }
          int? timestamp;
          final block = receipt?['blockNumber'];
          if (block is String && block != '0x') {
            timestamp = await _rpc.getBlockTimestamp(block);
          }
          if (mounted) {
            setState(() => _details[hash] = {
                  'tx': tx,
                  'receipt': receipt,
                  'timestamp': timestamp,
                });
          }
        } catch (_) {}
      }
    } finally {
      _loadingDetails = false;
    }
  }

  String _amount(String? value) {
    if (value == null || !value.startsWith('0x')) return '-';
    try {
      final wei = BigInt.parse(value.substring(2), radix: 16);
      final base = BigInt.from(1000000000000000000);
      final whole = wei ~/ base;
      final fraction = (wei % base)
          .toString()
          .padLeft(18, '0')
          .replaceFirst(RegExp(r'0+$'), '');
      return '$whole.${fraction.isEmpty ? '0' : fraction.substring(0, fraction.length > 6 ? 6 : fraction.length)} ETH';
    } catch (_) {
      return '-';
    }
  }

  String _time(dynamic timestamp) {
    if (timestamp is! int) return 'Pending';
    final d = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000).toLocal();
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day}/${d.month}/${d.year}  $h:$m';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Activity')),
        body: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? ListView(children: const [
                  SizedBox(height: 220),
                  Center(child: CircularProgressIndicator())
                ])
              : _error != null
                  ? ListView(children: [
                      const SizedBox(height: 170),
                      const Center(
                          child: Icon(Icons.cloud_off_rounded,
                              size: 58, color: AppColors.forest)),
                      const SizedBox(height: 14),
                      const Center(
                          child: Text('Activity unavailable',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w800))),
                      const SizedBox(height: 6),
                      Center(child: Text(_error!)),
                      const SizedBox(height: 18),
                      Center(
                          child: OutlinedButton(
                              onPressed: _load, child: const Text('Retry')))
                    ])
                  : _hashes.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 180),
                          _EmptyActivity()
                        ])
                      : ListView.separated(
                          padding: const EdgeInsets.all(18),
                          itemCount: _hashes.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final hash = _hashes[i];
                            final d = _details[hash];
                            final tx = d?['tx'] as Map<String, dynamic>?;
                            final receipt =
                                d?['receipt'] as Map<String, dynamic>?;
                            final status =
                                SepoliaTransactionStatusParser.parse(receipt);
                            // This local activity list is populated by
                            // wallet-originated broadcasts. Preserve the Send
                            // label while a public RPC has not indexed the tx.
                            final mine = tx == null ||
                                tx['from']?.toString().toLowerCase() ==
                                    _address?.toLowerCase();
                            return _TransactionTile(
                              hash: hash,
                              direction: mine ? 'Send' : 'Receive',
                              amount: _amount(tx?['value']?.toString()),
                              time: _time(d?['timestamp']),
                              status: switch (status) {
                                SepoliaTransactionStatus.pending => 'Pending',
                                SepoliaTransactionStatus.confirmed =>
                                  'Confirmed',
                                SepoliaTransactionStatus.failed => 'Failed',
                              },
                              onTap: () =>
                                  Navigator.of(context).push(PageRouteBuilder(
                                transitionDuration:
                                    const Duration(milliseconds: 380),
                                reverseTransitionDuration:
                                    const Duration(milliseconds: 260),
                                pageBuilder: (_, animation, __) =>
                                    TransactionDetailScreen(hash: hash),
                                transitionsBuilder: (_, animation, __, child) {
                                  final curve = CurvedAnimation(
                                      parent: animation,
                                      curve: Curves.easeOutCubic,
                                      reverseCurve: Curves.easeInCubic);
                                  return FadeTransition(
                                      opacity: curve,
                                      child: SlideTransition(
                                          position: Tween<Offset>(
                                                  begin: const Offset(.035, 0),
                                                  end: Offset.zero)
                                              .animate(curve),
                                          child: child));
                                },
                              )),
                            );
                          },
                        ),
        ),
      );
}

class _TransactionTile extends StatelessWidget {
  final String hash, direction, amount, time, status;
  final VoidCallback onTap;
  const _TransactionTile(
      {required this.hash,
      required this.direction,
      required this.amount,
      required this.time,
      required this.status,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    final failed = status == 'Failed';
    final send = direction == 'Send';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppColors.mist,
          child: Icon(
              failed
                  ? Icons.error_outline
                  : send
                      ? Icons.north_east_rounded
                      : Icons.south_west_rounded,
              color: failed ? Colors.redAccent : AppColors.forest),
        ),
        title: Text('$direction  •  $amount',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text('$status  •  $time')),
        trailing: const Icon(Icons.chevron_right_rounded, size: 20),
        onTap: onTap,
      ),
    );
  }
}

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity();
  @override
  Widget build(BuildContext context) => const Center(
        child: Column(children: [
          Icon(Icons.receipt_long_rounded, size: 64, color: AppColors.forest),
          SizedBox(height: 16),
          Text('No activity yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          SizedBox(height: 6),
          Text('Your Sepolia transactions will appear here.',
              style: TextStyle(color: Colors.black54)),
        ]),
      );
}
