import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/wallet/wallet_service.dart';
import 'wallet_lock_screen.dart';
import 'onboarding_screen.dart';
import '../wallet/connection/wallet_deep_link_receiver.dart';
import '../wallet/connection/wallet_connection_request.dart';
import 'connection_request_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _navigationTimer;
  late final WalletDeepLinkReceiver _deepLinkReceiver;
  WalletConnectionRequest? _incomingRequest;

  @override
  void initState() {
    super.initState();
    _deepLinkReceiver = WalletDeepLinkReceiver();
    _deepLinkReceiver.requests.listen(_handleIncomingRequest);
    _deepLinkReceiver.start();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1850),
    )..forward();

    _navigationTimer = Timer(
      const Duration(milliseconds: 2050),
      _openNext,
    );
  }

  void _handleIncomingRequest(WalletConnectionRequest request) {
    if (!mounted || _incomingRequest != null) return;
    _incomingRequest = request;
    _navigationTimer?.cancel();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ConnectionRequestScreen(request: request),
      ),
    );
  }

  Future<void> _openNext() async {
    if (_incomingRequest != null) return;
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
        transitionDuration: const Duration(milliseconds: 560),
        pageBuilder: (_, animation, __) => hasWallet
            ? WalletLockScreen(address: snapshot!.address)
            : const OnboardingScreen(),
        transitionsBuilder: (_, animation, __, child) {
          final curve = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curve,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, .025),
                end: Offset.zero,
              ).animate(curve),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _deepLinkReceiver.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF03140D),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Curves.easeInOutCubic.transform(_controller.value);
          final logoT = Curves.easeOutBack.transform(
            math.min(1, _controller.value / .58),
          );
          final textT = Curves.easeOutCubic.transform(
            math.max(0.0, math.min(1.0, (t - .24) / .42)),
          );
          final barT = Curves.easeOutCubic.transform(
            math.max(0.0, math.min(1.0, (t - .48) / .34)),
          );
          final ringT = Curves.easeOutCubic.transform(
            math.max(0.0, math.min(1.0, (t - .08) / .92)),
          );
          final exitT = Curves.easeInCubic.transform(
            math.max(0.0, math.min(1.0, (t - .76) / .24)),
          );

          return Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -.15),
                    radius: 1.05,
                    colors: [
                      Color(0xFF0D3B25),
                      Color(0xFF052117),
                      Color(0xFF03140D),
                    ],
                  ),
                ),
              ),
              CustomPaint(
                painter: _WalletRingPainter(progress: ringT, exit: exitT),
              ),
              Center(
                child: Transform.scale(
                  scale: .86 + (.14 * logoT),
                  child: Opacity(
                    opacity: math.max(0.0, math.min(1.0, 1 - (exitT * .65))),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _WalletMark(progress: logoT),
                        const SizedBox(height: 28),
                        Opacity(
                          opacity: textT,
                          child: Transform.translate(
                            offset: Offset(0, 14 * (1 - textT)),
                            child: const Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Negos',
                                    style: TextStyle(color: Color(0xFFF7F2E7)),
                                  ),
                                  TextSpan(
                                    text: 'Wallet',
                                    style: TextStyle(color: Color(0xFFB8E66C)),
                                  ),
                                ],
                              ),
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.3,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Opacity(
                          opacity: textT,
                          child: const Text(
                            'Secure. Connect. Transact.',
                            style: TextStyle(
                              color: Color(0xE6F7F2E7),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 2.1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        SizedBox(
                          width: 150,
                          height: 5,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: barT,
                                child: const DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFF9DDC5B),
                                        Color(0xFFC8F58A),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WalletMark extends StatelessWidget {
  final double progress;

  const _WalletMark({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: (1 - progress) * -.035,
      child: Container(
        width: 112,
        height: 112,
        decoration: BoxDecoration(
          color: const Color(0xFFEFF4DE),
          borderRadius: BorderRadius.circular(34),
          boxShadow: const [
            BoxShadow(
              color: Color(0x663DFF73),
              blurRadius: 36,
              spreadRadius: 2,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: CustomPaint(
          painter: _WalletIconPainter(),
        ),
      ),
    );
  }
}

class _WalletIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final green = Paint()..color = const Color(0xFF73B83E);
    final dark = Paint()..color = const Color(0xFF174B2C);

    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * .19,
        size.height * .31,
        size.width * .62,
        size.height * .43,
      ),
      Radius.circular(size.width * .09),
    );
    canvas.drawRRect(body, green);

    final flap = Path()
      ..moveTo(size.width * .27, size.height * .31)
      ..lineTo(size.width * .44, size.height * .18)
      ..quadraticBezierTo(
        size.width * .54,
        size.height * .12,
        size.width * .59,
        size.height * .24,
      )
      ..lineTo(size.width * .61, size.height * .31)
      ..close();
    canvas.drawPath(flap, green);

    final pocket = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * .57,
        size.height * .43,
        size.width * .25,
        size.height * .18,
      ),
      Radius.circular(size.width * .045),
    );
    canvas.drawRRect(pocket, dark);

    canvas.drawCircle(
      Offset(size.width * .68, size.height * .52),
      size.width * .025,
      Paint()..color = const Color(0xFFDDF8A2),
    );

    final leaf = Path()
      ..moveTo(size.width * .25, size.height * .67)
      ..quadraticBezierTo(
        size.width * .23,
        size.height * .49,
        size.width * .43,
        size.height * .43,
      )
      ..quadraticBezierTo(
        size.width * .38,
        size.height * .63,
        size.width * .25,
        size.height * .67,
      )
      ..close();
    canvas.drawPath(leaf, dark);

    final stem = Paint()
      ..color = const Color(0xFFDDF8A2)
      ..strokeWidth = size.width * .025
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * .27, size.height * .64),
      Offset(size.width * .38, size.height * .49),
      stem,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WalletRingPainter extends CustomPainter {
  final double progress;
  final double exit;

  const _WalletRingPainter({
    required this.progress,
    required this.exit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * .43;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = const Color(0xFFB8E66C).withValues(alpha: .92);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      ring,
    );

    if (exit > 0) {
      final maxRadius = size.longestSide * .85;
      final reveal = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 + (exit * 80)
        ..color = const Color(0xFFB8E66C).withValues(alpha: 1 - exit);
      canvas.drawCircle(
        center,
        radius + (maxRadius * exit),
        reveal,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WalletRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.exit != exit;
}
