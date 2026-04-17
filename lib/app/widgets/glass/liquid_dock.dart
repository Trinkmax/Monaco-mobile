import 'package:flutter/material.dart';

import 'liquid_glass.dart';
import 'liquid_tap_effect.dart';
import 'liquid_tokens.dart';

class LiquidDockItem {
  final IconData icon;
  final IconData? selectedIcon;
  final String label;

  const LiquidDockItem({
    required this.icon,
    this.selectedIcon,
    required this.label,
  });
}

/// Bottom navigation flotante estilo iOS 26 — vidrio líquido con margen
/// lateral e inferior respecto al borde.
class LiquidDock extends StatelessWidget {
  final List<LiquidDockItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  const LiquidDock({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: LiquidGlass(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          borderRadius: LiquidTokens.radiusDock,
          blur: LiquidTokens.blurHeavy,
          tintOpacity: 0.12,
          pressable: false,
          showVignette: false,
          shadow: LiquidTokens.dockLift(),
          child: Row(
            children: List.generate(items.length, (i) {
              return Expanded(
                child: _DockSlot(
                  item: items[i],
                  active: i == currentIndex,
                  onTap: () => onSelect(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _DockSlot extends StatelessWidget {
  final LiquidDockItem item;
  final bool active;
  final VoidCallback onTap;

  const _DockSlot({
    required this.item,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidTapEffect(
      onTap: onTap,
      scaleTo: 0.92,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: active
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.18),
                    Colors.white.withOpacity(0.06),
                  ],
                )
              : null,
          border: active
              ? Border.all(color: Colors.white.withOpacity(0.18), width: 0.8)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: active ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              child: Icon(
                active ? (item.selectedIcon ?? item.icon) : item.icon,
                size: 22,
                color: active
                    ? Colors.white
                    : Colors.white.withOpacity(0.55),
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 240),
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active
                    ? Colors.white
                    : Colors.white.withOpacity(0.48),
                letterSpacing: 0.1,
              ),
              child: Text(item.label),
            ),
          ],
        ),
      ),
    );
  }
}
