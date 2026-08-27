import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/core/auth/auth_provider.dart';
import 'package:monaco_mobile/core/auth/biometric_service.dart';
import 'package:monaco_mobile/core/auth/pin_service.dart';
import 'package:monaco_mobile/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:monaco_mobile/features/onboarding/presentation/widgets/pin_pad.dart';

/// Gate por PIN local (fallback de la biometría). Verifica contra el hash del
/// dispositivo; a los 5 fallos ofrece cerrar sesión.
class PinVerifyScreen extends ConsumerStatefulWidget {
  const PinVerifyScreen({super.key});

  @override
  ConsumerState<PinVerifyScreen> createState() => _PinVerifyScreenState();
}

class _PinVerifyScreenState extends ConsumerState<PinVerifyScreen> {
  static const _maxFails = 5;

  String _input = '';
  int _fails = 0;
  int _shakeSeed = 0;
  bool _error = false;
  bool _busy = false;
  bool? _hasPin;
  BiometricKind _bioKind = BiometricKind.none;
  bool _bioEnabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final hasPin = await PinService.hasPin();
    final kind = await BiometricService.availableKind();
    final status = ref.read(authProvider).status;
    if (!mounted) return;
    setState(() {
      _hasPin = hasPin;
      _bioKind = kind;
      // Sólo ofrecemos volver a la biometría si estamos en el gate (no si
      // alguien llegó acá con la sesión ya abierta).
      _bioEnabled =
          kind != BiometricKind.none && status == AuthStatus.needsBiometric;
    });
  }

  void _onDigit(String d) {
    if (_busy || _input.length >= PinService.length) return;
    setState(() {
      _input += d;
      _error = false;
    });
    if (_input.length == PinService.length) _verify();
  }

  void _onDelete() {
    if (_busy || _input.isEmpty) return;
    setState(() {
      _input = _input.substring(0, _input.length - 1);
      _error = false;
    });
  }

  Future<void> _verify() async {
    setState(() => _busy = true);
    final ok = await PinService.verifyPin(_input);
    if (!mounted) return;

    if (ok) {
      HapticFeedback.mediumImpact();
      ref.read(authProvider.notifier).completeBiometric();
      // El router redirige (needsBiometric → authenticated).
      setState(() => _busy = false);
      return;
    }

    HapticFeedback.heavyImpact();
    setState(() {
      _fails++;
      _error = true;
      _shakeSeed++;
      _busy = false;
    });
    // Dejamos ver los puntos en rojo un instante antes de vaciar.
    await Future.delayed(const Duration(milliseconds: 380));
    if (!mounted) return;
    setState(() => _input = '');

    if (_fails >= _maxFails) _offerLogout();
  }

  Future<void> _offerLogout() async {
    final choice = await showLiquidDialog<String>(
      context,
      title: 'Demasiados intentos',
      message: _bioEnabled
          ? 'Podés volver a probar con ${_bioKind.label}, seguir intentando el PIN o cerrar sesión y entrar de nuevo con tu número.'
          : 'Podés seguir intentando o cerrar sesión y entrar de nuevo con tu número y un código de WhatsApp.',
      icon: Icons.lock_clock_rounded,
      iconColor: MonacoColors.warning,
      barrierDismissible: false,
      actions: [
        if (_bioEnabled)
          LiquidDialogAction(label: _bioKind.ctaLabel, value: 'bio'),
        const LiquidDialogAction(label: 'Seguir', value: 'retry'),
        const LiquidDialogAction(
          label: 'Cerrar sesión',
          value: 'logout',
          destructive: true,
        ),
      ],
    );
    if (!mounted) return;
    switch (choice) {
      case 'logout':
        await ref.read(authProvider.notifier).logout();
      case 'bio':
        _goBiometric();
      default:
        break;
    }
  }

  void _goBiometric() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/biometric');
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
    if (ok == true && mounted) {
      await ref.read(authProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstName = ref.watch(authProvider.select((s) => s.firstName));
    final hasPin = _hasPin;

    if (hasPin == false) {
      return OnboardingScaffold(
        showBack: _bioEnabled,
        onBack: _goBiometric,
        centered: true,
        footer: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_bioEnabled)
              OnboardingCta(
                label: _bioKind.ctaLabel,
                icon: _bioKind.icon,
                onPressed: _goBiometric,
              ),
            const SizedBox(height: 6),
            OnboardingLink(
              label: 'Cerrar sesión',
              icon: Icons.logout_rounded,
              onTap: _logout,
            ),
          ],
        ),
        child: const LiquidEmptyState(
          scrollable: false,
          icon: Icons.dialpad_rounded,
          title: 'No tenés un PIN',
          message:
              'El PIN se configura desde Perfil con la sesión abierta. Mientras tanto, entrá con biometría.',
        ),
      );
    }

    final attemptsLeft = _maxFails - _fails;
    final hint = _error
        ? (attemptsLeft > 0 && attemptsLeft <= 2
              ? 'PIN incorrecto. Te ${attemptsLeft == 1 ? 'queda 1 intento' : 'quedan $attemptsLeft intentos'}.'
              : 'PIN incorrecto')
        : 'Ingresá tu PIN de ${PinService.length} dígitos';

    return OnboardingScaffold(
      showBack: _bioEnabled,
      onBack: _goBiometric,
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
          PinPad(
            enabled: hasPin != null && !_busy,
            onDigit: _onDigit,
            onDelete: _onDelete,
            onBiometric: _bioEnabled ? _goBiometric : null,
            biometricIcon: _bioKind.icon,
          ).liquidEnter(index: 2),
          const SizedBox(height: 4),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MonacoLogo.monogram(width: 50).liquidEnter(index: 0),
          const SizedBox(height: 26),
          OnboardingTitle(
            align: TextAlign.center,
            title: firstName.isEmpty ? 'Tu PIN' : 'Hola, $firstName',
            subtitle: null,
          ).liquidEnter(index: 1),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: LiquidTokens.swap,
            child: Text(
              hint,
              key: ValueKey(hint),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _error
                    ? MonacoColors.destructive
                    : Colors.white.withValues(alpha: 0.55),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 30),
          PinDots(
            length: PinService.length,
            filled: _input.length,
            error: _error,
            shakeKey: _shakeSeed,
          ),
          const SizedBox(height: 10),
          AnimatedOpacity(
            duration: LiquidTokens.swap,
            opacity: _busy ? 1 : 0,
            child: const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          ).animate().fadeIn(),
        ],
      ),
    );
  }
}
