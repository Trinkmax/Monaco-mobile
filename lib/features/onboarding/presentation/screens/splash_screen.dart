import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/core/auth/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final authState = ref.read(authProvider);

    switch (authState.status) {
      case AuthStatus.authenticated:
        context.go('/home');
      case AuthStatus.needsBiometric:
        context.go('/biometric');
      case AuthStatus.unauthenticated:
      case AuthStatus.initial:
        context.go('/welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // --- Logo icon ---
            Icon(
              Icons.content_cut_rounded,
              size: 80,
              color: Colors.white,
            )
                .animate()
                .fadeIn(duration: 600.ms, curve: Curves.easeOut)
                .scale(
                  begin: const Offset(0.6, 0.6),
                  end: const Offset(1.0, 1.0),
                  duration: 600.ms,
                  curve: Curves.easeOut,
                )
                .shimmer(
                  delay: 600.ms,
                  duration: 1200.ms,
                  color: MonacoColors.gold.withOpacity(0.4),
                ),

            const SizedBox(height: 24),

            // --- Brand name ---
            Text(
              'MONACO',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 12,
              ),
            )
                .animate()
                .fadeIn(delay: 300.ms, duration: 600.ms)
                .slideY(begin: 0.2, end: 0, duration: 600.ms),

            const SizedBox(height: 8),

            Text(
              'SMART BARBER',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Colors.white.withOpacity(0.5),
                letterSpacing: 6,
              ),
            )
                .animate()
                .fadeIn(delay: 500.ms, duration: 600.ms),
          ],
        ),
      ),
    );
  }
}
