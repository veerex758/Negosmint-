import 'package:flutter/material.dart';
import '../core/wallet/wallet_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _walletService = WalletService();
  int _step = 0;
  WalletSnapshot? _snapshot;
  int? _checkA;
  int? _checkB;
  String? _answerA;
  String? _answerB;
  bool _busy = false;
  String? _error;

  Future<void> _createWallet() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final snapshot = await _walletService.createWallet();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _checkA = 4;
        _checkB = 9;
        _step = 1;
        _busy = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not create wallet. Please try again.';
      });
    }
  }

  void _finish() {
    final snapshot = _snapshot;
    if (snapshot == null) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 650),
        pageBuilder: (_, __, ___) => HomeScreen(address: snapshot.address),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: SlideTransition(
            position:
                Tween<Offset>(begin: const Offset(0, .04), end: Offset.zero)
                    .animate(CurvedAnimation(
                        parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = switch (_step) {
      0 => _welcome(),
      1 => _phrase(),
      _ => _backupCheck(),
    };
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
              child: Row(
                children: List.generate(
                    3,
                    (index) => Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 280),
                            margin: EdgeInsets.only(right: index == 2 ? 0 : 6),
                            height: 4,
                            decoration: BoxDecoration(
                              color: index <= _step
                                  ? AppColors.forest
                                  : AppColors.mist,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        )),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                child: KeyedSubtree(key: ValueKey(_step), child: content),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _welcome() => Padding(
        padding: const EdgeInsets.fromLTRB(24, 56, 24, 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _brand(),
          const Spacer(),
          const Icon(Icons.shield_rounded, size: 68, color: AppColors.forest),
          const SizedBox(height: 22),
          const Text('Your wallet.\nYour keys.',
              style: TextStyle(
                  fontSize: 40,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  color: AppColors.charcoal)),
          const SizedBox(height: 16),
          const Text(
              'A non-custodial wallet where NegosMint does not control your recovery phrase.',
              style:
                  TextStyle(fontSize: 16, height: 1.5, color: Colors.black54)),
          const SizedBox(height: 18),
          _notice('Testnet-first',
              'This build is for wallet development and testing.'),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.withValues(alpha: 0.18)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: Colors.redAccent),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(
                    _error!,
                    style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w600,
                        height: 1.35),
                  )),
                ],
              ),
            ),
          ],
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _createWallet,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 17),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Create new wallet'),
            ),
          ),
        ]),
      );

  Widget _phrase() {
    final words = _snapshot!.mnemonic;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 30, 22, 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _back(),
        const SizedBox(height: 26),
        const Text('Recovery phrase',
            style: TextStyle(fontSize: 31, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: AppColors.mist, borderRadius: BorderRadius.circular(16)),
            child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline_rounded, color: AppColors.forest),
                  SizedBox(width: 10),
                  Expanded(
                      child: Text(
                          'Write these 12 words down offline. Never screenshot, message, or share them.',
                          style:
                              TextStyle(color: Colors.black54, height: 1.45)))
                ])),
        const SizedBox(height: 20),
        Expanded(
          child: GridView.builder(
            itemCount: words.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 54,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (_, index) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.mist),
              ),
              child: Row(children: [
                Text((index + 1).toString(),
                    style: const TextStyle(
                        color: Colors.black38, fontWeight: FontWeight.w700)),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(words[index],
                        style: const TextStyle(fontWeight: FontWeight.w700))),
              ]),
            ),
          ),
        ),
        _notice('Security rule',
            'NegosMint will never ask you to send us these words.'),
        const SizedBox(height: 14),
        SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => setState(() => _step = 2),
              child: const Text('I wrote it down'),
            )),
      ]),
    );
  }

  Widget _backupCheck() {
    final words = _snapshot!.mnemonic;
    final first = _checkA!;
    final second = _checkB!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 30, 22, 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _back(),
        const SizedBox(height: 26),
        const Text('Confirm backup',
            style: TextStyle(fontSize: 31, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(
            'Select the correct words for positions ' +
                (first + 1).toString() +
                ' and ' +
                (second + 1).toString() +
                '.',
            style: const TextStyle(color: Colors.black54, height: 1.45)),
        const Spacer(),
        _wordPicker(first, words[first]),
        const SizedBox(height: 16),
        _wordPicker(second, words[second]),
        const Spacer(),
        SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _selectedCorrect ? _finish : null,
              child: const Text('Open my wallet'),
            )),
      ]),
    );
  }

  Widget _wordPicker(int index, String correct) {
    final options = <String>{
      correct,
      _snapshot!.mnemonic[(index + 1) % _snapshot!.mnemonic.length],
      _snapshot!.mnemonic[(index + 3) % _snapshot!.mnemonic.length],
    }.toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Word ' + (index + 1).toString(),
          style: const TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options
            .map((word) => ChoiceChip(
                  label: Text(word),
                  selected:
                      index == _checkA ? _answerA == word : _answerB == word,
                  onSelected: (_) => setState(() {
                    if (index == _checkA) {
                      _answerA = word;
                    } else {
                      _answerB = word;
                    }
                  }),
                ))
            .toList(),
      ),
    ]);
  }

  bool get _selectedCorrect =>
      _answerA == _snapshot!.mnemonic[_checkA!] &&
      _answerB == _snapshot!.mnemonic[_checkB!];

  Widget _brand() => Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
              color: AppColors.forest, borderRadius: BorderRadius.circular(15)),
          child: const Center(
              child: Text('NM',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w900))),
        ),
        const SizedBox(width: 12),
        const Text('NegosMint Wallet',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      ]);

  Widget _back() => IconButton(
        onPressed: () => setState(() => _step = (_step - 1).clamp(0, 2)),
        icon: const Icon(Icons.arrow_back_rounded),
        padding: EdgeInsets.zero,
        alignment: Alignment.centerLeft,
      );

  Widget _notice(String title, String body) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
            color: AppColors.mist, borderRadius: BorderRadius.circular(17)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.forest),
          const SizedBox(width: 11),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(body,
                    style:
                        const TextStyle(color: Colors.black54, height: 1.35)),
              ])),
        ]),
      );
}
