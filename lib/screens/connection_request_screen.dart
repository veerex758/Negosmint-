import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../wallet/connection/wallet_connection_manager.dart';
import '../wallet/connection/wallet_connection_request.dart';
import '../wallet/connection/wallet_connection_result.dart';
import 'home_screen.dart';

class ConnectionRequestScreen extends StatefulWidget {
  final WalletConnectionRequest request;
  const ConnectionRequestScreen({super.key, required this.request});
  @override
  State<ConnectionRequestScreen> createState() => _ConnectionRequestScreenState();
}

class _ConnectionRequestScreenState extends State<ConnectionRequestScreen> {
  final _manager = WalletConnectionManager();
  bool _busy = false;
  String? _error;

  Future<void> _approve() async {
    setState(() { _busy = true; _error = null; });
    try {
      final result = await _manager.approveConnection(widget.request);
      if (!mounted) return;
      if (result.status != WalletConnectionResultStatus.approved) {
        throw const WalletConnectionException('Connection was not approved.');
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeScreen(address: result.walletAddress)),
      );
    } on WalletConnectionException catch (e) {
      if (!mounted) return;
      setState(() { _busy = false; _error = e.message; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _busy = false; _error = 'Unable to approve this connection request.'; });
    }
  }

  void _reject() => Navigator.of(context).pop(_manager.rejectConnection(widget.request));

  @override
  Widget build(BuildContext context) {
    final network = _manager.networkFor(widget.request.chainId);
    return Scaffold(
      appBar: AppBar(title: const Text('Connection Request')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
        children: [
          const Icon(Icons.link_rounded, size: 48, color: AppColors.forest),
          const SizedBox(height: 16),
          Text('Connect to ' + widget.request.appName + '?',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('Only the public wallet information listed below will be shared.',
              style: TextStyle(height: 1.45)),
          const SizedBox(height: 24),
          Card(child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(children: [
              _InfoRow(label: 'App', value: widget.request.appName),
              const Divider(height: 26),
              _InfoRow(label: 'App ID', value: widget.request.appIdentifier),
              const Divider(height: 26),
              _InfoRow(label: 'Network', value: network.name),
              const Divider(height: 26),
              _InfoRow(label: 'Chain ID', value: network.chainId.toString()),
            ]),
          )),
          const SizedBox(height: 16),
          const Text('Requested permissions',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Card(child: Column(
            children: widget.request.permissions.map((permission) => ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: Text(permission.label),
              subtitle: permission == WalletConnectionPermission.requestTransaction
                  ? const Text('This does not authorize automatic transactions.')
                  : null,
            )).toList(),
          )),
          if (widget.request.requestsSigning) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                'Signing is never automatic. Every signature or transaction must be reviewed and explicitly approved in the wallet.',
                style: TextStyle(fontWeight: FontWeight.w600, height: 1.45),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 26),
          FilledButton(onPressed: _busy ? null : _approve,
              child: Text(_busy ? 'Connecting…' : 'Connect')),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: _busy ? null : _reject, child: const Text('Cancel')),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(width: 88, child: Text(label, style: const TextStyle(color: Colors.black54))),
      Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700))),
    ],
  );
}
