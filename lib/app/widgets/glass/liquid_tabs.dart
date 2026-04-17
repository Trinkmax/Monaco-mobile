import 'package:flutter/material.dart';

import 'liquid_glass.dart';
import 'liquid_tap_effect.dart';
import 'liquid_tokens.dart';

/// Tabs tipo pill glass — el estado activo se distingue por brillo y
/// saturación, no por cambiar a un color sólido.
class LiquidSegmentedTabs extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChange;
  final double height;

  const LiquidSegmentedTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChange,
    this.height = 40,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      padding: const EdgeInsets.all(4),
      borderRadius: LiquidTokens.radiusPill,
      pressable: false,
      showVignette: false,
      blur: LiquidTokens.blurSubtle,
      tintOpacity: 0.05,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = constraints.maxWidth / labels.length;
          return SizedBox(
            height: height,
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  left: selectedIndex * segmentWidth,
                  top: 0,
                  bottom: 0,
                  width: segmentWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.24),
                          Colors.white.withOpacity(0.09),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.32),
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.10),
                          blurRadius: 14,
                          spreadRadius: -3,
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: List.generate(labels.length, (i) {
                    final active = i == selectedIndex;
                    return Expanded(
                      child: LiquidTapEffect(
                        onTap: () => onChange(i),
                        scaleTo: 0.96,
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 240),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  active ? FontWeight.w700 : FontWeight.w500,
                              color: active
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.5),
                              letterSpacing: -0.1,
                            ),
                            child: Text(labels[i]),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
