import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'liquid_tokens.dart';

/// Fondo con orbes de color que se desplazan lentamente — le da al blur algo
/// detrás para que el glass "respire" y se note el material.
///
/// Orbes por defecto: verde Monaco + azul profundo + violeta.
class LiquidBackdrop extends StatefulWidget {
  final Widget child;

  /// Opcional — colores custom para los 3 orbes. Null usa la paleta Monaco.
  final List<Color>? orbColors;

  /// Intensidad del tint (0..1). Default 1.0. Bajalo si el glass de arriba
  /// compite demasiado.
  final double intensity;

  const LiquidBackdrop({
    super.key,
    required this.child,
    this.orbColors,
    this.intensity = 1.0,
  });

  @override
  State<LiquidBackdrop> createState() => _LiquidBackdropState();
}

class _LiquidBackdropState extends State<LiquidBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.orbColors ??
        const [
          LiquidTokens.monacoGreen,
          LiquidTokens.orbBlue,
          LiquidTokens.orbViolet,
        ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final t = _ctrl.value;
            return Stack(
              children: [
                const Positioned.fill(child: ColoredBox(color: Colors.black)),
                _orb(
                  palette: palette,
                  index: 0,
                  phase: t,
                  baseX: 0.78, baseY: 0.08,
                  ampX: 0.08, ampY: 0.06,
                  size: 420,
                  w: w, h: h,
                ),
                _orb(
                  palette: palette,
                  index: 1,
                  phase: (t + 0.34) % 1,
                  baseX: -0.12, baseY: 0.42,
                  ampX: 0.10, ampY: 0.08,
                  size: 380,
                  w: w, h: h,
                ),
                _orb(
                  palette: palette,
                  index: 2,
                  phase: (t + 0.66) % 1,
                  baseX: 0.70, baseY: 0.92,
                  ampX: 0.12, ampY: 0.06,
                  size: 340,
                  w: w, h: h,
                ),
                widget.child,
              ],
            );
          },
        );
      },
    );
  }

  Widget _orb({
    required List<Color> palette,
    required int index,
    required double phase,
    required double baseX,
    required double baseY,
    required double ampX,
    required double ampY,
    required double size,
    required double w,
    required double h,
  }) {
    final color = palette[index % palette.length];
    final angle = phase * 2 * math.pi;
    final dx = baseX + ampX * math.sin(angle);
    final dy = baseY + ampY * math.cos(angle + index * 1.2);

    return Positioned(
      left: w * dx - size / 2,
      top: h * dy - size / 2,
      child: IgnorePointer(
        child: SizedBox(
          width: size,
          height: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withOpacity(0.32 * widget.intensity),
                  color.withOpacity(0.10 * widget.intensity),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
