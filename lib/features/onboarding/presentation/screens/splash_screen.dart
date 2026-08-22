import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/core/auth/auth_provider.dart';

import '../widgets/onboarding_scaffold.dart';

/// Pantalla de arranque: monograma con entrada animada mientras el
/// `AuthNotifier` resuelve la sesión. Navega UNA vez según `AuthStatus`
/// (`initial` espera) y tiene un tope de seguridad para no quedar colgada.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  /// Mínimo en pantalla, para que la marca no parpadee si el auth resuelve
  /// al instante.
  static const _minDisplay = Duration(milliseconds: 1100);

  /// Si el auth sigue en `initial` después de esto, mostramos "Reintentar".
  /// (Navegar a /welcome no serviría: el router devuelve a /splash mientras
  /// el estado sea `initial`.)
  static const _safetyTimeout = Duration(seconds: 7);

  bool _minDisplayElapsed = false;
  bool _navigated = false;
  bool _stuck = false;
  Timer? _minTimer;
  Timer? _safetyTimer;

  @override
  void initState() {
    super.initState();
    _armTimers();
  }

  void _armTimers() {
    _minTimer?.cancel();
    _safetyTimer?.cancel();
    _minDisplayElapsed = false;
    _minTimer = Timer(_minDisplay, () {
      if (!mounted) return;
      _minDisplayElapsed = true;
      _maybeNavigate();
    });
    _safetyTimer = Timer(_safetyTimeout, () {
      if (!mounted || _navigated) return;
      debugPrint('[splash] auth sigue en initial después de $_safetyTimeout');
      setState(() => _stuck = true);
    });
  }

  void _maybeNavigate() {
    if (!mounted || _navigated || !_minDisplayElapsed) return;

    final status = ref.read(authProvider).status;
    if (status == AuthStatus.initial) return;

    _navigated = true;
    _safetyTimer?.cancel();

    switch (status) {
      case AuthStatus.authenticated:
        context.go('/home');
      case AuthStatus.needsBiometric:
        context.go('/biometric');
      case AuthStatus.needsBranch:
        context.go('/elegir-sucursal?onboarding=1');
      case AuthStatus.unauthenticated:
      case AuthStatus.initial:
        context.go('/welcome');
    }
  }

  void _retry() {
    setState(() => _stuck = false);
    // Recrea el notifier → vuelve a correr `_init`.
    ref.invalidate(authProvider);
    _armTimers();
  }

  @override
  void dispose() {
    _minTimer?.cancel();
    _safetyTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (_, next) {
      if (next.status != AuthStatus.initial) _maybeNavigate();
    });

    return Scaffold(
      backgroundColor: MonacoColors.background,
      body: LiquidBackdrop(
        orbColors: kOnboardingOrbs,
        intensity: kOnboardingOrbIntensity,
        child: SafeArea(
          child: Stack(
            children: [
              // Precarga de los shaders del dock (ver LiquidGlassWarmup).
              const Positioned(left: 0, top: 0, child: LiquidGlassWarmup()),

              // ── Marca centrada ──
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _GlowingMonogram()
                        .animate()
                        .fadeIn(duration: 520.ms, curve: Curves.easeOut)
                        .scale(
                          begin: const Offset(0.78, 0.78),
                          end: const Offset(1, 1),
                          duration: 760.ms,
                          curve: Curves.easeOutBack,
                        ),
                    const SizedBox(height: 26),
                    const MonacoLogo.wordmark(width: 176)
                        .animate()
                        .fadeIn(delay: 380.ms, duration: 520.ms)
                        .slideY(
                          begin: 0.25,
                          end: 0,
                          delay: 380.ms,
                          duration: 520.ms,
                          curve: Curves.easeOutCubic,
                        ),
                  ],
                ),
              ),

              // ── Pie: indicador / reintento ──
              Positioned(
                left: 0,
                right: 0,
                bottom: 28,
                child: AnimatedSwitcher(
                  duration: LiquidTokens.swap,
                  child: _stuck
                      ? _StuckFooter(onRetry: _retry)
                      : const _LoadingDots(key: ValueKey('dots')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Monograma "M" sobre un halo verde muy tenue.
class _GlowingMonogram extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    MonacoColors.monacoGreen.withValues(alpha: 0.22),
                    MonacoColors.monacoGreen.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                  stops: const [0, 0.5, 1],
                ),
              ),
            )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scaleXY(begin: 0.92, end: 1.06, duration: 2200.ms),
        const MonacoLogo.monogram(width: 116),
      ],
    );
  }
}

class _LoadingDots extends StatelessWidget {
  const _LoadingDots({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        return Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            )
            .animate(onPlay: (c) => c.repeat(), delay: (i * 160).ms)
            .fadeIn(duration: 400.ms)
            .then()
            .fadeOut(duration: 500.ms);
      }),
    ).animate().fadeIn(delay: 900.ms, duration: 400.ms);
  }
}

class _StuckFooter extends StatelessWidget {
  final VoidCallback onRetry;
  const _StuckFooter({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Está tardando más de lo normal',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          LiquidPill(
            onTap: onRetry,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Reintentar',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}
