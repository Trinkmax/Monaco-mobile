import 'package:flutter/material.dart';

import '../../theme/monaco_colors.dart';
import 'liquid_tap_effect.dart';
import 'liquid_tokens.dart';

/// Chip seleccionable del lenguaje Liquid Glass (horarios, días, servicios,
/// filtros). El estado seleccionado se distingue por un relleno claro y brillo
/// (`MonacoColors.seleccion`); `disabled` baja la opacidad y no responde.
class LiquidChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;
  final Widget? leading;
  final Widget? trailing;
  final Color? tint;
  final EdgeInsets padding;
  final double radius;
  final double fontSize;
  final bool expand;

  const LiquidChip({
    super.key,
    required this.label,
    this.selected = false,
    this.disabled = false,
    this.onTap,
    this.leading,
    this.trailing,
    this.tint,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    this.radius = 14,
    this.fontSize = 14,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = tint ?? MonacoColors.seleccion;
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 7)],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : Colors.white.withValues(alpha: disabled ? 0.35 : 0.9),
              fontSize: fontSize,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              letterSpacing: -0.1,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 7), trailing!],
      ],
    );

    final box = AnimatedContainer(
      duration: LiquidTokens.swap,
      curve: LiquidTokens.curveSwap,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: selected
              ? [
                  accent.withValues(alpha: 0.55),
                  accent.withValues(alpha: 0.28),
                ]
              : [
                  Colors.white.withValues(alpha: disabled ? 0.03 : 0.09),
                  Colors.white.withValues(alpha: disabled ? 0.015 : 0.035),
                ],
        ),
        border: Border.all(
          color: selected
              ? accent.withValues(alpha: 0.9)
              : Colors.white.withValues(alpha: disabled ? 0.07 : 0.16),
          width: selected ? 1.1 : 0.8,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.35),
                  blurRadius: 16,
                  spreadRadius: -4,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: content,
    );

    if (onTap == null || disabled) {
      return Opacity(opacity: disabled ? 0.6 : 1, child: box);
    }
    return LiquidTapEffect(
      onTap: onTap!,
      scaleTo: 0.95,
      borderRadius: BorderRadius.circular(radius),
      child: box,
    );
  }
}
