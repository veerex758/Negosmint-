import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'receive_screen.dart';
import 'send_screen.dart';
import 'package:flutter/services.dart';
import '../core/network/evm_rpc_service.dart';

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
      _HomeTab(address: widget.address, onSend: _openSend, onReceive: _openReceive),
      const _ActivityTab(),
      const _SettingsTab(),
    ];
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(.03, 0), end: Offset.zero).animate(animation),
              child: child,
            ),
          ),
          child: KeyedSubtree(key: ValueKey(_index), child: pages[_index]),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Wallet'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Activity'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  void _openReceive() {
    final address = widget.address;
    if (address == null || address.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ReceiveScreen(address: address),
    ));
  }

  void _openSend() {
    final address = widget.address;
    if (address == null || address.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SendScreen(address: address),
    ));
  }
}

class _HomeTab extends StatelessWidget {
  final String? address;
  final VoidCallback onSend;
  final VoidCallback onReceive;
  const _HomeTab({this.address, required this.onSend, required this.onReceive});

  @override
  Widget build(BuildContext context) => CustomScrollView(
    physics: const BouncingScrollPhysics(),
    slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
        sliver: SliverToBoxAdapter(child: Row(children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: AppColors.forest, borderRadius: BorderRadius.circular(16)),
              child: const Center(child: Text('NM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)))),
          const SizedBox(width: 14),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Good day', style: TextStyle(color: Colors.black54, fontSize: 13)),
            Text('Your Wallet', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.charcoal)),
          ])),
          IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded)),
        ])),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
        sliver: SliverToBoxAdapter(child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.forest, Color(0xFF31563F)]),
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [BoxShadow(color: Color(0x241E3A2B), blurRadius: 24, offset: Offset(0, 12))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('Total balance', style: TextStyle(color: Color(0xBFFFFFFF), fontSize: 13)),
              const Spacer(),
              IconButton(onPressed: () {}, color: Colors.white, icon: const Icon(Icons.visibility_outlined)),
            ]),
            const SizedBox(height: 4),
            _LiveEthBalance(address: address),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(child: _Action(label: 'Send', icon: Icons.arrow_upward_rounded, onTap: onSend)),
              const SizedBox(width: 10),
              Expanded(child: _Action(label: 'Receive', icon: Icons.arrow_downward_rounded, onTap: onReceive)),
            ]),
          ]),
        )),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 8),
        sliver: SliverToBoxAdapter(child: Row(children: [
          const Expanded(child: Text('Assets', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
          TextButton(onPressed: () {}, child: const Text('Manage')),
        ])),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        sliver: SliverList.list(children: const [
          _AssetTile(icon: Icons.currency_bitcoin_rounded, name: 'Bitcoin', symbol: 'BTC', balance: '0.000000', value: r'$0.00'),
          SizedBox(height: 10),
          _LiveEthAsset(address: address),
          SizedBox(height: 10),
          _AssetTile(icon: Icons.token_outlined, name: 'USD Coin', symbol: 'USDC', balance: '0.00', value: r'$0.00'),
        ]),
      ),
      if (address != null)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
          sliver: SliverToBoxAdapter(child: _AddressCard(address!)),
        ),
    ],
  );
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
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('EVM address', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(address, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ])),
        IconButton(onPressed: () async { await Clipboard.setData(ClipboardData(text: address)); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Address copied'))); }, icon: const Icon(Icons.copy_rounded)),
      ]),
    ),
  );
}

class _Action extends StatelessWidget {
  final String label; final IconData icon; final VoidCallback onTap;
  const _Action({required this.label, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onTap, icon: Icon(icon, size: 18), label: Text(label),
    style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.forest,
      padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
  );
}

class _LiveEthBalance extends StatelessWidget {
  final String? address;
  const _LiveEthBalance({this.address});

  @override
  Widget build(BuildContext context) {
    if (address == null || address!.isEmpty) {
      return const Text(r'$0.00', style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -1));
    }
    return FutureBuilder<BigInt>(
      future: EvmRpcService().getNativeBalanceInWei(address!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 43, child: Align(alignment: Alignment.centerLeft, child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))));
        }
        if (snapshot.hasError) {
          return const Text('Network unavailable', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700));
        }
        return Text(_formatEth(snapshot.data!), style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -1));
      },
    );
  }
}

class _LiveEthAsset extends StatelessWidget {
  final String? address;
  const _LiveEthAsset({this.address});

  @override
  Widget build(BuildContext context) {
    if (address == null || address!.isEmpty) {
      return const _AssetTile(icon: Icons.diamond_outlined, name: 'Ethereum', symbol: 'ETH', balance: '0.000000', value: r'$0.00');
    }
    return FutureBuilder<BigInt>(
      future: EvmRpcService().getNativeBalanceInWei(address!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AssetTile(icon: Icons.diamond_outlined, name: 'Ethereum', symbol: 'Sepolia ETH', balance: 'Loading...', value: 'Testnet');
        }
        if (snapshot.hasError) {
          return const _AssetTile(icon: Icons.diamond_outlined, name: 'Ethereum', symbol: 'Sepolia ETH', balance: 'Unavailable', value: 'Testnet');
        }
        return _AssetTile(icon: Icons.diamond_outlined, name: 'Ethereum', symbol: 'Sepolia ETH', balance: _formatEth(snapshot.data!), value: 'Testnet');
      },
    );
  }
}

String _formatEth(BigInt wei) {
  const unit = 1000000000000000000;
  final whole = wei ~/ BigInt.from(unit);
  final fraction = (wei % BigInt.from(unit)).toString().padLeft(18, '0');
  final trimmed = fraction.replaceFirst(RegExp(r'0+
  final IconData icon; final String name, symbol, balance, value;
  const _AssetTile({required this.icon, required this.name, required this.symbol, required this.balance, required this.value});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
    Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.mist, borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: AppColors.forest)),
    const SizedBox(width: 13),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
      Text(symbol, style: const TextStyle(color: Colors.black45, fontSize: 12)),
    ])),
    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(balance, style: const TextStyle(fontWeight: FontWeight.w700)),
      Text(value, style: const TextStyle(color: Colors.black45, fontSize: 12)),
    ]),
  ]));
}

class _ActivityTab extends StatelessWidget {
  const _ActivityTab();
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(width: 72, height: 72, decoration: BoxDecoration(color: AppColors.mist, borderRadius: BorderRadius.circular(24)),
      child: const Icon(Icons.receipt_long_rounded, color: AppColors.forest, size: 34)),
    const SizedBox(height: 18),
    const Text('No activity yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
    const SizedBox(height: 6),
    const Text('Your wallet transactions will appear here.', style: TextStyle(color: Colors.black54)),
  ]));
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab();
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(22), children: [
    const Text('Settings', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
    const SizedBox(height: 20),
    Card(child: Column(children: const [
      ListTile(leading: Icon(Icons.security_outlined), title: Text('Security'), trailing: Icon(Icons.chevron_right)),
      ListTile(leading: Icon(Icons.key_outlined), title: Text('Recovery phrase'), trailing: Icon(Icons.chevron_right)),
      ListTile(leading: Icon(Icons.network_check_outlined), title: Text('Network'), trailing: Icon(Icons.chevron_right)),
      ListTile(leading: Icon(Icons.info_outline), title: Text('About NegosMint Wallet'), trailing: Icon(Icons.chevron_right)),
    ])),
  ]);
}
), '');
  final shown = trimmed.isEmpty ? '0' : trimmed.substring(0, trimmed.length > 6 ? 6 : trimmed.length);
  return whole.toString() + '.' + shown + ' ETH';
}

class _AssetTile extends StatelessWidget {
  final IconData icon; final String name, symbol, balance, value;
  const _AssetTile({required this.icon, required this.name, required this.symbol, required this.balance, required this.value});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
    Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.mist, borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: AppColors.forest)),
    const SizedBox(width: 13),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
      Text(symbol, style: const TextStyle(color: Colors.black45, fontSize: 12)),
    ])),
    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(balance, style: const TextStyle(fontWeight: FontWeight.w700)),
      Text(value, style: const TextStyle(color: Colors.black45, fontSize: 12)),
    ]),
  ]));
}

class _ActivityTab extends StatelessWidget {
  const _ActivityTab();
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(width: 72, height: 72, decoration: BoxDecoration(color: AppColors.mist, borderRadius: BorderRadius.circular(24)),
      child: const Icon(Icons.receipt_long_rounded, color: AppColors.forest, size: 34)),
    const SizedBox(height: 18),
    const Text('No activity yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
    const SizedBox(height: 6),
    const Text('Your wallet transactions will appear here.', style: TextStyle(color: Colors.black54)),
  ]));
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab();
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(22), children: [
    const Text('Settings', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
    const SizedBox(height: 20),
    Card(child: Column(children: const [
      ListTile(leading: Icon(Icons.security_outlined), title: Text('Security'), trailing: Icon(Icons.chevron_right)),
      ListTile(leading: Icon(Icons.key_outlined), title: Text('Recovery phrase'), trailing: Icon(Icons.chevron_right)),
      ListTile(leading: Icon(Icons.network_check_outlined), title: Text('Network'), trailing: Icon(Icons.chevron_right)),
      ListTile(leading: Icon(Icons.info_outline), title: Text('About NegosMint Wallet'), trailing: Icon(Icons.chevron_right)),
    ])),
  ]);
}
