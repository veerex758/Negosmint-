import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/wallet/wallet_service.dart';
import '../theme/app_theme.dart';

class RecoveryPhraseScreen extends StatefulWidget {
  const RecoveryPhraseScreen({super.key});
  @override
  State<RecoveryPhraseScreen> createState() => _RecoveryPhraseScreenState();
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
      setState(() {
        _phrase = phrase;
        _revealed = phrase != null && phrase.isNotEmpty;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Recovery phrase')),
        body: ListView(padding: const EdgeInsets.all(22), children: [
          Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  color: AppColors.mist,
                  borderRadius: BorderRadius.circular(20)),
              child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined,
                        color: AppColors.forest, size: 30),
                    SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text('Keep this secret',
                              style: TextStyle(
                                  fontSize: 21, fontWeight: FontWeight.w800)),
                          SizedBox(height: 6),
                          Text(
                              'Anyone with this phrase can control the wallet.',
                              style: TextStyle(height: 1.4))
                        ]))
                  ])),
          const SizedBox(height: 14),
          const SizedBox(height: 8),
          const Text(
              'Anyone with this phrase can control the wallet. Never screenshot it, send it to anyone, or enter it into a website.'),
          const SizedBox(height: 22),
          if (!_revealed)
            FilledButton.icon(
                onPressed: _loading ? null : _confirm,
                icon: const Icon(Icons.visibility_outlined),
                label:
                    Text(_loading ? 'Loading...' : 'Reveal recovery phrase')),
          if (_revealed) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.lock_outline_rounded, size: 19),
                    SizedBox(width: 8),
                    Expanded(
                        child: Text('Stored locally on this device',
                            style: TextStyle(fontWeight: FontWeight.w700))),
                  ]),
                  const SizedBox(height: 14),
                  Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (_phrase ?? '')
                          .split(' ')
                          .asMap()
                          .entries
                          .map((entry) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 9),
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outlineVariant)),
                              child: Text('${entry.key + 1}. ${entry.value}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700))))
                          .toList()),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _copyPhrase,
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy phrase'),
            ),
          ],
        ]),
      );

  Future<void> _copyPhrase() async {
    await Clipboard.setData(ClipboardData(text: _phrase ?? ''));

    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
          content: Text('Phrase copied — protect it carefully')),
    );
  }

  Future<void> _confirm() async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
              title: const Text('Reveal secret?'),
              content: const Text(
                  'Only continue if nobody can see your screen. Do not screenshot, share, or paste the phrase anywhere.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('Reveal'))
              ],
            ));
    if (ok == true) await _reveal();
  }
}
