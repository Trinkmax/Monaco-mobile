import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Placeholder de carga: caja translúcida con shimmer. Usar en vez de
/// `CircularProgressIndicator` en listas y tarjetas.
class LiquidSkeleton extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  final EdgeInsetsGeometry? margin;

  const LiquidSkeleton({
    super.key,
    this.width,
    this.height = 120,
    this.radius = 22,
    this.margin,
  });

  /// Línea de texto simulada.
  const LiquidSkeleton.line({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 7,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1400.ms, color: Colors.white10);
  }
}

/// Lista vertical de esqueletos, para pantallas que cargan una lista.
class LiquidSkeletonList extends StatelessWidget {
  final int count;
  final double itemHeight;
  final EdgeInsets padding;
  final double gap;

  const LiquidSkeletonList({
    super.key,
    this.count = 3,
    this.itemHeight = 120,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 120),
    this.gap = 12,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      itemCount: count,
      separatorBuilder: (_, _) => SizedBox(height: gap),
      itemBuilder: (_, _) => LiquidSkeleton(height: itemHeight),
    );
  }
}
