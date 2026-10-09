import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/assets/erc20_asset_service.dart';
import '../core/network/network_config.dart';
import '../core/wallet/wallet_service.dart';
import '../theme/app_theme.dart';

class AssetsScreen extends StatefulWidget {
  const AssetsScreen({super.key});

  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen> {
  final _wallet = WalletService();
  final _assets = Erc20AssetService();
  final _addressController = TextEditingController();
  String? _walletAddress;
  List<Erc20Asset> _tokens = const [];
  bool _loading = true;
  bool _adding = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final snapshot = await _wallet.restoreWallet();
      final address = snapshot?.address;
      final tokens = address == null
          ? <Erc20Asset>[]
          : await _assets.loadAssets(address);
      if (!mounted) return;
      setState(() {
        _walletAddress = address;
        _tokens = tokens;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load token balances. Check your Sepolia connection.';
      });
    }
  }

  Future<void> _addToken() async {
    final address = _addressController.text.trim();
    if (address.isEmpty || _adding) return;
    setState(() {
      _adding = true;
      _error = null;
    });
    try {
      await _assets.addToken(address);
      _addressController.clear();
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Token added to your Sepolia assets.')),
        );
      }
    } catch (error) {
      if (mounted) {
        final message = error is Erc20AssetException
            ? error.message
            : 'Could not add token. Verify the contract address and network.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _removeToken(Erc20Asset token) async {
    await _assets.removeToken(token.address);
    await _refresh();
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied')),
    );
  }

  @override
  void dispose() {
    _addressController.dispose();
    _assets.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Assets'),
          actions: [
            IconButton(
              tooltip: 'Refresh balances',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.forest,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shield_outlined,
                            color: AppColors.mint, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'ETHEREUM SEPOLIA',
                          style: TextStyle(
                            color: AppColors.mint,
                            fontSize: 11,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Your tokens, your control.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Only add token contracts you trust. Token names and symbols are supplied by the contract and are not proof of authenticity.',
                      style: TextStyle(color: Colors.white70, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Add a token',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Paste an ERC-20 contract address deployed on Sepolia.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _addressController,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.none,
                decoration: InputDecoration(
                  hintText: '0x… token contract address',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  suffixIcon: IconButton(
                    tooltip: 'Paste address',
                    onPressed: () async {
                      final data = await Clipboard.getData('text/plain');
                      if (data?.text != null) {
                        _addressController.text = data!.text!.trim();
                      }
                    },
                    icon: const Icon(Icons.content_paste_rounded),
                  ),
                ),
                onSubmitted: (_) => _addToken(),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _adding ? null : _addToken,
                icon: _adding
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_rounded),
                label: Text(_adding ? 'Checking contract…' : 'Add token'),
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Your tokens',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    '${_tokens.length} added',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        const Icon(Icons.cloud_off_rounded, size: 36),
                        const SizedBox(height: 8),
                        Text(_error!, textAlign: TextAlign.center),
                        TextButton(
                          onPressed: _refresh,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_walletAddress == null)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text(
                      'Create or import a wallet to view token balances.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else if (_tokens.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(22),
                    child: Column(
                      children: [
                        Icon(Icons.token_outlined,
                            size: 42, color: AppColors.forest),
                        SizedBox(height: 10),
                        Text(
                          'No custom tokens yet',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Add an ERC-20 contract above to see its Sepolia balance here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ..._tokens.map(_tokenTile),
              const SizedBox(height: 14),
              Text(
                'Explorer: ${SupportedNetworks.sepolia.explorerUrl}',
                style: const TextStyle(fontSize: 11, color: Colors.black45),
              ),
            ],
          ),
        ),
      );

  Widget _tokenTile(Erc20Asset token) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.mist,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.token_rounded,
                        color: AppColors.forest),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(token.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15)),
                        const SizedBox(height: 3),
                        Text(
                          '${token.symbol}  •  ${token.decimals} decimals',
                          style: const TextStyle(
                              color: Colors.black54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove token',
                    onPressed: () => _removeToken(token),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                token.formattedBalance,
                style:
                    const TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
              ),
              Text(token.symbol,
                  style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      token.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.black54),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy contract address',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _copy(token.address, 'Contract address'),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                  ),
                  IconButton(
                    tooltip: 'Copy Sepolia explorer link',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _copy(
                      _assets.explorerTokenUrl(token.address),
                      'Explorer link',
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}
