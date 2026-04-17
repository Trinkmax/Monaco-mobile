import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'liquid_tokens.dart';

/// Helpers de entrada staggered — fade + slide desde abajo, 220-260ms,
/// curva easeOutCubic. Uso típico dentro de `ListView.builder`:
///
/// ```dart
/// _Card(...).liquidEnter(index: i);
/// ```
extension LiquidEnterX on Widget {
  Widget liquidEnter({
    int index = 0,
    double stagger = 60,
    double slide = 0.08,
    Duration? duration,
  }) {
    final d = duration ?? LiquidTokens.enter;
    return animate(delay: Duration(milliseconds: (index * stagger).round()))
        .fadeIn(duration: d, curve: LiquidTokens.curveEnter)
        .slideY(
          begin: slide,
          end: 0,
          duration: d,
          curve: LiquidTokens.curveEnter,
        );
  }
}
