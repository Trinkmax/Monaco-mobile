import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/utils/feedback_confirmacion.dart';

/// Velo verde a pantalla completa que confirma la reserva: un círculo que
/// crece con `Transform.scale` desde donde estaba el botón, dos anillos que
/// pulsan, el tilde que se dibuja y "¡Turno confirmado!". Se desvanece solo
/// y avisa con `onDone`.
///
/// Es el único lugar de la app con un verde FIJO (no el de marca): "confirmado"
/// es un código que el cliente ya trae aprendido. El círculo se dimensiona
/// para que a escala 1 APENAS cubra la pantalla: más grande y el barrido se
/// completa en el primer tramo y se lee como un flash.
class ConfirmacionVerde extends StatefulWidget {
  /// Centro del botón que confirmó, en coordenadas globales. Si es `null`
  /// arranca del 50 % / 62 % de la pantalla.
  final Offset? origin;
  final VoidCallback onDone;

  const ConfirmacionVerde({super.key, this.origin, required this.onDone});

  @override
  State<ConfirmacionVerde> createState() => _ConfirmacionVerdeState();
}

class _ConfirmacionVerdeState extends State<ConfirmacionVerde>
    with SingleTickerProviderStateMixin {
  static const _total = Duration(milliseconds: 2400);

  late final AnimationController _ctrl = AnimationController(vsync: this, duration: _total);

  late final Animation<double> _circle = CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(0.0, 620 / 2400, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _ring1 = CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(300 / 2400, 1300 / 2400, curve: Curves.easeOut),
  );
  late final Animation<double> _ring2 = CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(520 / 2400, 1520 / 2400, curve: Curves.easeOut),
  );
  late final Animation<double> _ringDraw = CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(380 / 2400, 900 / 2400, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _tilde = CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(560 / 2400, 980 / 2400, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _texto = CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(620 / 2400, 1000 / 2400, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _salida = CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(1900 / 2400, 2360 / 2400, curve: Curves.easeIn),
  );

  bool _done = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed && !_done) {
        _done = true;
        widget.onDone();
      }
    });
    _ctrl.forward();

    // Sonido "ta-da" + háptica media justo cuando el círculo ya cubrió y el
    // anillo empieza a dibujarse (380 ms); remate háptico suave al terminar el
    // tilde (980 ms). Es el mismo gesto que hacen las apps de pedidos: el
    // sonido acompaña al tilde, no al botón.
    Future<void>.delayed(const Duration(milliseconds: 380), () {
      if (mounted) FeedbackConfirmacion.reproducir();
    });
    Future<void>.delayed(const Duration(milliseconds: 980), () {
      if (mounted) FeedbackConfirmacion.remate();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: 'Tu turno quedó confirmado',
      liveRegion: true,
      child: AbsorbPointer(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            final origin = widget.origin ?? Offset(w * 0.5, h * 0.62);
            final ox = origin.dx.clamp(0.0, w);
            final oy = origin.dy.clamp(0.0, h);
            // Distancia a la esquina más lejana → diámetro que apenas cubre.
            final far = [
              Offset(0, 0),
              Offset(w, 0),
              Offset(0, h),
              Offset(w, h),
            ].map((c) => (c - Offset(ox, oy)).distance).reduce(math.max);
            final diameter = far * 2 * 1.02;

            return AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) {
                final scale = reduce ? 1.0 : _circle.value;
                final opacity = 1.0 - _salida.value;
                return Opacity(
                  opacity: opacity,
                  child: Stack(
                    children: [
                      Positioned(
                        left: ox - diameter / 2,
                        top: oy - diameter / 2,
                        width: diameter,
                        height: diameter,
                        child: Transform.scale(
                          scale: scale,
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Color(0xFF1AA14C),
                                  Color(0xFF15803D),
                                  Color(0xFF0F6A33),
                                ],
                                stops: [0.0, 0.55, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 150,
                              height: 150,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  _Anillo(progress: reduce ? 1 : _ring1.value),
                                  _Anillo(progress: reduce ? 1 : _ring2.value),
                                  CustomPaint(
                                    size: const Size(104, 104),
                                    painter: TildePainter(
                                      ringProgress: reduce ? 1 : _ringDraw.value,
                                      progress: reduce ? 1 : _tilde.value,
                                      color: Colors.white,
                                      strokeWidth: 6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            Opacity(
                              opacity: reduce ? 1 : _texto.value,
                              child: Transform.translate(
                                offset: Offset(0, reduce ? 0 : (1 - _texto.value) * 10),
                                child: const Text(
                                  '¡Turno confirmado!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.8,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _Anillo extends StatelessWidget {
  final double progress;
  const _Anillo({required this.progress});

  @override
  Widget build(BuildContext context) {
    final scale = 0.7 + progress * 0.9;
    final opacity = (1 - progress) * 0.55;
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: opacity), width: 2),
        ),
      ),
    );
  }
}

/// Dibuja un anillo (arco que se completa) y un tilde que se traza según
/// `progress`. Reutilizado en la pantalla de confirmación (en verde sobre
/// vidrio) y en el velo (en blanco).
class TildePainter extends CustomPainter {
  final double ringProgress;
  final double progress;
  final Color color;
  final double strokeWidth;
  final Color? ringColor;

  const TildePainter({
    required this.ringProgress,
    required this.progress,
    required this.color,
    this.strokeWidth = 5,
    this.ringColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - strokeWidth;
    if (ringProgress > 0) {
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 0.6
        ..strokeCap = StrokeCap.round
        ..color = (ringColor ?? color).withValues(alpha: 0.9);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * ringProgress.clamp(0.0, 1.0),
        false,
        ringPaint,
      );
    }

    if (progress <= 0) return;
    final w = size.width;
    final h = size.height;
    final path = ui.Path()
      ..moveTo(w * 0.30, h * 0.52)
      ..lineTo(w * 0.44, h * 0.66)
      ..lineTo(w * 0.71, h * 0.37);
    for (final metric in path.computeMetrics()) {
      final partial = metric.extractPath(0, metric.length * progress.clamp(0.0, 1.0));
      canvas.drawPath(partial, paint);
    }
  }

  @override
  bool shouldRepaint(covariant TildePainter old) =>
      old.progress != progress ||
      old.ringProgress != ringProgress ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}
