import 'dart:async';
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
  // Tiempo mínimo que queremos mostrar el splash (para que no parpadee
  // si el auth resuelve al instante).
  static const _minDisplay = Duration(milliseconds: 1200);
  // Fallback si el auth se cuelga — evita splash eterno.
  static const _safetyTimeout = Duration(seconds: 6);

  bool _minDisplayElapsed = false;
  bool _navigated = false;
  Timer? _safetyTimer;

  @override
  void initState() {
    super.initState();

    Future.delayed(_minDisplay, () {
      if (!mounted) return;
      _minDisplayElapsed = true;
      _maybeNavigate();
    });

    _safetyTimer = Timer(_safetyTimeout, () {
      if (!mounted || _navigated) return;
      debugPrint('[splash] safety timeout — forcing /welcome');
      _navigated = true;
      context.go('/welcome');
    });
  }

  void _maybeNavigate() {
    if (!mounted || _navigated || !_minDisplayElapsed) return;

    final authState = ref.read(authProvider);
    if (authState.status == AuthStatus.initial) return;

    _navigated = true;
    _safetyTimer?.cancel();

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
  void dispose() {
    _safetyTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Escuchar cambios del auth para navegar apenas deje de ser initial
    // (por si el mínimo de display ya pasó).
    ref.listen<AuthState>(authProvider, (_, next) {
      if (next.status != AuthStatus.initial) _maybeNavigate();
    });

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
