import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Badge de estado tipo "Ocupación media", "Sin espera", "Abierto"...
///
/// El color del nivel se ve a través del vidrio como tint, pero el punto
/// LED del dot es sólido y brillante, como un pixel encendido.
class LiquidStatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool pulse;
  final bool compact;

  const LiquidStatusPill({
    super.key,
    required this.label,
    required this.color,
    this.pulse = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final hPadding = compact ? 8.0 : 10.0;
    final vPadding = compact ? 3.0 : 5.0;
    final fontSize = compact ? 10.5 : 11.5;
    final dotSize = compact ? 6.5 : 7.0;

    Widget dot = Container(
      width: dotSize,
      height: dotSize,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.7),
            blurRadius: 6,
            spreadRadius: 0.5,
          ),
        ],
      ),
    );
    if (pulse) {
      dot = dot
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(begin: 1.0, end: 1.3, duration: 1000.ms);
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: vPadding),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.22),
            color.withOpacity(0.10),
          ],
        ),
        border: Border.all(color: color.withOpacity(0.35), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          dot,
          SizedBox(width: compact ? 6 : 7),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
