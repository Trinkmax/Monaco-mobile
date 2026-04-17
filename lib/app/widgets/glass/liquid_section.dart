import 'package:flutter/material.dart';

import '../../theme/monaco_colors.dart';
import 'liquid_glass.dart';
import 'liquid_tap_effect.dart';
import 'liquid_tokens.dart';

/// Bloque glass que agrupa list tiles con divisores casi imperceptibles.
/// Pensado para secciones tipo "Seguridad", "Preferencias", "Historial"
/// en la pantalla de perfil.
class LiquidSectionCard extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const LiquidSectionCard({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.symmetric(vertical: 4),
    this.borderRadius = LiquidTokens.radiusGroup,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) {
        rows.add(_Divider());
      }
    }
    return LiquidGlass(
      padding: padding,
      borderRadius: borderRadius,
      pressable: false,
      showVignette: false,
      child: Column(children: rows),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.5,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: Colors.white.withOpacity(0.06),
    );
  }
}

/// List tile glass con icon-en-mini-glass, título, subtítulo opcional,
/// trailing (default: chevron).
class LiquidListTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const LiquidListTile({
    super.key,
    required this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? Colors.white;
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          _MiniGlassIcon(icon: icon, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: MonacoColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else if (onTap != null)
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withOpacity(0.3),
              size: 22,
            ),
        ],
      ),
    );

    if (onTap == null) return row;
    return LiquidTapEffect(onTap: onTap!, scaleTo: 0.98, child: row);
  }
}

class _MiniGlassIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _MiniGlassIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.24),
            color.withOpacity(0.10),
          ],
        ),
        border: Border.all(color: color.withOpacity(0.32), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 8,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

/// Switch glass custom — sustituye al Material SwitchListTile.
class LiquidSwitchTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const LiquidSwitchTile({
    super.key,
    required this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidListTile(
      icon: icon,
      iconColor: iconColor,
      title: title,
      subtitle: subtitle,
      onTap: () => onChanged(!value),
      trailing: LiquidSwitch(value: value, onChanged: onChanged),
    );
  }
}

/// Switch glass standalone.
class LiquidSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const LiquidSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        width: 46,
        height: 28,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: value
                ? [
                    LiquidTokens.monacoGreen.withOpacity(0.95),
                    LiquidTokens.monacoGreenDeep.withOpacity(0.75),
                  ]
                : [
                    Colors.white.withOpacity(0.10),
                    Colors.white.withOpacity(0.04),
                  ],
          ),
          border: Border.all(
            color: value
                ? LiquidTokens.monacoGreen.withOpacity(0.55)
                : Colors.white.withOpacity(0.14),
            width: 0.8,
          ),
          boxShadow: value
              ? [
                  BoxShadow(
                    color: LiquidTokens.monacoGreen.withOpacity(0.38),
                    blurRadius: 12,
                    spreadRadius: -3,
                  ),
                ]
              : null,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFFFFF), Color(0xFFE6E6E6)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.32),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
