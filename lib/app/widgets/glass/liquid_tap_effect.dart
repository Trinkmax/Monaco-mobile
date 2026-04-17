import 'package:flutter/material.dart';
import 'liquid_tokens.dart';

/// Wrapper que da a cualquier widget la interacción "squish" de iOS 26 —
/// escala levemente al presionar y vuelve con suavidad al soltar.
class LiquidTapEffect extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double scaleTo;
  final BorderRadius borderRadius;
  final HitTestBehavior behavior;

  const LiquidTapEffect({
    super.key,
    required this.child,
    required this.onTap,
    this.scaleTo = 0.97,
    this.borderRadius = const BorderRadius.all(Radius.circular(22)),
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<LiquidTapEffect> createState() => _LiquidTapEffectState();
}

class _LiquidTapEffectState extends State<LiquidTapEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: LiquidTokens.tapDown,
      reverseDuration: LiquidTokens.tapUp,
    );
    _scale = _buildScale();
  }

  Animation<double> _buildScale() => Tween<double>(
        begin: 1.0,
        end: widget.scaleTo,
      ).animate(CurvedAnimation(
        parent: _ctrl,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeOutCubic,
      ));

  @override
  void didUpdateWidget(LiquidTapEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scaleTo != widget.scaleTo) {
      _scale = _buildScale();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
