import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Canvas oscuro sobre el que apoyan las láminas glass.
///
/// Por defecto: solo un fondo negro neutro sin brillos. Si querés darle vida
/// con orbes de color, pasá `orbColors: [...]` explícitamente — cada color
/// genera un orbe que se desplaza suavemente (un orbe por color, hasta 3).
class LiquidBackdrop extends StatefulWidget {
  final Widget child;

  /// Opcional — colores de los orbes. Si es null o está vacío, no se renderiza
  /// ningún orbe (solo fondo negro limpio).
  final List<Color>? orbColors;

  /// Intensidad del tint de los orbes cuando hay (0..1).
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
  AnimationController? _ctrl;

  @override
  void initState() {
    super.initState();
    if (_hasOrbs) _startAnimation();
  }

  bool get _hasOrbs =>
      widget.orbColors != null && widget.orbColors!.isNotEmpty;

  void _startAnimation() {
    _ctrl ??= AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();
  }

  @override
  void didUpdateWidget(LiquidBackdrop old) {
    super.didUpdateWidget(old);
    if (_hasOrbs && _ctrl == null) {
      _startAnimation();
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasOrbs) {
      return Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Colors.black)),
          widget.child,
        ],
      );
    }

    final palette = widget.orbColors!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        return AnimatedBuilder(
          animation: _ctrl!,
          builder: (context, _) {
            final t = _ctrl!.value;
            return Stack(
              children: [
                const Positioned.fill(child: ColoredBox(color: Colors.black)),
                for (var i = 0; i < palette.length && i < 3; i++)
                  _orb(
                    palette: palette,
                    index: i,
                    phase: (t + i * 0.33) % 1,
                    baseX: [0.78, -0.12, 0.70][i],
                    baseY: [0.08, 0.42, 0.92][i],
                    ampX: [0.08, 0.10, 0.12][i],
                    ampY: [0.06, 0.08, 0.06][i],
                    size: [420.0, 380.0, 340.0][i],
                    w: w,
                    h: h,
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
                  color.withOpacity(0.28 * widget.intensity),
                  color.withOpacity(0.09 * widget.intensity),
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
