import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/wallet/wallet_service.dart';

class RecoveryPhraseScreen extends StatefulWidget {
  const RecoveryPhraseScreen({super.key});
  @override State<RecoveryPhraseScreen> createState() => _RecoveryPhraseScreenState();
}
class _RecoveryPhraseScreenState extends State<RecoveryPhraseScreen> {
  bool _revealed = false;
  String? _phrase;
  bool _loading = false;
  Future<void> _reveal() async {
    if (_revealed) return;
    setState(() => _loading = true);
    try {
      final phrase = await WalletService().getRecoveryPhrase();
      if (!mounted) return;
      setState(() { _phrase = phrase; _revealed = phrase != null && phrase.isNotEmpty; });
    } finally { if (mounted) setState(() => _loading = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Recovery phrase')),
    body: ListView(padding: const EdgeInsets.all(22), children: [
      const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange),
      const SizedBox(height: 14),
      const Text('Keep this secret', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      const Text('Anyone with this phrase can control the wallet. Never screenshot it, send it to anyone, or enter it into a website.'),
      const SizedBox(height: 22),
      if (!_revealed) FilledButton.icon(onPressed: _loading ? null : _confirm, icon: const Icon(Icons.visibility_outlined), label: Text(_loading ? 'Loading...' : 'Reveal recovery phrase')),
      if (_revealed) ...[
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Text(_phrase ?? '', style: const TextStyle(fontSize: 18, height: 1.7, fontWeight: FontWeight.w700)))),
        const SizedBox(height: 10),
        OutlinedButton.icon(onPressed: () async { await Clipboard.setData(ClipboardData(text: _phrase ?? '')); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phrase copied — protect it carefully'))); }, icon: const Icon(Icons.copy), label: const Text('Copy phrase')),
      ],
    ]),
  );
  Future<void> _confirm() async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Reveal secret?'),
      content: const Text('Only continue if nobody can see your screen. Do not screenshot, share, or paste the phrase anywhere.'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Reveal'))],
    ));
    if (ok == true) await _reveal();
  }
}