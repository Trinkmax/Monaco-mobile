import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/core/auth/auth_provider.dart';
import 'package:monaco_mobile/core/auth/biometric_service.dart';
import 'package:monaco_mobile/core/auth/pin_service.dart';
import 'package:monaco_mobile/core/auth/secure_storage.dart';

import '../widgets/onboarding_scaffold.dart';

/// Gate local: hay sesión pero el cliente pidió Face ID / huella para abrir.
/// Al pasar, `completeBiometric()` cambia el estado y el router manda a /home
/// (o a elegir sucursal). Fallback "Usar PIN" → /pin; "Cerrar sesión" abajo.
class BiometricGateScreen extends ConsumerStatefulWidget {
  const BiometricGateScreen({super.key});

  @override
  ConsumerState<BiometricGateScreen> createState() =>
      _BiometricGateScreenState();
}

class _BiometricGateScreenState extends ConsumerState<BiometricGateScreen> {
  BiometricKind _kind = BiometricKind.generic;
  bool _hasPin = false;
  bool _ready = false;
  bool _busy = false;
  bool _autoPrompted = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final kind = await BiometricService.availableKind();
    final hasPin = await PinService.hasPin();
    final bioEnabled = await SecureStorageService.isBiometricEnabled();
    if (!mounted) return;
    // Gate sólo con PIN (biometría apagada): vamos directo al PIN, sin
    // molestar con Face ID/huella que el cliente no activó.
    if (!bioEnabled && hasPin) {
      context.go('/pin');
      return;
    }
    setState(() {
      _kind = kind;
      _hasPin = hasPin;
      _ready = true;
    });
    // Disparamos el prompt solo una vez al entrar; si cancela, queda el botón.
    if (!_autoPrompted) {
      _autoPrompted = true;
      unawaited(
        Future.delayed(const Duration(milliseconds: 450), () {
          if (mounted) _authenticate();
        }),
      );
    }
  }

  @override
  void dispose() {
    BiometricService.stop();
    super.dispose();
  }

  Future<void> _authenticate() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final outcome = await BiometricService.authenticateDetailed(
      reason: 'Desbloqueá Monaco para continuar',
    );
    if (!mounted) return;
    setState(() => _busy = false);

    switch (outcome) {
      case BiometricOutcome.success:
        ref.read(authProvider.notifier).completeBiometric();
        // El router redirige solo (needsBiometric → authenticated/needsBranch).
        return;
      case BiometricOutcome.cancelled:
        // Decisión del usuario: no gritamos.
        return;
      case BiometricOutcome.notAvailable:
      case BiometricOutcome.notEnrolled:
        setState(
          () => _message = _hasPin
              ? 'Este dispositivo no tiene ${_kind.label} configurada. Entrá con tu PIN.'
              : 'Este dispositivo no tiene ${_kind.label} configurada. '
                    'Cerrá sesión y volvé a entrar con tu número.',
        );
      case BiometricOutcome.lockedOut:
        setState(
          () => _message = _hasPin
              ? '${_kind.label} está bloqueada por demasiados intentos. Usá tu PIN.'
              : '${_kind.label} está bloqueada por demasiados intentos. '
                    'Probá de nuevo en un rato.',
        );
      case BiometricOutcome.failed:
        setState(
          () => _message =
              'No pudimos verificar tu identidad. Probá de nuevo${_hasPin ? ' o usá tu PIN' : ''}.',
        );
    }
  }

  Future<void> _logout() async {
    final ok = await showLiquidDialog<bool>(
      context,
      title: '¿Cerrar sesión?',
      message:
          'Vas a tener que volver a ingresar tu número y un código de WhatsApp.',
      icon: Icons.logout_rounded,
      iconColor: MonacoColors.destructive,
      actions: const [
        LiquidDialogAction(label: 'Cancelar', value: false),
        LiquidDialogAction(
          label: 'Cerrar sesión',
          value: true,
          destructive: true,
        ),
      ],
    );
    if (ok != true || !mounted) return;
    await ref.read(authProvider.notifier).logout();
    // El router manda a /welcome al pasar a unauthenticated.
  }

  @override
  Widget build(BuildContext context) {
    final firstName = ref.watch(authProvider.select((s) => s.firstName));
    final kind = _kind;
    final noBio = kind == BiometricKind.none;

    return OnboardingScaffold(
      centered: true,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      topRight: OnboardingLink(
        label: 'Cerrar sesión',
        icon: Icons.logout_rounded,
        onTap: _busy ? null : _logout,
        dense: true,
      ),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          OnboardingCta(
            label: noBio ? 'Usar código del dispositivo' : kind.ctaLabel,
            icon: kind.icon,
            loading: _busy,
            onPressed: _ready ? _authenticate : null,
          ).liquidEnter(index: 3),
          const SizedBox(height: 6),
          OnboardingLink(
            label: _hasPin ? 'Usar PIN' : 'Usar PIN (no configurado)',
            icon: Icons.dialpad_rounded,
            onTap: _hasPin && !_busy ? () => context.push('/pin') : null,
          ).liquidEnter(index: 4),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const MonacoLogo.monogram(width: 54).liquidEnter(index: 0),
          const SizedBox(height: 34),
          _BiometricOrb(icon: kind.icon, busy: _busy).liquidEnter(index: 1),
          const SizedBox(height: 30),
          OnboardingTitle(
            align: TextAlign.center,
            title: firstName.isEmpty ? 'Desbloqueá la app' : 'Hola, $firstName',
            subtitle: noBio
                ? 'Tu cuenta está protegida. Verificá tu identidad para seguir.'
                : 'Tu cuenta está protegida con ${kind.label}. Verificá tu identidad para seguir.',
          ).liquidEnter(index: 2),
          const SizedBox(height: 18),
          AnimatedSize(
            duration: LiquidTokens.swap,
            curve: LiquidTokens.curveSwap,
            child: _message == null
                ? const SizedBox.shrink()
                : OnboardingErrorBox(
                    message: _message!,
                  ).animate().fadeIn(duration: 220.ms),
          ),
        ],
      ),
    );
  }
}

/// Círculo de vidrio con el ícono de la biometría, pulsando suave.
class _BiometricOrb extends StatelessWidget {
  final IconData icon;
  final bool busy;
  const _BiometricOrb({required this.icon, required this.busy});

  @override
  Widget build(BuildContext context) {
    final ring =
        Container(
              width: 164,
              height: 164,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    MonacoColors.monacoGreen.withValues(alpha: 0.28),
                    MonacoColors.monacoGreen.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                  stops: const [0.45, 0.8, 1],
                ),
              ),
            )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scaleXY(
              begin: 0.94,
              end: 1.08,
              duration: 1600.ms,
              curve: Curves.easeInOut,
            );

    final glass = LiquidGlass(
      width: 128,
      height: 128,
      borderRadius: 64,
      padding: EdgeInsets.zero,
      pressable: false,
      tint: MonacoColors.monacoGreen,
      tintOpacity: 0.14,
      blur: LiquidTokens.blurHeavy,
      showVignette: false,
      child: Center(
        child: AnimatedSwitcher(
          duration: LiquidTokens.swap,
          child: busy
              ? const SizedBox(
                  key: ValueKey('busy'),
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    color: Colors.white,
                  ),
                )
              : Icon(icon, key: ValueKey(icon), size: 60, color: Colors.white),
        ),
      ),
    );

    return Stack(alignment: Alignment.center, children: [ring, glass]);
  }
}
