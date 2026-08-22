import 'package:flutter/material.dart';

import '../../theme/monaco_colors.dart';
import 'liquid_glass.dart';
import 'liquid_pill.dart';
import 'liquid_tokens.dart';

/// Acción de un [showLiquidDialog]. `primary` pinta el botón verde; `destructive`
/// rojo; si ninguno, pastilla neutra.
class LiquidDialogAction<T> {
  final String label;
  final T? value;
  final bool primary;
  final bool destructive;
  final IconData? icon;

  const LiquidDialogAction({
    required this.label,
    this.value,
    this.primary = false,
    this.destructive = false,
    this.icon,
  });
}

/// Diálogo de vidrio centrado, reemplazo del `AlertDialog` de Material.
/// Devuelve el `value` de la acción elegida (o null si se cerró tocando afuera).
Future<T?> showLiquidDialog<T>(
  BuildContext context, {
  required String title,
  String? message,
  Widget? content,
  IconData? icon,
  Color? iconColor,
  List<LiquidDialogAction<T>> actions = const [],
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: barrierDismissible,
    barrierColor: Colors.black.withValues(alpha: 0.66),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: LiquidGlass(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        borderRadius: LiquidTokens.radiusGroup,
        pressable: false,
        tintOpacity: 0.10,
        blur: LiquidTokens.blurHeavy,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          (iconColor ?? Colors.white).withValues(alpha: 0.24),
                          (iconColor ?? Colors.white).withValues(alpha: 0.08),
                        ],
                      ),
                      border: Border.all(
                        color: (iconColor ?? Colors.white).withValues(alpha: 0.32),
                        width: 0.8,
                      ),
                    ),
                    child: Icon(icon, size: 20, color: iconColor ?? Colors.white),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: MonacoColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      letterSpacing: -0.3,
                      height: 1.15,
                    ),
                  ),
                ),
              ],
            ),
            if (message != null) ...[
              const SizedBox(height: 10),
              Text(
                message,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
            if (content != null) ...[
              const SizedBox(height: 14),
              content,
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(
                      child: _ActionButton<T>(
                        action: actions[i],
                        onTap: () => Navigator.of(ctx).pop(actions[i].value),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _ActionButton<T> extends StatelessWidget {
  final LiquidDialogAction<T> action;
  final VoidCallback onTap;
  const _ActionButton({required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = action.destructive
        ? MonacoColors.destructive
        : action.primary
            ? MonacoColors.monacoGreen
            : Colors.white;
    final label = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (action.icon != null) ...[
          Icon(action.icon, size: 16, color: action.primary ? Colors.white : color),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            action.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: action.primary ? Colors.white : color,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
    if (action.primary) {
      return LiquidButton(
        onPressed: onTap,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: label,
      );
    }
    return LiquidPill(
      onTap: onTap,
      tint: action.destructive ? MonacoColors.destructive : null,
      tintOpacity: action.destructive ? 0.16 : 0.10,
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: Center(child: label),
    );
  }
}
