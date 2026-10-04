import 'dart:async';
import 'package:flutter/material.dart';
import '../core/network/evm_rpc_service.dart';
import '../core/wallet/wallet_service.dart';
import '../theme/app_theme.dart';
import 'transaction_detail_screen.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});
  @override State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final _wallet = WalletService();
  final _rpc = EvmRpcService();
  Timer? _timer;
  List<String> _hashes = const [];
  final Map<String, Map<String, dynamic>> _details = {};
  String? _address;
  bool _loading = true;

  @override void initState() { super.initState(); _load(); _timer = Timer.periodic(const Duration(seconds: 8), (_) => _loadDetails()); }
  Future<void> _load() async {
    final hashes = await _wallet.getActivity();
    final snapshot = await _wallet.restoreWallet();
    if (!mounted) return;
    setState(() { _hashes = hashes; _address = snapshot?.address; _loading = false; });
    await _loadDetails();
  }
  Future<void> _loadDetails() async {
    for (final hash in _hashes) {
      try {
        final tx = await _rpc.getTransactionByHash(hash);
        if (tx == null) continue;
        final receipt = await _rpc.getTransactionReceipt(hash);
        int? timestamp;
        final block = receipt?['blockNumber'];
        if (block is String && block != '0x') timestamp = await _rpc.getBlockTimestamp(block);
        if (mounted) setState(() => _details[hash] = {'tx': tx, 'receipt': receipt, 'timestamp': timestamp});
      } catch (_) {}
    }
  }
  String _amount(String? value) {
    if (value == null || !value.startsWith('0x')) return '-';
    final wei = BigInt.parse(value.substring(2), radix: 16);
    final base = BigInt.from(1000000000000000000);
    final whole = wei ~/ base;
    final fraction = (wei % base).toString().padLeft(18, '0').replaceFirst(RegExp(r'0+$'), '');
    return whole.toString() + '.' + (fraction.isEmpty ? '0' : fraction.substring(0, fraction.length > 6 ? 6 : fraction.length)) + ' ETH';
  }
  String _time(dynamic timestamp) {
    if (timestamp is! int) return 'Pending';
    final d = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000).toLocal();
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day}/${d.month}/${d.year}  ' + h + ':' + m;
  }
  @override void dispose() { _timer?.cancel(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Activity')),
    body: RefreshIndicator(onRefresh: _load, child: _loading ? const Center(child: CircularProgressIndicator()) : _hashes.isEmpty ? ListView(children: const [SizedBox(height: 180), _EmptyActivity()]) : ListView.separated(
      padding: const EdgeInsets.all(18), itemCount: _hashes.length, separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final hash = _hashes[i]; final d = _details[hash]; final tx = d?['tx'] as Map<String, dynamic>?; final receipt = d?['receipt'] as Map<String, dynamic>?;
        final confirmed = receipt?['status'] == '0x1'; final failed = receipt != null && !confirmed;
        final mine = tx?['from']?.toString().toLowerCase() == _address?.toLowerCase();
        return _TransactionTile(hash: hash, direction: mine ? 'Send' : 'Receive', amount: _amount(tx?['value']?.toString()), time: _time(d?['timestamp']), status: receipt == null ? 'Pending' : failed ? 'Failed' : 'Confirmed', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TransactionDetailScreen(hash: hash))));
      },
    )),
  );
}

class _TransactionTile extends StatelessWidget {
  final String hash, direction, amount, time, status; final VoidCallback onTap;
  const _TransactionTile({required this.hash, required this.direction, required this.amount, required this.time, required this.status, required this.onTap});
  @override Widget build(BuildContext context) {
    final failed = status == 'Failed'; final send = direction == 'Send';
    return Card(child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), leading: CircleAvatar(backgroundColor: AppColors.mist, child: Icon(failed ? Icons.error_outline : send ? Icons.north_east_rounded : Icons.south_west_rounded, color: failed ? Colors.redAccent : AppColors.forest)), title: Text(direction + '  •  ' + amount, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Padding(padding: const EdgeInsets.only(top: 5), child: Text(status + '  •  ' + time)), trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 15), onTap: onTap));
  }
}

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity();
  @override Widget build(BuildContext context) => Center(child: Column(children: const [Icon(Icons.receipt_long_rounded, size: 64, color: AppColors.forest), SizedBox(height: 16), Text('No activity yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)), SizedBox(height: 6), Text('Your Sepolia transactions will appear here.', style: TextStyle(color: Colors.black54))]));
}