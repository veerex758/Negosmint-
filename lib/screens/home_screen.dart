import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoSliverRefreshControl, RefreshIndicatorMode;
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../core/network/evm_rpc_service.dart';
import 'receive_screen.dart';
import 'send_screen.dart';
import 'activity_screen.dart';
import 'security_screen.dart';
import 'recovery_phrase_screen.dart';
import 'network_screen.dart';
import 'about_screen.dart';
import 'connected_apps_screen.dart';

class HomeScreen extends StatefulWidget {
  final String? address;
  const HomeScreen({super.key, this.address});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomeTab(
          address: widget.address, onSend: _openSend, onReceive: _openReceive),
      const ActivityScreen(),
      const _SettingsTab(),
    ];
    return Scaffold(
      body: SafeArea(
          child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
                position:
                    Tween<Offset>(begin: const Offset(.03, 0), end: Offset.zero)
                        .animate(animation),
                child: child)),
        child: KeyedSubtree(key: ValueKey(_index), child: pages[_index]),
      )),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Wallet'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Activity'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings'),
        ],
      ),
    );
  }

  PageRoute<T> _premiumRoute<T>(Widget page) => PageRouteBuilder<T>(
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, animation, __) => page,
        transitionsBuilder: (_, animation, __, child) {
          final curve = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic);
          return FadeTransition(
            opacity: curve,
            child: SlideTransition(
              position:
                  Tween<Offset>(begin: const Offset(0.035, 0), end: Offset.zero)
                      .animate(curve),
              child: child,
            ),
          );
        },
      );

  void _openReceive() {
    final address = widget.address;
    if (address == null || address.isEmpty) return;
    Navigator.of(context).push(_premiumRoute(ReceiveScreen(address: address)));
  }

  void _openSend() {
    final address = widget.address;
    if (address == null || address.isEmpty) return;
    Navigator.of(context).push(_premiumRoute(SendScreen(address: address)));
  }
}

class _HomeTab extends StatefulWidget {
  final String? address;
  final VoidCallback onSend;
  final VoidCallback onReceive;
  const _HomeTab({this.address, required this.onSend, required this.onReceive});
  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  bool _hideBalance = false;

  Future<void> _refreshPortfolio() async {
    if (!mounted) return;
    setState(() {});
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  @override
  Widget build(BuildContext context) => CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            CupertinoSliverRefreshControl(
              onRefresh: _refreshPortfolio,
              builder: (context, refreshState, pulledExtent,
                      refreshTriggerPullDistance, refreshIndicatorExtent) =>
                  SizedBox(
                height: refreshIndicatorExtent,
                child: Center(
                  child: _LeafRefreshGlyph(
                    refreshing: refreshState == RefreshIndicatorMode.refresh,
                    progress: refreshTriggerPullDistance <= 0
                        ? 0
                        : (pulledExtent / refreshTriggerPullDistance)
                            .clamp(0.0, 1.0),
                  ),
                ),
              ),
            ),
            SliverPadding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
                sliver: SliverToBoxAdapter(
                    child: Row(children: [
                  Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                          color: AppColors.forest,
                          borderRadius: BorderRadius.circular(16)),
                      child: const Center(
                          child: Text('NM',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900)))),
                  const SizedBox(width: 14),
                  const Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('NEGOSWALLET',
                            style: TextStyle(
                                color: AppColors.forest,
                                fontSize: 11,
                                letterSpacing: 1.4,
                                fontWeight: FontWeight.w800)),
                        SizedBox(height: 3),
                        Text('Your portfolio',
                            style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                color: AppColors.charcoal))
                      ])),
                  IconButton(
                      onPressed: () => _showTestnetNotice(context),
                      icon: const Icon(Icons.notifications_none_rounded)),
                ]))),
            SliverPadding(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                sliver: SliverToBoxAdapter(
                    child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.forest, Color(0xFF31563F)]),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x241E3A2B),
                            blurRadius: 24,
                            offset: Offset(0, 12))
                      ]),
                  child: Stack(
                    children: [
                      Positioned(
                        top: -90,
                        right: -60,
                        child: Container(
                          width: 210,
                          height: 210,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [Color(0x337FAF8B), Color(0x001E3A2B)],
                            ),
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.shield_outlined,
                                  size: 15, color: AppColors.mint),
                              const SizedBox(width: 6),
                              const Text('SEPOLIA TESTNET',
                                  style: TextStyle(
                                    color: AppColors.mint,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.15,
                                  )),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0x26B8D9B2),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                      color: const Color(0x557FAF8B)),
                                ),
                                child: const Text('TEST TOKENS',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: .5,
                                    )),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Row(children: [
                            const Text('Total balance',
                                style: TextStyle(
                                    color: Color(0xBFFFFFFF), fontSize: 13)),
                            const Spacer(),
                            IconButton(
                                onPressed: () => setState(
                                    () => _hideBalance = !_hideBalance),
                                color: Colors.white,
                                icon: Icon(_hideBalance
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined))
                          ]),
                          const SizedBox(height: 4),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 280),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                              opacity: animation,
                              child: ScaleTransition(
                                scale:
                                    Tween<double>(begin: .96, end: 1).animate(
                                  CurvedAnimation(
                                    parent: animation,
                                    curve: Curves.easeOutBack,
                                  ),
                                ),
                                child: child,
                              ),
                            ),
                            child: _hideBalance
                                ? const Text(
                                    '••••••',
                                    key: ValueKey('hidden'),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 36,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 2,
                                    ),
                                  )
                                : _LiveEthBalance(
                                    key: const ValueKey('visible'),
                                    address: widget.address,
                                  ),
                          ),
                          const SizedBox(height: 22),
                          Row(children: [
                            Expanded(
                                child: _Action(
                                    label: 'Send',
                                    icon: Icons.arrow_upward_rounded,
                                    onTap: widget.onSend)),
                            const SizedBox(width: 8),
                            Expanded(
                                child: _Action(
                                    label: 'Receive',
                                    icon: Icons.arrow_downward_rounded,
                                    onTap: widget.onReceive)),
                            const SizedBox(width: 8),
                            const Expanded(
                                child: _Action(
                                    label: 'Swap',
                                    icon: Icons.swap_horiz_rounded,
                                    onTap: _disabledAction,
                                    enabled: false)),
                          ]),
                        ],
                      ),
                    ],
                  ),
                ))),
            SliverPadding(
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 8),
                sliver: SliverToBoxAdapter(
                    child: Row(children: [
                  const Expanded(
                      child: Text('Assets',
                          style: TextStyle(
                              fontSize: 19, fontWeight: FontWeight.w800))),
                  TextButton(
                      onPressed: () => _showAssets(context),
                      child: const Text('Manage'))
                ]))),
            SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                sliver: SliverList.list(children: [
                  _StaggeredAssetEntry(
                    index: 0,
                    child: const _AssetTile(
                      icon: Icons.currency_bitcoin_rounded,
                      name: 'Bitcoin',
                      symbol: 'BTC',
                      balance: '—',
                      value: 'Not available',
                      networkLabel: 'PLANNED',
                      iconBackgroundColor: Color(0xFFFFE8C8),
                      iconColor: Color(0xFF9B5B12),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _StaggeredAssetEntry(
                    index: 1,
                    child: _LiveEthAsset(address: widget.address),
                  ),
                  const SizedBox(height: 10),
                  _StaggeredAssetEntry(
                    index: 2,
                    child: const _AssetTile(
                      icon: Icons.token_outlined,
                      name: 'USD Coin',
                      symbol: 'USDC',
                      balance: '—',
                      value: 'Not available',
                      networkLabel: 'PLANNED',
                      iconBackgroundColor: Color(0xFFDDEBFF),
                      iconColor: Color(0xFF285BA8),
                    ),
                  ),
                ])),
            if (widget.address != null)
              SliverPadding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
                  sliver:
                      SliverToBoxAdapter(child: _AddressCard(widget.address!))),
          ]);
  void _showTestnetNotice(BuildContext context) => showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      barrierColor: const Color(0x66000000),
      showDragHandle: true,
      builder: (_) => const Padding(
          padding: EdgeInsets.fromLTRB(24, 8, 24, 30),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Testnet status',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                SizedBox(height: 10),
                Text(
                    'NegosMint Wallet is connected to Ethereum Sepolia. Notifications and mainnet features are not enabled in this build.',
                    style: TextStyle(height: 1.5))
              ])));
  void _showAssets(BuildContext context) => showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      barrierColor: const Color(0x66000000),
      showDragHandle: true,
      builder: (_) => const Padding(
          padding: EdgeInsets.fromLTRB(24, 8, 24, 30),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Assets',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                SizedBox(height: 10),
                Text(
                    'Bitcoin and USDC are placeholders for future asset support. Sepolia ETH is the only live asset in this testnet build.',
                    style: TextStyle(height: 1.5)),
                SizedBox(height: 8),
                Text('Mainnet assets are disabled.',
                    style: TextStyle(fontWeight: FontWeight.w700))
              ])));
}

class _AddressCard extends StatelessWidget {
  final String address;
  const _AddressCard(this.address);
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            const Icon(Icons.alternate_email_rounded, color: AppColors.forest),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('EVM address',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54))
                ])),
            IconButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: address));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Address copied')));
                  }
                },
                icon: const Icon(Icons.copy_rounded)),
          ])));
}

void _disabledAction() {}

class _Action extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  const _Action({
    required this.label,
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  @override
  State<_Action> createState() => _ActionState();
}

class _ActionState extends State<_Action> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => AnimatedScale(
        scale: _pressed ? .97 : 1,
        duration: const Duration(milliseconds: 90),
        child: GestureDetector(
          onTapDown:
              widget.enabled ? (_) => setState(() => _pressed = true) : null,
          onTapCancel:
              widget.enabled ? () => setState(() => _pressed = false) : null,
          onTapUp:
              widget.enabled ? (_) => setState(() => _pressed = false) : null,
          child: FilledButton.icon(
            onPressed: widget.enabled ? widget.onTap : null,
            icon: Icon(widget.icon, size: 18),
            label: Text(widget.label),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.forest,
              disabledBackgroundColor: Colors.white.withValues(alpha: .55),
              disabledForegroundColor: AppColors.forest.withValues(alpha: .45),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      );
}

class _LiveEthBalance extends StatelessWidget {
  final String? address;
  const _LiveEthBalance({super.key, this.address});
  @override
  Widget build(BuildContext context) {
    if (address == null || address!.isEmpty) {
      return const Text(r'$0.00',
          style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -1));
    }
    return FutureBuilder<BigInt>(
        future: EvmRpcService().getNativeBalanceInWei(address!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _BalanceSkeleton();
          }
          if (snapshot.hasError) {
            return const Text('Network unavailable',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700));
          }
          final targetEth = double.parse(
            _formatEth(snapshot.data!).replaceFirst(' ETH', ''),
          );
          return TweenAnimationBuilder<double>(
            key: ValueKey(snapshot.data),
            tween: Tween<double>(begin: 0, end: targetEth),
            duration: const Duration(milliseconds: 850),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => Text(
              '${_formatAnimatedEth(value)} ETH',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
          );
        });
  }
}

class _BalanceSkeleton extends StatefulWidget {
  const _BalanceSkeleton();

  @override
  State<_BalanceSkeleton> createState() => _BalanceSkeletonState();
}

class _BalanceSkeletonState extends State<_BalanceSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween<double>(begin: .42, end: .8).animate(_controller),
        child: Container(
          width: 150,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .22),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
}

class _LiveEthAsset extends StatelessWidget {
  final String? address;
  const _LiveEthAsset({this.address});
  @override
  Widget build(BuildContext context) {
    if (address == null || address!.isEmpty) {
      return const _AssetTile(
          icon: Icons.diamond_outlined,
          name: 'Ethereum',
          symbol: 'ETH',
          balance: '0.000000 ETH',
          value: 'Balance unavailable',
          networkLabel: 'SEPOLIA',
          iconBackgroundColor: Color(0xFFE0E8E2),
          iconColor: AppColors.forest);
    }
    return FutureBuilder<BigInt>(
        future: EvmRpcService().getNativeBalanceInWei(address!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _AssetTile(
                icon: Icons.diamond_outlined,
                name: 'Ethereum',
                symbol: 'Sepolia ETH',
                balance: 'Loading...',
                value: 'Fetching balance',
                networkLabel: 'SEPOLIA',
                iconBackgroundColor: Color(0xFFE0E8E2),
                iconColor: AppColors.forest,
                loading: true);
          }
          if (snapshot.hasError) {
            return const _AssetTile(
                icon: Icons.diamond_outlined,
                name: 'Ethereum',
                symbol: 'Sepolia ETH',
                balance: 'Unavailable',
                value: 'RPC connection issue',
                networkLabel: 'SEPOLIA',
                iconBackgroundColor: Color(0xFFE0E8E2),
                iconColor: AppColors.forest);
          }
          return _AnimatedEthAssetTile(wei: snapshot.data!);
        });
  }
}

String _formatAnimatedEth(double eth) {
  final fixed = eth.toStringAsFixed(6);
  final trimmed = fixed.replaceFirst(RegExp(r'0+
  const unit = 1000000000000000000;
  final whole = wei ~/ BigInt.from(unit);
  final fraction = (wei % BigInt.from(unit)).toString().padLeft(18, '0');
  final trimmed = fraction.replaceFirst(RegExp(r'0+$'), '');
  final shown = trimmed.isEmpty
      ? '0'
      : trimmed.substring(0, trimmed.length > 6 ? 6 : trimmed.length);
  return '$whole.$shown ETH';
}

class _AssetTile extends StatelessWidget {
  final IconData icon;
  final String name, symbol, balance, value;
  final String networkLabel;
  final Color iconBackgroundColor;
  final Color iconColor;
  final bool loading;

  const _AssetTile({
    required this.icon,
    required this.name,
    required this.symbol,
    required this.balance,
    required this.value,
    this.networkLabel = 'PLANNED',
    this.iconBackgroundColor = AppColors.mist,
    this.iconColor = AppColors.forest,
    this.loading = false,
  });
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: iconBackgroundColor,
                    borderRadius: BorderRadius.circular(15)),
                child: Icon(icon, color: iconColor, size: 23)),
            const SizedBox(width: 13),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(symbol,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          )),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: networkLabel == 'SEPOLIA'
                              ? const Color(0xFFE3EFE5)
                              : const Color(0xFFF0F0ED),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(networkLabel,
                            style: TextStyle(
                              color: networkLabel == 'SEPOLIA'
                                  ? AppColors.forest
                                  : Colors.black45,
                              fontSize: 8,
                              letterSpacing: .35,
                              fontWeight: FontWeight.w800,
                            )),
                      ),
                    ],
                  ),
                ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (loading)
                Container(
                  width: 78,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.mist,
                    borderRadius: BorderRadius.circular(8),
                  ),
                )
              else
                Text(balance,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(color: Colors.black45, fontSize: 11))
            ]),
          ])));
}

class _AnimatedEthAssetTile extends StatelessWidget {
  final BigInt wei;
  const _AnimatedEthAssetTile({required this.wei});

  @override
  Widget build(BuildContext context) {
    final targetEth = double.parse(_formatEth(wei).replaceFirst(' ETH', ''));
    return TweenAnimationBuilder<double>(
      key: ValueKey(wei),
      tween: Tween<double>(begin: 0, end: targetEth),
      duration: const Duration(milliseconds: 850),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => _AssetTile(
        icon: Icons.diamond_outlined,
        name: 'Ethereum',
        symbol: 'Sepolia ETH',
        balance: '${_formatAnimatedEth(value)} ETH',
        value: 'Testnet balance',
        networkLabel: 'SEPOLIA',
        iconBackgroundColor: const Color(0xFFE0E8E2),
        iconColor: AppColors.forest,
      ),
    );
  }
}

class _StaggeredAssetEntry extends StatefulWidget {
  final int index;
  final Widget child;

  const _StaggeredAssetEntry({required this.index, required this.child});

  @override
  State<_StaggeredAssetEntry> createState() => _StaggeredAssetEntryState();
}

class _StaggeredAssetEntryState extends State<_StaggeredAssetEntry> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration(milliseconds: 90 * widget.index), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void didUpdateWidget(covariant _StaggeredAssetEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _visible = false;
      Future<void>.delayed(Duration(milliseconds: 90 * widget.index), () {
        if (mounted) setState(() => _visible = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        child: AnimatedSlide(
          offset: _visible ? Offset.zero : const Offset(0, .08),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      );
}

class _LeafRefreshGlyph extends StatefulWidget {
  final bool refreshing;
  final double progress;

  const _LeafRefreshGlyph({
    required this.refreshing,
    required this.progress,
  });

  @override
  State<_LeafRefreshGlyph> createState() => _LeafRefreshGlyphState();
}

class _LeafRefreshGlyphState extends State<_LeafRefreshGlyph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  );

  @override
  void didUpdateWidget(covariant _LeafRefreshGlyph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshing && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.refreshing && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(
        turns: widget.refreshing
            ? _controller
            : AlwaysStoppedAnimation<double>(widget.progress * .35),
        child: const Icon(
          Icons.eco_rounded,
          color: AppColors.forest,
          size: 25,
        ),
      );
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab();

  void _open(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => screen,
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity:
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          child: SlideTransition(
            position:
                Tween<Offset>(begin: const Offset(0.035, 0), end: Offset.zero)
                    .animate(CurvedAnimation(
                        parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _settingTile(BuildContext context, IconData icon, String title,
      String subtitle, Widget screen) {
    return InkWell(
      onTap: () => _open(context, screen),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(icon),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13)),
              ])),
          const Icon(Icons.chevron_right, size: 20),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(22), children: [
        const Text('Settings',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 20),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            _settingTile(context, Icons.security_outlined, 'Security',
                'Protect your wallet', const SecurityScreen()),
            const Divider(height: 1, indent: 72),
            _settingTile(context, Icons.key_outlined, 'Recovery phrase',
                'Keep your backup safe', const RecoveryPhraseScreen()),
            const Divider(height: 1, indent: 72),
            _settingTile(context, Icons.network_check_outlined, 'Network',
                'Sepolia testnet only', const NetworkScreen()),
            const Divider(height: 1, indent: 72),
            _settingTile(context, Icons.link_rounded, 'Connected Apps',
                'Manage wallet connections', const ConnectedAppsScreen()),
            const Divider(height: 1, indent: 72),
            _settingTile(context, Icons.info_outline, 'About NegosMint Wallet',
                'Version and wallet information', const AboutScreen()),
          ]),
        ),
      ]);
}
), '').replaceFirst(RegExp(r'\.
  const unit = 1000000000000000000;
  final whole = wei ~/ BigInt.from(unit);
  final fraction = (wei % BigInt.from(unit)).toString().padLeft(18, '0');
  final trimmed = fraction.replaceFirst(RegExp(r'0+$'), '');
  final shown = trimmed.isEmpty
      ? '0'
      : trimmed.substring(0, trimmed.length > 6 ? 6 : trimmed.length);
  return '$whole.$shown ETH';
}

class _AssetTile extends StatelessWidget {
  final IconData icon;
  final String name, symbol, balance, value;
  final String networkLabel;
  final Color iconBackgroundColor;
  final Color iconColor;
  final bool loading;

  const _AssetTile({
    required this.icon,
    required this.name,
    required this.symbol,
    required this.balance,
    required this.value,
    this.networkLabel = 'PLANNED',
    this.iconBackgroundColor = AppColors.mist,
    this.iconColor = AppColors.forest,
    this.loading = false,
  });
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: iconBackgroundColor,
                    borderRadius: BorderRadius.circular(15)),
                child: Icon(icon, color: iconColor, size: 23)),
            const SizedBox(width: 13),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(symbol,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          )),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: networkLabel == 'SEPOLIA'
                              ? const Color(0xFFE3EFE5)
                              : const Color(0xFFF0F0ED),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(networkLabel,
                            style: TextStyle(
                              color: networkLabel == 'SEPOLIA'
                                  ? AppColors.forest
                                  : Colors.black45,
                              fontSize: 8,
                              letterSpacing: .35,
                              fontWeight: FontWeight.w800,
                            )),
                      ),
                    ],
                  ),
                ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (loading)
                Container(
                  width: 78,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.mist,
                    borderRadius: BorderRadius.circular(8),
                  ),
                )
              else
                Text(balance,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(color: Colors.black45, fontSize: 11))
            ]),
          ])));
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab();

  void _open(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => screen,
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity:
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          child: SlideTransition(
            position:
                Tween<Offset>(begin: const Offset(0.035, 0), end: Offset.zero)
                    .animate(CurvedAnimation(
                        parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _settingTile(BuildContext context, IconData icon, String title,
      String subtitle, Widget screen) {
    return InkWell(
      onTap: () => _open(context, screen),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(icon),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13)),
              ])),
          const Icon(Icons.chevron_right, size: 20),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(22), children: [
        const Text('Settings',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 20),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            _settingTile(context, Icons.security_outlined, 'Security',
                'Protect your wallet', const SecurityScreen()),
            const Divider(height: 1, indent: 72),
            _settingTile(context, Icons.key_outlined, 'Recovery phrase',
                'Keep your backup safe', const RecoveryPhraseScreen()),
            const Divider(height: 1, indent: 72),
            _settingTile(context, Icons.network_check_outlined, 'Network',
                'Sepolia testnet only', const NetworkScreen()),
            const Divider(height: 1, indent: 72),
            _settingTile(context, Icons.link_rounded, 'Connected Apps',
                'Manage wallet connections', const ConnectedAppsScreen()),
            const Divider(height: 1, indent: 72),
            _settingTile(context, Icons.info_outline, 'About NegosMint Wallet',
                'Version and wallet information', const AboutScreen()),
          ]),
        ),
      ]);
}
), '');
  return trimmed.isEmpty ? '0' : trimmed;
}

String _formatEth(BigInt wei) {
  const unit = 1000000000000000000;
  final whole = wei ~/ BigInt.from(unit);
  final fraction = (wei % BigInt.from(unit)).toString().padLeft(18, '0');
  final trimmed = fraction.replaceFirst(RegExp(r'0+$'), '');
  final shown = trimmed.isEmpty
      ? '0'
      : trimmed.substring(0, trimmed.length > 6 ? 6 : trimmed.length);
  return '$whole.$shown ETH';
}

class _AssetTile extends StatelessWidget {
  final IconData icon;
  final String name, symbol, balance, value;
  final String networkLabel;
  final Color iconBackgroundColor;
  final Color iconColor;
  final bool loading;

  const _AssetTile({
    required this.icon,
    required this.name,
    required this.symbol,
    required this.balance,
    required this.value,
    this.networkLabel = 'PLANNED',
    this.iconBackgroundColor = AppColors.mist,
    this.iconColor = AppColors.forest,
    this.loading = false,
  });
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: iconBackgroundColor,
                    borderRadius: BorderRadius.circular(15)),
                child: Icon(icon, color: iconColor, size: 23)),
            const SizedBox(width: 13),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(symbol,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          )),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: networkLabel == 'SEPOLIA'
                              ? const Color(0xFFE3EFE5)
                              : const Color(0xFFF0F0ED),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(networkLabel,
                            style: TextStyle(
                              color: networkLabel == 'SEPOLIA'
                                  ? AppColors.forest
                                  : Colors.black45,
                              fontSize: 8,
                              letterSpacing: .35,
                              fontWeight: FontWeight.w800,
                            )),
                      ),
                    ],
                  ),
                ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (loading)
                Container(
                  width: 78,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.mist,
                    borderRadius: BorderRadius.circular(8),
                  ),
                )
              else
                Text(balance,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(color: Colors.black45, fontSize: 11))
            ]),
          ])));
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab();

  void _open(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => screen,
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity:
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          child: SlideTransition(
            position:
                Tween<Offset>(begin: const Offset(0.035, 0), end: Offset.zero)
                    .animate(CurvedAnimation(
                        parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _settingTile(BuildContext context, IconData icon, String title,
      String subtitle, Widget screen) {
    return InkWell(
      onTap: () => _open(context, screen),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(icon),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13)),
              ])),
          const Icon(Icons.chevron_right, size: 20),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(22), children: [
        const Text('Settings',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 20),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            _settingTile(context, Icons.security_outlined, 'Security',
                'Protect your wallet', const SecurityScreen()),
            const Divider(height: 1, indent: 72),
            _settingTile(context, Icons.key_outlined, 'Recovery phrase',
                'Keep your backup safe', const RecoveryPhraseScreen()),
            const Divider(height: 1, indent: 72),
            _settingTile(context, Icons.network_check_outlined, 'Network',
                'Sepolia testnet only', const NetworkScreen()),
            const Divider(height: 1, indent: 72),
            _settingTile(context, Icons.link_rounded, 'Connected Apps',
                'Manage wallet connections', const ConnectedAppsScreen()),
            const Divider(height: 1, indent: 72),
            _settingTile(context, Icons.info_outline, 'About NegosMint Wallet',
                'Version and wallet information', const AboutScreen()),
          ]),
        ),
      ]);
}
