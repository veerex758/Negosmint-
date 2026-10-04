import 'dart:async';
import 'package:flutter/material.dart';
import '../core/wallet/wallet_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    Timer(const Duration(milliseconds: 1900), _openNext);
  }

  Future<void> _openNext() async {
    if (!mounted) return;
    final service = WalletService();
    WalletSnapshot? snapshot;
    try {
      snapshot = await service.restoreWallet();
    } catch (_) {
      snapshot = null;
    }
    final hasWallet = snapshot != null;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 650),
        pageBuilder: (_, animation, __) => hasWallet
            ? HomeScreen(address: snapshot!.address)
            : const OnboardingScreen(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, .04), end: Offset.zero)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.forest,
    body: Center(
      child: FadeTransition(
        opacity: _fade,
        child: ScaleTransition(
          scale: _scale,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 92, height: 92,
              decoration: BoxDecoration(
                color: AppColors.gold, borderRadius: BorderRadius.circular(28),
                boxShadow: const [BoxShadow(color: Color(0x55201F18), blurRadius: 30, offset: Offset(0, 12))],
              ),
              child: const Center(child: Text('NM', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white))),
            ),
            const SizedBox(height: 22),
            const Text('NegosMint', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -.8)),
            const SizedBox(height: 4),
            const Text('WALLET', style: TextStyle(color: AppColors.sage, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 4)),
          ]),
        ),
      ),
    ),
  );
}
