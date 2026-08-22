import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';

import 'shake.dart';

/// Puntos del PIN: se llenan en verde con un pequeño pop y tiemblan en rojo
/// cuando [shakeKey] cambia (error).
class PinDots extends StatelessWidget {
  final int length;
  final int filled;
  final bool error;

  /// Cambiar la key dispara la animación de shake.
  final Object? shakeKey;

  const PinDots({
    super.key,
    required this.length,
    required this.filled,
    this.error = false,
    this.shakeKey,
  });

  @override
  Widget build(BuildContext context) {
    final accent = error ? MonacoColors.destructive : MonacoColors.monacoGreen;
    final row = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (i) {
        final on = i < filled;
        // El "pop" (easeOutBack, que se pasa de 1) va en un AnimatedScale
        // aparte: si la misma curva interpola la decoración, al volver de
        // "con sombra" a "sin sombra" el overshoot deja un blurRadius
        // negativo y `BoxShadow` tira en debug.
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11),
          child: AnimatedScale(
            scale: on ? 1.12 : 1,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutBack,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: on
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [accent, accent.withValues(alpha: 0.7)],
                      )
                    : null,
                color: on ? null : Colors.white.withValues(alpha: 0.07),
                border: Border.all(
                  color: on
                      ? accent.withValues(alpha: 0.9)
                      : Colors.white.withValues(alpha: 0.22),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: on ? 0.45 : 0),
                    blurRadius: on ? 12 : 0,
                    spreadRadius: on ? -1 : 0,
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
    return ShakeOnChange(trigger: shakeKey, amount: 6, child: row);
  }
}

/// Teclado numérico de vidrio (3x4). Cada tecla mide ≥ 64 px, muy por encima
/// del mínimo táctil. `onBiometric` agrega el ícono abajo a la izquierda;
/// si es null, esa celda queda vacía.
class PinPad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final VoidCallback? onBiometric;
  final IconData biometricIcon;
  final bool enabled;

  const PinPad({
    super.key,
    required this.onDigit,
    required this.onDelete,
    this.onBiometric,
    this.biometricIcon = Icons.fingerprint_rounded,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget key(Widget child, VoidCallback? onTap, {String? semantics}) {
      return Padding(
        padding: const EdgeInsets.all(6),
        child: Semantics(
          button: true,
          label: semantics,
          child: _PadKey(onTap: enabled ? onTap : null, child: child),
        ),
      );
    }

    Widget digit(String d, {String? letters}) {
      return key(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              d,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                height: 1,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            if (letters != null)
              Text(
                letters,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.38),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                  height: 1.2,
                ),
              ),
          ],
        ),
        () {
          HapticFeedback.lightImpact();
          onDigit(d);
        },
        semantics: d,
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.35,
        children: [
          digit('1'),
          digit('2', letters: 'ABC'),
          digit('3', letters: 'DEF'),
          digit('4', letters: 'GHI'),
          digit('5', letters: 'JKL'),
          digit('6', letters: 'MNO'),
          digit('7', letters: 'PQRS'),
          digit('8', letters: 'TUV'),
          digit('9', letters: 'WXYZ'),
          onBiometric != null
              ? key(
                  Icon(
                    biometricIcon,
                    size: 28,
                    color: MonacoColors.monacoGreen,
                  ),
                  () {
                    HapticFeedback.selectionClick();
                    onBiometric!();
                  },
                  semantics: 'Usar biometría',
                )
              : const SizedBox.shrink(),
          digit('0'),
          key(
            Icon(
              Icons.backspace_outlined,
              size: 24,
              color: Colors.white.withValues(alpha: 0.85),
            ),
            () {
              HapticFeedback.selectionClick();
              onDelete();
            },
            semantics: 'Borrar',
          ),
        ],
      ),
    );
  }
}

class _PadKey extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _PadKey({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final box = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0.035),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
          width: 0.8,
        ),
      ),
      child: Center(child: child),
    );
    if (onTap == null) return Opacity(opacity: 0.5, child: box);
    return LiquidTapEffect(
      onTap: onTap!,
      scaleTo: 0.92,
      borderRadius: BorderRadius.circular(20),
      child: box,
    );
  }
}
