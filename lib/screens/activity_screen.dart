import 'dart:async';
import 'package:flutter/material.dart';
import '../core/network/evm_rpc_service.dart';
import '../core/assets/activity_indexer.dart';
import '../core/assets/sepolia_activity_history_service.dart';
import '../core/assets/transaction_parser.dart';
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
  final _indexer = ActivityIndexer();
  final _historyService = SepoliaActivityHistoryService();
  Map<String, dynamic>? _transactionCursor;
  Map<String, dynamic>? _tokenTransferCursor;
  final Set<String> _historyHashes = {};
  bool _hasMoreHistory = false;
  bool _loadingOlder = false;
  bool _historyInitialized = false;
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
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _load());
  }

  Future<void> _load() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final localHashes = await _wallet.getActivity();
      final snapshot = await _wallet.restoreWallet();
      var indexed = <IndexedTokenTransfer>[];
      var latestHistoryHashes = <String>[];
      if (snapshot != null) {
        try {
          indexed = await _indexer.sync(snapshot.address);
        } catch (_) {
          // Keep locally recorded transactions visible when log indexing is
          // unavailable. The indexer cursor only advances after a full chunk.
          try {
            indexed = await _indexer.getTransfers(snapshot.address);
          } catch (_) {}
        }
        // RPC alone cannot enumerate incoming native transactions. Use the
        // read-only Sepolia explorer API for address history and older pages.
        try {
          final page = await _historyService.fetchPage(snapshot.address);
          latestHistoryHashes = page.transactionHashes;
          _historyHashes.addAll(latestHistoryHashes);
          if (!_historyInitialized) {
            _transactionCursor = page.transactionCursor;
            _tokenTransferCursor = page.tokenTransferCursor;
            _hasMoreHistory = page.hasMore;
            _historyInitialized = true;
          }
        } catch (_) {
          // Explorer outages must not hide locally recorded or RPC-indexed
          // activity.
        }
      }
      final hashes = <String>{
        ...localHashes,
        ...latestHistoryHashes,
        ..._historyHashes,
        ...indexed.map((transfer) => transfer.transactionHash),
      }.toList();
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

  Future<void> _loadOlder() async {
    if (_loadingOlder || !_hasMoreHistory || _address == null) return;
    setState(() => _loadingOlder = true);
    try {
      final page = await _historyService.fetchPage(
        _address!,
        transactionCursor: _transactionCursor,
        tokenTransferCursor: _tokenTransferCursor,
        includeTransactions: _transactionCursor != null,
        includeTokenTransfers: _tokenTransferCursor != null,
      );
      if (!mounted) return;
      _historyHashes.addAll(page.transactionHashes);
      _transactionCursor = page.transactionCursor;
      _tokenTransferCursor = page.tokenTransferCursor;
      _hasMoreHistory = page.hasMore;
      final hashes = <String>{
        ..._hashes,
        ...page.transactionHashes,
      }.toList();
      setState(() {
        _hashes = hashes;
        _loadingOlder = false;
      });
      await _loadDetails();
    } catch (_) {
      if (mounted) {
        setState(() => _loadingOlder = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load older activity. Please try again.'),
          ),
        );
      }
    }
  }

  Future<void> _loadDetails() async {
    if (_loadingDetails || _hashes.isEmpty) return;
    _loadingDetails = true;
    try {
      final hashes = List<String>.from(_hashes);
      // A small concurrent batch avoids serially waiting on three RPC calls
      // for every item while keeping pressure on the public RPC endpoint low.
      for (var start = 0; start < hashes.length; start += 5) {
        if (!mounted) return;
        final batch = hashes.skip(start).take(5);
        await Future.wait(batch.map(_loadTransactionDetail));
      }
    } finally {
      _loadingDetails = false;
    }
  }

  Future<void> _loadTransactionDetail(String hash) async {
    // Confirmed transactions are immutable for this screen's purposes.
    // Pending transactions are retried on later refreshes.
    if (_details[hash]?['receipt'] != null) return;
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
        return;
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
    _indexer.dispose();
    _historyService.dispose();
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
                          itemCount: _hashes.length + (_hasMoreHistory ? 1 : 0),
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            if (i >= _hashes.length) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                child: Center(
                                  child: OutlinedButton.icon(
                                    onPressed: _loadingOlder ? null : _loadOlder,
                                    icon: _loadingOlder
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.expand_more_rounded),
                                    label: Text(
                                      _loadingOlder
                                          ? 'Loading older activity…'
                                          : 'Load older activity',
                                    ),
                                  ),
                                ),
                              );
                            }
                            final hash = _hashes[i];
                            final d = _details[hash];
                            final tx = d?['tx'] as Map<String, dynamic>?;
                            final receipt =
                                d?['receipt'] as Map<String, dynamic>?;
                            final status =
                                SepoliaTransactionStatusParser.parse(receipt);
                            final parsedTransfers = tx == null || _address == null
                                ? <ParsedAssetTransfer>[]
                                : TransactionParser.parse(
                                    transaction: tx,
                                    receipt: receipt,
                                    walletAddress: _address!,
                                  );
                            final tokenTransfers = parsedTransfers
                                .where((transfer) =>
                                    !transfer.isNative &&
                                    transfer.direction !=
                                        AssetTransferDirection.unknown)
                                .toList(growable: false);
                            final walletAddress = _address?.toLowerCase();
                            final nativeFrom =
                                tx?['from']?.toString().toLowerCase();
                            final directions = tokenTransfers
                                .map((transfer) =>
                                    transfer.direction == AssetTransferDirection.sent
                                        ? 'Send'
                                        : transfer.direction ==
                                                AssetTransferDirection.received
                                            ? 'Receive'
                                            : 'Transfer')
                                .toSet();
                            // Locally recorded hashes are wallet-originated;
                            // retain Send while the public RPC has not indexed them.
                            final direction = tokenTransfers.isEmpty
                                ? (tx == null || nativeFrom == walletAddress
                                    ? 'Send'
                                    : 'Receive')
                                : directions.length == 1
                                    ? directions.single
                                    : 'Transfer';
                            final singleTransfer = tokenTransfers.length == 1
                                ? tokenTransfers.single
                                : null;
                            final amount = tokenTransfers.isEmpty
                                ? _amount(tx?['value']?.toString())
                                : tokenTransfers.length == 1
                                    ? '${singleTransfer!.rawAmount} token units'
                                    : '${tokenTransfers.length} token transfers';
                            return _TransactionTile(
                              hash: hash,
                              direction: direction,
                              amount: amount,
                              time: _time(d?['timestamp']),
                              tokenAddress: singleTransfer?.tokenAddress,
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
  final String? tokenAddress;
  final VoidCallback onTap;
  const _TransactionTile(
      {required this.hash,
      required this.direction,
      required this.amount,
      required this.time,
      required this.status,
      required this.onTap,
      this.tokenAddress});
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$status  •  $time'),
              if (tokenAddress != null)
                Text(
                  'Token: $tokenAddress',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
            ],
          ),
        ),
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
