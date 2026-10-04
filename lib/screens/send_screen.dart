import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../core/network/evm_rpc_service.dart';

class SendScreen extends StatefulWidget {
  final String address;
  const SendScreen({super.key, required this.address});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final _formKey = GlobalKey<FormState>();
  final _recipient = TextEditingController();
  final _amount = TextEditingController();
  String _asset = 'ETH';

  @override
  void dispose() {
    _recipient.dispose();
    _amount.dispose();
    super.dispose();
  }

  bool _validAddress(String value) =>
      RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(value.trim());

  Future<void> _review() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    if (_asset != 'ETH') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('USDC sending will be enabled after token support is added.')));
      return;
    }
    final amountWei = _ethToWei(_amount.text.trim());
    if (amountWei == null || amountWei <= BigInt.zero) return;
    try {
      final rpc = EvmRpcService();
      final nonce = await rpc.getTransactionCount(widget.address);
      final gas = await rpc.estimateNativeTransferGas(from: widget.address, to: _recipient.text.trim(), valueWei: amountWei);
      final gasPrice = await rpc.getGasPriceWei();
      final feeWei = gas * gasPrice;
      if (!mounted) return;
      showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Review transaction',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
            const SizedBox(height: 18),
            _Row('Asset', _asset),
            _Row('Amount', '${_amount.text.trim()} $_asset'),
            _Row('To', _recipient.text.trim()),
            _Row('Nonce', nonce.toString()),
            _Row('Gas limit', gas.toString()),
            _Row('Est. fee', _formatWei(feeWei) + ' ETH'),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.mist,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'This is a Sepolia testnet estimate. Signing and broadcasting are still disabled.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close review'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BigInt? _ethToWei(String value) {
    final parts = value.split('.');
    if (parts.length > 2 || parts.isEmpty || parts.first.isEmpty) return null;
    final whole = BigInt.tryParse(parts.first);
    if (whole == null || whole < BigInt.zero) return null;
    final decimals = parts.length == 2 ? parts[1] : '';
    if (decimals.length > 18 || (decimals.isNotEmpty && int.tryParse(decimals) == null)) return null;
    final fraction = decimals.padRight(18, '0');
    final fractionValue = fraction.isEmpty ? BigInt.zero : BigInt.parse(fraction);
    return whole * BigInt.from(1000000000000000000) + fractionValue;
  }

  String _formatWei(BigInt wei) {
    final unit = BigInt.from(1000000000000000000);
    final whole = wei ~/ unit;
    final fraction = (wei % unit).toString().padLeft(18, '0').replaceFirst(RegExp(r'0+
        appBar: AppBar(title: const Text('Send')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
            children: [
              const Text('Send crypto',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('Testnet transaction flow. No real funds are broadcast.',
                  style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 26),
              DropdownButtonFormField<String>(
                value: _asset,
                decoration: const InputDecoration(
                  labelText: 'Asset',
                  prefixIcon: Icon(Icons.token_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'ETH', child: Text('Ethereum (ETH)')),
                  DropdownMenuItem(value: 'USDC', child: Text('USD Coin (USDC)')),
                ],
                onChanged: (value) => setState(() => _asset = value!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _recipient,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Recipient address',
                  hintText: '0x...',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a recipient address';
                  }
                  if (!_validAddress(value)) return 'Enter a valid EVM address';
                  if (value.trim().toLowerCase() ==
                      widget.address.toLowerCase()) {
                    return 'Recipient cannot be your own address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  hintText: '0.00',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                validator: (value) {
                  final n = double.tryParse(value?.trim() ?? '');
                  if (n == null || n <= 0) {
                    return 'Enter an amount greater than 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _review,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Review transaction'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 72,
              child: Text(label, style: const TextStyle(color: Colors.black54)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
}
), '');
    return fraction.isEmpty ? whole.toString() : whole.toString() + '.' + fraction.substring(0, fraction.length > 6 ? 6 : fraction.length);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Send')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
            children: [
              const Text('Send crypto',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('Testnet transaction flow. No real funds are broadcast.',
                  style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 26),
              DropdownButtonFormField<String>(
                value: _asset,
                decoration: const InputDecoration(
                  labelText: 'Asset',
                  prefixIcon: Icon(Icons.token_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'ETH', child: Text('Ethereum (ETH)')),
                  DropdownMenuItem(value: 'USDC', child: Text('USD Coin (USDC)')),
                ],
                onChanged: (value) => setState(() => _asset = value!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _recipient,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Recipient address',
                  hintText: '0x...',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a recipient address';
                  }
                  if (!_validAddress(value)) return 'Enter a valid EVM address';
                  if (value.trim().toLowerCase() ==
                      widget.address.toLowerCase()) {
                    return 'Recipient cannot be your own address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  hintText: '0.00',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                validator: (value) {
                  final n = double.tryParse(value?.trim() ?? '');
                  if (n == null || n <= 0) {
                    return 'Enter an amount greater than 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _review,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Review transaction'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 72,
              child: Text(label, style: const TextStyle(color: Colors.black54)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
}
