import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/core/auth/pin_service.dart';
import 'package:monaco_mobile/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:monaco_mobile/features/onboarding/presentation/widgets/pin_pad.dart';

/// Alta / cambio del PIN local en dos pasos (elegir → confirmar). Guarda el
/// hash en el dispositivo y prende el gate. Devuelve `true` al `pop` si quedó
/// configurado, `false` si se quitó.
class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  int _step = 0; // 0 = elegir, 1 = confirmar
  String _first = '';
  String _input = '';
  bool _error = false;
  bool _busy = false;
  bool _hadPin = false;
  int _shakeSeed = 0;

  @override
  void initState() {
    super.initState();
    PinService.hasPin().then((v) {
      if (mounted) setState(() => _hadPin = v);
    });
  }

  void _onDigit(String d) {
    if (_busy || _input.length >= PinService.length) return;
    setState(() {
      _input += d;
      _error = false;
    });
    if (_input.length == PinService.length) _advance();
  }

  void _onDelete() {
    if (_busy || _input.isEmpty) return;
    setState(() {
      _input = _input.substring(0, _input.length - 1);
      _error = false;
    });
  }

  Future<void> _advance() async {
    if (_step == 0) {
      if (_isWeak(_input)) {
        HapticFeedback.heavyImpact();
        setState(() {
          _error = true;
          _shakeSeed++;
        });
        await Future.delayed(const Duration(milliseconds: 420));
        if (!mounted) return;
        setState(() {
          _input = '';
          _error = false;
        });
        showLiquidToast(
          context,
          'Elegí un PIN menos obvio (evitá 1234 o cuatro iguales).',
          tone: LiquidToastTone.info,
        );
        return;
      }
      HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 180));
      if (!mounted) return;
      setState(() {
        _first = _input;
        _input = '';
        _step = 1;
      });
      return;
    }

    // Paso 2: confirmar.
    if (_input != _first) {
      HapticFeedback.heavyImpact();
      setState(() {
        _error = true;
        _shakeSeed++;
      });
      await Future.delayed(const Duration(milliseconds: 420));
      if (!mounted) return;
      setState(() {
        _input = '';
        _first = '';
        _step = 0;
        _error = false;
      });
      showLiquidToast(
        context,
        'Los PIN no coinciden. Empezá de nuevo.',
        tone: LiquidToastTone.error,
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await PinService.setPin(_input);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      showLiquidToast(
        context,
        _hadPin ? 'PIN actualizado' : 'PIN activado',
        tone: LiquidToastTone.success,
        icon: Icons.lock_rounded,
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _input = '';
        _first = '';
        _step = 0;
      });
      showLiquidToast(
        context,
        'No pudimos guardar el PIN. Probá de nuevo.',
        tone: LiquidToastTone.error,
      );
    }
  }

  /// 1234 / 0000 / 1111… no protegen nada.
  static bool _isWeak(String pin) {
    if (RegExp(r'^(\d)\1+$').hasMatch(pin)) return true;
    const seqs = [
      '0123',
      '1234',
      '2345',
      '3456',
      '4567',
      '5678',
      '6789',
      '9876',
      '8765',
      '7654',
      '6543',
      '5432',
      '4321',
      '3210',
    ];
    return seqs.contains(pin);
  }

  Future<void> _remove() async {
    final ok = await showLiquidDialog<bool>(
      context,
      title: '¿Quitar el PIN?',
      message: 'La app va a dejar de pedirlo como respaldo de la biometría.',
      icon: Icons.lock_open_rounded,
      iconColor: MonacoColors.warning,
      actions: const [
        LiquidDialogAction(label: 'Cancelar', value: false),
        LiquidDialogAction(label: 'Quitar PIN', value: true, destructive: true),
      ],
    );
    if (ok != true || !mounted) return;
    await PinService.removePin();
    if (!mounted) return;
    showLiquidToast(context, 'PIN quitado', tone: LiquidToastTone.neutral);
    context.pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final confirming = _step == 1;
    final title = confirming
        ? 'Confirmá tu PIN'
        : (_hadPin ? 'Elegí tu nuevo PIN' : 'Elegí un PIN');
    final subtitle = confirming
        ? 'Repetilo para estar seguros.'
        : 'Cuatro dígitos. Es el respaldo cuando la biometría no está disponible.';

    return OnboardingScaffold(
      orbs: false,
      showBack: true,
      onBack: () => context.pop(),
      centered: true,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      topRight: _hadPin
          ? OnboardingLink(
              label: 'Quitar PIN',
              icon: Icons.lock_open_rounded,
              color: MonacoColors.destructive.withValues(alpha: 0.9),
              onTap: _busy ? null : _remove,
              dense: true,
            )
          : null,
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PinPad(
            enabled: !_busy,
            onDigit: _onDigit,
            onDelete: _onDelete,
          ).liquidEnter(index: 2),
          const SizedBox(height: 4),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepBar(step: _step).liquidEnter(index: 0),
          const SizedBox(height: 22),
          AnimatedSwitcher(
            duration: LiquidTokens.swap,
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.08, 0),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: OnboardingTitle(
              key: ValueKey(_step),
              align: TextAlign.center,
              title: title,
              subtitle: subtitle,
            ),
          ),
          const SizedBox(height: 34),
          PinDots(
            length: PinService.length,
            filled: _input.length,
            error: _error,
            shakeKey: _shakeSeed,
          ),
          const SizedBox(height: 12),
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

/// Dos segmentos: "elegir" y "confirmar".
class _StepBar extends StatelessWidget {
  final int step;
  const _StepBar({required this.step});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(2, (i) {
            final on = i <= step;
            return AnimatedContainer(
              duration: LiquidTokens.swap,
              curve: LiquidTokens.curveSwap,
              width: 44,
              height: 5,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: on
                    ? MonacoColors.monacoGreen
                    : Colors.white.withValues(alpha: 0.14),
                boxShadow: on
                    ? [
                        BoxShadow(
                          color: MonacoColors.monacoGreen.withValues(
                            alpha: 0.4,
                          ),
                          blurRadius: 10,
                          spreadRadius: -2,
                        ),
                      ]
                    : null,
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        Text(
          'Paso ${step + 1} de 2',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
