import 'package:flutter/material.dart';

import '../core/network/evm_rpc_service.dart';
import '../core/wallet/wallet_service.dart';
import '../theme/app_theme.dart';
import '../core/wallet/payment_uri.dart';
import 'qr_scanner_screen.dart';

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
  final WalletService _walletService = WalletService();
  String _asset = 'ETH';
  bool _sending = false;
  bool _reviewPressed = false;

  @override
  void dispose() {
    _recipient.dispose();
    _amount.dispose();
    super.dispose();
  }

  bool _validAddress(String value) =>
      RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(value.trim());

  Future<void> _review() async {
    if (_sending) return;
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    if (widget.address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wallet address is unavailable.')),
      );
      return;
    }
    if (_asset != 'ETH') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('USDC sending is not enabled yet.')),
      );
      return;
    }

    final amountWei = _ethToWei(_amount.text.trim());
    if (amountWei == null || amountWei <= BigInt.zero) return;

    try {
      final rpc = EvmRpcService();
      final balance = await rpc.getNativeBalanceInWei(widget.address);
      final nonce = await rpc.getTransactionCount(widget.address);
      final gas = await rpc.estimateNativeTransferGas(
        from: widget.address,
        to: _recipient.text.trim(),
        valueWei: amountWei,
      );
      if (await rpc.getChainId() != EvmRpcService.chainId) {
        throw const WalletException(
          'Wrong network detected. Sepolia is required.',
        );
      }
      final gasPrice = await rpc.getGasPriceWei();
      final feeWei = gas * gasPrice;

      if (amountWei + feeWei > balance) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Insufficient Sepolia ETH for amount plus network fee.',
            ),
          ),
        );
        return;
      }

      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheetContext) => Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Review transaction',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              _Row('Asset', _asset),
              _Row('Amount', '${_amount.text.trim()} ETH'),
              _Row('To', _recipient.text.trim()),
              _Row('Nonce', nonce.toString()),
              _Row('Gas limit', gas.toString()),
              _Row('Est. fee', '${_formatWei(feeWei)} ETH'),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.mist,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Sepolia testnet only. Your recovery phrase stays on this device. No mainnet transaction is possible from this flow.',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _confirmAndSend(sheetContext, amountWei),
                  child: const Text('Send on Sepolia'),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not prepare transaction: $error')),
      );
    }
  }

  Future<void> _confirmAndSend(
    BuildContext sheetContext,
    BigInt amountWei,
  ) async {
    if (_sending) return;
    setState(() => _sending = true);
    Navigator.of(sheetContext).pop();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final hash = await _walletService.sendSepoliaEth(
        to: _recipient.text.trim(),
        valueWei: amountWei,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      if (mounted) setState(() => _sending = false);
      if (_recipient.text.isNotEmpty) _recipient.clear();
      _amount.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sent on Sepolia: ${hash.length > 10 ? hash.substring(0, 10) : hash}...',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context).pop();
      if (mounted) setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Transaction failed: $error')),
      );
    }
  }

  Future<void> _scanPaymentQr() async {
    final request = await Navigator.of(context).push<PaymentRequest>(
      MaterialPageRoute<PaymentRequest>(
        builder: (_) => const QrScannerScreen(),
      ),
    );
    if (!mounted || request == null) return;
    if (request.chainId != PaymentUriParser.sepoliaChainId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Only Ethereum Sepolia payment requests are supported.'),
        ),
      );
      return;
    }
    setState(() {
      _asset = 'ETH';
      _recipient.text = request.address;
      if (request.amountWei != null) {
        _amount.text = _weiToInput(request.amountWei!);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          request.amountWei == null
              ? 'Recipient address scanned.'
              : 'Recipient and requested ETH amount scanned. Review before sending.',
        ),
      ),
    );
  }

  String _weiToInput(BigInt wei) {
    final unit = BigInt.from(1000000000000000000);
    final whole = wei ~/ unit;
    final fraction = (wei % unit)
        .toString()
        .padLeft(18, '0')
        .replaceFirst(RegExp(r'0+$'), '');
    return fraction.isEmpty ? whole.toString() : '$whole.$fraction';
  }

  BigInt? _ethToWei(String value) {
    final parts = value.split('.');
    if (parts.length > 2 || parts.first.isEmpty) return null;
    final whole = BigInt.tryParse(parts.first);
    if (whole == null || whole < BigInt.zero) return null;
    final decimals = parts.length == 2 ? parts[1] : '';
    if (decimals.length > 18 ||
        (decimals.isNotEmpty && int.tryParse(decimals) == null)) {
      return null;
    }
    final fraction = decimals.padRight(18, '0');
    return whole * BigInt.from(1000000000000000000) + BigInt.parse(fraction);
  }

  String _formatWei(BigInt wei) {
    final unit = BigInt.from(1000000000000000000);
    final whole = wei ~/ unit;
    final fraction = (wei % unit)
        .toString()
        .padLeft(18, '0')
        .replaceFirst(RegExp(r'0+$'), '');
    return fraction.isEmpty
        ? whole.toString()
        : '$whole.${fraction.substring(0, fraction.length > 6 ? 6 : fraction.length)}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Send')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
            children: [
              const Row(
                children: [
                  Icon(Icons.north_east_rounded, color: AppColors.forest),
                  SizedBox(width: 10),
                  Text(
                    'Send crypto',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Testnet transaction flow. No real funds are used.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.mist,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.science_outlined, color: AppColors.forest),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Sepolia testnet only. Double-check the recipient address before sending.',
                        style: TextStyle(
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                initialValue: _asset,
                decoration: const InputDecoration(
                  labelText: 'Asset',
                  prefixIcon: Icon(Icons.token_outlined),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'ETH',
                    child: Text('Ethereum (ETH)'),
                  ),
                  DropdownMenuItem(
                    value: 'USDC',
                    child: Text('USD Coin (USDC)'),
                  ),
                ],
                onChanged: (value) => setState(() => _asset = value!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _recipient,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Recipient address',
                  hintText: '0x...',
                  prefixIcon: const Icon(
                    Icons.account_balance_wallet_outlined,
                  ),
                  suffixIcon: IconButton(
                    tooltip: 'Scan payment QR',
                    onPressed: _sending ? null : _scanPaymentQr,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a recipient address';
                  }
                  if (!_validAddress(value)) {
                    return 'Enter a valid EVM address';
                  }
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
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  hintText: '0.00',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                validator: (value) {
                  final raw = value?.trim() ?? '';
                  final wei = _ethToWei(raw);
                  if (wei == null || wei <= BigInt.zero) {
                    return 'Enter a valid amount greater than 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 26),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        color: AppColors.forest,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Review the address and amount before confirming. Blockchain transactions cannot be easily reversed.',
                          style: TextStyle(
                            color: Colors.black54,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AnimatedScale(
                scale: _reviewPressed ? .98 : 1,
                duration: const Duration(milliseconds: 90),
                child: GestureDetector(
                  onTapDown: _sending
                      ? null
                      : (_) => setState(() => _reviewPressed = true),
                  onTapCancel: _sending
                      ? null
                      : () => setState(() => _reviewPressed = false),
                  onTapUp: _sending
                      ? null
                      : (_) => setState(() => _reviewPressed = false),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _sending ? null : _review,
                      icon: const Icon(Icons.visibility_outlined),
                      label: Text(
                        _sending ? 'Sending...' : 'Review transaction',
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
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
              child: Text(
                label,
                style: const TextStyle(color: Colors.black54),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
}
