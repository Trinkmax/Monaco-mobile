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
      backgroundColor: MonacoColors.background,
      body: Center(
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            //  R    G    B    A   offset
               0,   0,   0,   0,  255,  // R → siempre blanco
               0,   0,   0,   0,  255,  // G → siempre blanco
               0,   0,   0,   0,  255,  // B → siempre blanco
              -1,   0,   0,   1,    0,  // A = A_in - R_in (blanco→0, negro→255)
          ]),
          child: Image.asset(
            'assets/images/bos_icon.png',
            width: 220,
          ),
        )
            .animate()
            .fadeIn(duration: 600.ms, curve: Curves.easeOut)
            .scale(
              begin: const Offset(0.7, 0.7),
              end: const Offset(1.0, 1.0),
              duration: 600.ms,
              curve: Curves.easeOut,
            ),
      ),
    );
  }
}
