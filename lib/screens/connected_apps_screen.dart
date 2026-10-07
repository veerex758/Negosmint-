import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../wallet/connection/wallet_connection_manager.dart';
import '../wallet/connection/wallet_connection_session.dart';

class ConnectedAppsScreen extends StatefulWidget {
  const ConnectedAppsScreen({super.key});
  @override
  State<ConnectedAppsScreen> createState() => _ConnectedAppsScreenState();
}

class _ConnectedAppsScreenState extends State<ConnectedAppsScreen> {
  final _manager = WalletConnectionManager();
  late Future<List<WalletConnectionSession>> _sessions;

  @override
  void initState() {
    super.initState();
    _sessions = _manager.getActiveConnections();
  }

  Future<void> _revoke(WalletConnectionSession session) async {
    await _manager.revokeConnection(session.sessionId);
    if (!mounted) return;
    setState(() => _sessions = _manager.getActiveConnections());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(session.appName + ' disconnected.')),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Connected Apps')),
    body: FutureBuilder<List<WalletConnectionSession>>(
      future: _sessions,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Unable to load connections.'));
        }
        final sessions = snapshot.data ?? const [];
        if (sessions.isEmpty) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.link_off_rounded, size: 54),
              SizedBox(height: 14),
              Text('No connected apps',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              SizedBox(height: 8),
              Text('Apps must ask for permission before they can connect to this wallet.',
                  textAlign: TextAlign.center),
            ]),
          ));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(22),
          itemCount: sessions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final session = sessions[index];
            return Card(child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const CircleAvatar(
                    backgroundColor: AppColors.mist,
                    child: Icon(Icons.apps_rounded, color: AppColors.forest),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(session.appName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                  IconButton(
                    tooltip: 'Disconnect',
                    onPressed: () => _revoke(session),
                    icon: const Icon(Icons.link_off_rounded),
                  ),
                ]),
                const SizedBox(height: 14),
                Text(session.network + ' • Chain ' + session.chainId.toString(),
                    style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 10),
                Text(_shorten(session.walletAddress),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: session.permissions.map((permission) =>
                    Chip(label: Text(permission.label))).toList(),
                ),
                const SizedBox(height: 8),
                Text('Expires ' + session.expiresAt.toLocal().toString(),
                    style: const TextStyle(fontSize: 12, color: Colors.black45)),
              ]),
            ));
          },
        );
      },
    ),
  );

  String _shorten(String address) =>
      address.length > 12 ? address.substring(0, 8) + '…' + address.substring(address.length - 6) : address;
}
