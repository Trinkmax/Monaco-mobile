import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Sacude horizontalmente al hijo cada vez que cambia [trigger], SIN
/// remontarlo (a diferencia de `.animate(key: …)`, que recrea el subárbol y
/// le hace perder el foco a un campo de texto). Útil para "código incorrecto".
class ShakeOnChange extends StatefulWidget {
  final Widget child;
  final Object? trigger;
  final double amount;
  final double hz;
  final Duration duration;

  const ShakeOnChange({
    super.key,
    required this.child,
    required this.trigger,
    this.amount = 7,
    this.hz = 5,
    this.duration = const Duration(milliseconds: 420),
  });

  @override
  State<ShakeOnChange> createState() => _ShakeOnChangeState();
}

class _ShakeOnChangeState extends State<ShakeOnChange>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void didUpdateWidget(ShakeOnChange old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger && widget.trigger != null) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      child: widget.child,
      builder: (context, child) {
        final t = _ctrl.value;
        // Seno amortiguado: arranca fuerte y se apaga.
        final dx =
            math.sin(t * math.pi * 2 * widget.hz) * widget.amount * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );
  }
}
