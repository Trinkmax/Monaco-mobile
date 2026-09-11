import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/features/loyalty/data/loyalty_models.dart';
import 'package:monaco_mobile/features/loyalty/presentation/widgets/card_tilt.dart';

final _pts = NumberFormat.decimalPattern('es_AR');

/// Lo que se dibuja donde va el saldo cuando no se pudo leer. Es una raya de
/// EM (—), no un guión de teclado: en el cuerpo de 44 pt de la tarjeta un `-`
/// se lee como un signo menos.
const String _sinSaldo = '—';

/// El texto del contador para un saldo que puede no existir.
String _textoSaldo(int? saldo, int animado) =>
    saldo == null ? _sinSaldo : _pts.format(animado);

/// **La tarjeta Monaco** — la tarjeta de crédito del cliente.
///
/// Proporción 1.586:1 (tarjeta física), radio 22, ancho completo. Con
/// categoría: gradiente 135° con los colores de `loyalty_tiers` (nunca
/// hardcodeados), banda de brillo que recorre la lámina cada ~6 s y sigue la
/// inclinación del teléfono, chip EMV, wordmark, "CLIENTE ORO", el saldo grande
/// con contador, el nombre en mayúsculas grabado y "MIEMBRO DESDE 2024".
/// Platinum suma un barrido holográfico que gira despacio.
///
/// Sin categoría (programa apagado, RPC caída, cliente sin sesión) se dibuja en
/// **vidrio gris** como el resto de la app —sin chip ni etiqueta—, para que la
/// ausencia del programa no se lea como una tarjeta rota.
///
/// Tocar la pill "Ver progreso" la da vuelta (flip 3D): el dorso tiene la banda
/// magnética, el anillo de visitas y cuánto falta para la siguiente categoría.
///
/// La tipografía **no escala con el texto del sistema**: es un gráfico de
/// proporción fija (como una tarjeta real) y con 1.3× desbordaba a 360 pt. Lo
/// que dice la tarjeta viaja entero en el `Semantics`.
class MonacoCard extends StatefulWidget {
  final LoyaltySummary summary;

  /// Saldo de puntos, o **`null` cuando no se pudo leer**.
  ///
  /// No es lo mismo que cero y la tarjeta no puede confundirlos: con la red
  /// caída o la RPC en error, un `0` le dice al cliente que se quedó sin
  /// puntos —que es exactamente la peor lectura posible de una billetera—.
  /// Con `null` se dibuja un guión, que se lee como "todavía no sabemos".
  final int? saldo;
  final VoidCallback? onTap;

  /// Versión chica para el carrusel de `/categoria`: sin pill de progreso,
  /// sin contador animado y sin arrastre (compite con el PageView).
  final bool compact;

  /// Dibuja la tarjeta con OTRA categoría (el carrusel muestra las cuatro).
  /// `null` = la del cliente.
  final LoyaltyTier? tier;

  /// Anima el número desde 0 (o desde el saldo anterior) en 1100 ms.
  final bool animarContador;

  /// Muestra la pill "Ver progreso" y habilita el flip. Sólo tiene sentido con
  /// categoría y sin `compact`.
  final bool conDorso;

  const MonacoCard({
    super.key,
    required this.summary,
    required this.saldo,
    this.onTap,
    this.compact = false,
    this.tier,
    this.animarContador = true,
    this.conDorso = true,
  });

  /// Proporción de una tarjeta de crédito (85,6 × 53,98 mm).
  static const double proporcion = 1.586;
  static const double radio = 22;

  static double alturaPara(double ancho) => ancho / proporcion;

  @override
  State<MonacoCard> createState() => _MonacoCardState();
}

class _MonacoCardState extends State<MonacoCard>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
    reverseDuration: const Duration(milliseconds: 520),
  );
  late final AnimationController _sheen = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );
  late final AnimationController _holo = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  );
  late final AnimationController _contador = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late Animation<int> _numero;

  Offset _tilt = Offset.zero;
  StreamSubscription<Object?>? _sensorSub;
  bool _conSensor = false;

  LoyaltyTier? get _tier =>
      widget.tier ??
      (widget.summary.programEnabled ? widget.summary.tier : null);

  bool get _esPlatinum => _tier?.code == 'platinum';

  /// El contador anima enteros: sin saldo se lo deja en 0 y las caras dibujan
  /// el guión (no leen `_numero`).
  int get _saldoOCero => widget.saldo ?? 0;

  @override
  void initState() {
    super.initState();
    _numero = IntTween(
      begin: widget.animarContador ? 0 : _saldoOCero,
      end: _saldoOCero,
    ).animate(CurvedAnimation(parent: _contador, curve: Curves.easeOutCubic));
    if (widget.animarContador) {
      _contador.forward();
    } else {
      _contador.value = 1;
    }
    _sheen.repeat();
    if (_esPlatinum) _holo.repeat();
    WidgetsBinding.instance.addObserver(this);
    _escucharSensor();
  }

  /// El acelerómetro se PAUSA con la app en segundo plano.
  ///
  /// `sensors_plus` no mira el ciclo de vida: la suscripción queda registrada
  /// en el sensor nativo mientras el widget viva. En iOS el sistema suspende el
  /// proceso a los pocos segundos y da igual, pero en Android el proceso queda
  /// en cache y el sensor sigue muestreando a ~16 Hz hasta que el freezer lo
  /// pare (Android 14+): en la franja 7–13, que es justo la gama baja del
  /// público, eso se ve en las métricas de batería de Play Vitals. Bloquear el
  /// teléfono con el Home abierto es el gesto más común que hay.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final sub = _sensorSub;
    if (sub == null) return;
    switch (state) {
      case AppLifecycleState.resumed:
        if (sub.isPaused) sub.resume();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        if (!sub.isPaused) sub.pause();
    }
  }

  void _escucharSensor() {
    if (widget.compact) return;
    _sensorSub = CardTilt.escuchar(
      onTilt: (x, y) {
        if (!mounted) return;
        setState(() => _tilt = Offset(x, y));
      },
      onSinSensor: () {
        if (!mounted) return;
        setState(() {
          _conSensor = false;
          _tilt = Offset.zero;
        });
      },
    );
    _conSensor = _sensorSub != null;
  }

  @override
  void didUpdateWidget(covariant MonacoCard old) {
    super.didUpdateWidget(old);
    if (old.saldo != widget.saldo) {
      _numero = IntTween(
        begin: widget.animarContador ? (old.saldo ?? 0) : _saldoOCero,
        end: _saldoOCero,
      ).animate(CurvedAnimation(parent: _contador, curve: Curves.easeOutCubic));
      _contador
        ..reset()
        ..forward();
    }
    final eraPlatinum = (old.tier ?? old.summary.tier)?.code == 'platinum';
    if (_esPlatinum && !_holo.isAnimating) _holo.repeat();
    if (!_esPlatinum && eraPlatinum) _holo.stop();
    if (_tier == null && _flip.value > 0) _flip.value = 0;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sensorSub?.cancel();
    _flip.dispose();
    _sheen.dispose();
    _holo.dispose();
    _contador.dispose();
    super.dispose();
  }

  // ── Arrastre (fallback sin sensor) ───────────────────────────────────────

  void _onDrag(DragUpdateDetails d, double ancho) {
    if (_conSensor || widget.compact) return;
    final nx = (_tilt.dx + d.delta.dx / ancho * 2.2).clamp(-1.0, 1.0);
    setState(() => _tilt = Offset(nx, _tilt.dy));
  }

  void _onDragEnd() {
    if (_conSensor || widget.compact) return;
    setState(() => _tilt = Offset.zero);
  }

  // ── Semántica ────────────────────────────────────────────────────────────

  String _semantica(LoyaltyTier? tier) {
    final s = widget.summary;
    final b = StringBuffer('Tarjeta Monaco. ');
    if (tier != null) b.write('Cliente ${tier.name}. ');
    final saldo = widget.saldo;
    b.write(
      saldo == null
          ? 'Puntos no disponibles por ahora. '
          : '${_pts.format(saldo)} puntos. ',
    );
    if (s.clientName.isNotEmpty) b.write('${s.clientName}. ');
    if (s.memberSinceYear != null) {
      b.write('Miembro desde ${s.memberSinceYear}. ');
    }
    if (tier != null && widget.tier == null) {
      b.write(
        '${s.visitsInWindow} visitas en las últimas ${s.program.windowWeeks} semanas. ',
      );
      final next = s.nextTier;
      if (next != null) {
        b.write('Te faltan ${s.nextTierFaltan} para ${next.name}. ');
      } else {
        b.write('Sos ${tier.name}, la categoría más alta. ');
      }
    }
    if (widget.onTap != null) b.write('Ver detalle.');
    return b.toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    final tier = _tier;
    return AspectRatio(
      aspectRatio: MonacoCard.proporcion,
      child: LayoutBuilder(
        builder: (context, c) {
          final ancho = c.maxWidth.isFinite ? c.maxWidth : 350.0;
          final alto = ancho / MonacoCard.proporcion;
          // Escala tipográfica por ancho: 350 pt (iPhone de 390 menos
          // márgenes) es el 1.0.
          final k = (ancho / 350).clamp(0.8, 1.15);

          Widget cuerpo = tier == null
              ? _CaraApagada(
                  summary: widget.summary,
                  saldo: widget.saldo,
                  numero: _numero,
                  k: k,
                  compact: widget.compact,
                )
              : _construirConCategoria(tier, ancho, alto, k);

          cuerpo = MediaQuery.withNoTextScaling(child: cuerpo);

          if (widget.onTap != null) {
            cuerpo = LiquidTapEffect(
              onTap: widget.onTap!,
              scaleTo: 0.98,
              borderRadius: BorderRadius.circular(MonacoCard.radio),
              child: cuerpo,
            );
          }

          if (!widget.compact && !_conSensor && tier != null) {
            cuerpo = GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: (d) => _onDrag(d, ancho),
              onHorizontalDragEnd: (_) => _onDragEnd(),
              onHorizontalDragCancel: _onDragEnd,
              child: cuerpo,
            );
          }

          return Semantics(
            button: widget.onTap != null,
            label: _semantica(tier),
            child: ExcludeSemantics(child: cuerpo),
          );
        },
      ),
    );
  }

  Widget _construirConCategoria(
    LoyaltyTier tier,
    double ancho,
    double alto,
    double k,
  ) {
    return TweenAnimationBuilder<Offset>(
      tween: Tween<Offset>(end: _tilt),
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      builder: (context, tilt, _) {
        return AnimatedBuilder(
          animation: _flip,
          builder: (context, _) {
            final t = _flip.value;
            final dorso = t > 0.5;
            final m = Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(t * math.pi + tilt.dx * 0.10)
              ..rotateX(-tilt.dy * 0.07);
            final cara = dorso
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: _CaraDorso(
                      summary: widget.summary,
                      tier: tier,
                      tilt: tilt,
                      sheen: _sheen,
                      holo: _holo,
                      k: k,
                      onVolver: () => _flip.reverse(),
                    ),
                  )
                : _CaraFrente(
                    summary: widget.summary,
                    tier: tier,
                    saldo: widget.saldo,
                    numero: _numero,
                    tilt: tilt,
                    sheen: _sheen,
                    holo: _holo,
                    k: k,
                    compact: widget.compact,
                    onVerProgreso:
                        widget.conDorso &&
                            !widget.compact &&
                            widget.tier == null
                        ? () => _flip.forward()
                        : null,
                  );
            return Transform(
              alignment: Alignment.center,
              transform: m,
              child: cara,
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// LÁMINA — gradiente + brillo + holograma + viñeta (compartida por las caras)
// ═══════════════════════════════════════════════════════════════════════════

class _Lamina extends StatelessWidget {
  final LoyaltyTier tier;
  final Offset tilt;
  final Animation<double> sheen;
  final Animation<double> holo;
  final bool oscurecer;
  final Widget child;

  const _Lamina({
    required this.tier,
    required this.tilt,
    required this.sheen,
    required this.holo,
    this.oscurecer = false,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(MonacoCard.radio);
    final esPlatinum = tier.code == 'platinum';
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 28,
            spreadRadius: -8,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: tier.colorSecondary.withValues(alpha: 0.18),
            blurRadius: 30,
            spreadRadius: -12,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Base: 135° primary → secondary, corrido apenas con la inclinación.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(-1 + tilt.dx * 0.35, -1 + tilt.dy * 0.35),
                  end: Alignment(1 + tilt.dx * 0.35, 1 + tilt.dy * 0.35),
                  colors: [tier.colorPrimary, tier.colorSecondary],
                ),
              ),
            ),
            // Textura: luz suave arriba a la izquierda.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.9 + tilt.dx * 0.4, -1.1 + tilt.dy * 0.4),
                  radius: 1.3,
                  colors: [
                    Colors.white.withValues(alpha: 0.16),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
            if (esPlatinum)
              AnimatedBuilder(
                animation: holo,
                builder: (context, _) => DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: SweepGradient(
                      center: Alignment(
                        0.55 + tilt.dx * 0.45,
                        -0.35 + tilt.dy * 0.45,
                      ),
                      transform: GradientRotation(holo.value * 2 * math.pi),
                      colors: [
                        for (final c in const [
                          Color(0xFFFF4D6D),
                          Color(0xFFFFD166),
                          Color(0xFF6EE7B7),
                          Color(0xFF60A5FA),
                          Color(0xFFC084FC),
                          Color(0xFFFF4D6D),
                        ])
                          c.withValues(alpha: 0.14),
                      ],
                    ),
                  ),
                ),
              ),
            // Viñeta abajo a la derecha.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(1.05, 1.15),
                  radius: 1.1,
                  colors: [
                    Colors.black.withValues(alpha: 0.30),
                    Colors.black.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
            if (oscurecer)
              ColoredBox(color: Colors.black.withValues(alpha: 0.22)),
            // Borde fino.
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.22),
                  width: 0.8,
                ),
              ),
            ),
            child,
            // Banda de brillo que recorre la tarjeta cada ~6 s y sigue la mano.
            // Va ENCIMA del contenido (logo, etiqueta, número, nombre): es el
            // reflejo de la luz sobre la tarjeta entera, no un fondo que los
            // textos tapan. Pedido del dueño (30/ago): "el brillo debe recorrer
            // la tarjeta completa, incluyendo el logo y 'Cliente X'".
            //
            // NO se traslada ninguna lámina: la primera versión corría una caja
            // del tamaño de la tarjeta y, a mitad del recorrido, el BORDE de esa
            // caja entraba en la tarjeta y cortaba el brillo en seco (se veía un
            // filo diagonal cerca de "Ver progreso"). Acá la caja siempre cubre
            // la tarjeta entera y lo que se mueve es el gradiente: fuera de la
            // franja es transparente en las dos puntas (TileMode.clamp), así que
            // no hay borde posible. IgnorePointer: los taps pasan al contenido.
            IgnorePointer(
              child: AnimatedBuilder(
                animation: sheen,
                builder: (context, _) {
                  final p = Curves.easeInOut.transform(
                    ((sheen.value - 0.05) / 0.45).clamp(0.0, 1.0),
                  );
                  // Centro de la franja en coordenadas de Alignment (-1..1 es
                  // la tarjeta): arranca fuera por la izquierda y termina fuera
                  // por la derecha; la mano lo corre un poco.
                  final x0 = -2.8 + p * 4.2 + tilt.dx * 0.45;
                  final y0 = tilt.dy * 0.3;
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(x0, -1.0 + y0),
                        end: Alignment(x0 + 1.4, 1.0 + y0),
                        tileMode: TileMode.clamp,
                        colors: [
                          Colors.white.withValues(alpha: 0.0),
                          Colors.white.withValues(alpha: 0.20),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                        stops: const [0.30, 0.5, 0.70],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FRENTE
// ═══════════════════════════════════════════════════════════════════════════

class _CaraFrente extends StatelessWidget {
  final LoyaltySummary summary;
  final LoyaltyTier tier;
  final int? saldo;
  final Animation<int> numero;
  final Offset tilt;
  final Animation<double> sheen;
  final Animation<double> holo;
  final double k;
  final bool compact;
  final VoidCallback? onVerProgreso;

  const _CaraFrente({
    required this.summary,
    required this.tier,
    required this.saldo,
    required this.numero,
    required this.tilt,
    required this.sheen,
    required this.holo,
    required this.k,
    required this.compact,
    required this.onVerProgreso,
  });

  @override
  Widget build(BuildContext context) {
    final color = tier.textColor;
    final pad = (compact ? 16.0 : 18.0) * k;
    final nombre = summary.clientName.trim().toUpperCase();
    final anio = summary.memberSinceYear;

    return _Lamina(
      tier: tier,
      tilt: tilt,
      sheen: sheen,
      holo: holo,
      child: Padding(
        padding: EdgeInsets.all(pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Wordmark(tier: tier, width: (compact ? 84 : 96) * k),
                SizedBox(width: 10 * k),
                // `Expanded` y no `Spacer` + `Column`: el dashboard admite
                // nombres de categoría de hasta 40 caracteres y la etiqueta
                // sin límite de ancho desbordaba la tarjeta (150 px a 390 pt).
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _EtiquetaCategoria(tier: tier, k: k),
                      if (onVerProgreso != null) ...[
                        SizedBox(height: 7 * k),
                        _PillTarjeta(
                          label: 'Ver progreso',
                          icon: Icons.donut_large_rounded,
                          color: color,
                          k: k,
                          onTap: onVerProgreso!,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: (compact ? 8 : 10) * k),
            _ChipEmv(k: compact ? k * 0.9 : k),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: AnimatedBuilder(
                animation: numero,
                builder: (context, _) => Text(
                  _textoSaldo(saldo, numero.value),
                  style: TextStyle(
                    color: color,
                    fontSize: (compact ? 36 : 44) * k,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                    letterSpacing: -1.5 * k,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            SizedBox(height: 2 * k),
            Text(
              'PUNTOS',
              style: TextStyle(
                color: color.withValues(alpha: 0.78),
                fontSize: 10 * k,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.4 * k,
                height: 1.1,
              ),
            ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    nombre.isEmpty ? 'CLIENTE MONACO' : nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: (compact ? 12 : 13) * k,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4 * k,
                      height: 1.1,
                      shadows: [
                        Shadow(
                          color: Colors.white.withValues(alpha: 0.25),
                          offset: const Offset(0, 1),
                        ),
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          offset: const Offset(0, -1),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 10 * k),
                Text(
                  anio == null ? 'MIEMBRO MONACO' : 'MIEMBRO DESDE $anio',
                  style: TextStyle(
                    color: color.withValues(alpha: 0.85),
                    fontSize: 9.5 * k,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2 * k,
                    height: 1.1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// El PNG del wordmark es blanco: sobre un texto oscuro (oro) se tiñe al color
/// de texto de la categoría.
class _Wordmark extends StatelessWidget {
  final LoyaltyTier tier;
  final double width;
  const _Wordmark({required this.tier, required this.width});

  @override
  Widget build(BuildContext context) {
    final logo = MonacoLogo.wordmark(width: width);
    if (!tier.textoOscuro) return logo;
    return ColorFiltered(
      colorFilter: ColorFilter.mode(tier.textColor, BlendMode.srcIn),
      child: logo,
    );
  }
}

class _EtiquetaCategoria extends StatelessWidget {
  final LoyaltyTier tier;
  final double k;
  const _EtiquetaCategoria({required this.tier, required this.k});

  @override
  Widget build(BuildContext context) {
    final color = tier.textColor;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6 * k,
          height: 6 * k,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6 * k),
            ],
          ),
        ),
        SizedBox(width: 6 * k),
        Flexible(
          child: Text(
            'CLIENTE ${tier.name.toUpperCase()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 10 * k,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.2 * k,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }
}

/// Pill chica dentro de la tarjeta ("Ver progreso", "Volver"): vidrio del color
/// de texto de la categoría, sin blur (ya está sobre un gradiente).
class _PillTarjeta extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final double k;
  final VoidCallback onTap;

  const _PillTarjeta({
    required this.label,
    required this.icon,
    required this.color,
    required this.k,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: LiquidTapEffect(
        onTap: onTap,
        scaleTo: 0.92,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 9 * k, vertical: 5 * k),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: color.withValues(alpha: 0.14),
            border: Border.all(
              color: color.withValues(alpha: 0.38),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 11 * k, color: color),
              SizedBox(width: 5 * k),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10.5 * k,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.1,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chip EMV: rectángulo dorado 34×26 con radio 6 y las líneas de contacto. Es lo
/// que hace que la lámina "parezca una tarjeta real".
class _ChipEmv extends StatelessWidget {
  final double k;
  const _ChipEmv({required this.k});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(34 * k, 26 * k),
      painter: const _ChipEmvPainter(),
    );
  }
}

class _ChipEmvPainter extends CustomPainter {
  const _ChipEmvPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Rect.fromLTWH(0, 0, w, h);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(h * 0.23));

    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE8C46A), Color(0xFFB8892B)],
        ).createShader(rect),
    );

    final linea = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.7, h * 0.035)
      ..color = const Color(0xFF6B4A12).withValues(alpha: 0.55);

    // Dos horizontales que cruzan todo el chip.
    canvas.drawLine(Offset(0, h * 0.34), Offset(w, h * 0.34), linea);
    canvas.drawLine(Offset(0, h * 0.66), Offset(w, h * 0.66), linea);
    // Dos verticales sólo en la banda del medio (los contactos).
    canvas.drawLine(
      Offset(w * 0.34, h * 0.34),
      Offset(w * 0.34, h * 0.66),
      linea,
    );
    canvas.drawLine(
      Offset(w * 0.66, h * 0.34),
      Offset(w * 0.66, h * 0.66),
      linea,
    );
    // Verticales cortas arriba y abajo, apenas corridas.
    canvas.drawLine(Offset(w * 0.4, 0), Offset(w * 0.4, h * 0.34), linea);
    canvas.drawLine(Offset(w * 0.6, h * 0.66), Offset(w * 0.6, h), linea);
    // Cuadradito central.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w / 2, h / 2),
          width: w * 0.22,
          height: h * 0.24,
        ),
        Radius.circular(h * 0.06),
      ),
      linea,
    );

    // Reflejo arriba a la izquierda.
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.55),
            Colors.white.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: 0.25),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _ChipEmvPainter old) => false;
}

// ═══════════════════════════════════════════════════════════════════════════
// DORSO — banda magnética, anillo de visitas, cuánto falta
// ═══════════════════════════════════════════════════════════════════════════

class _CaraDorso extends StatelessWidget {
  final LoyaltySummary summary;
  final LoyaltyTier tier;
  final Offset tilt;
  final Animation<double> sheen;
  final Animation<double> holo;
  final double k;
  final VoidCallback onVolver;

  const _CaraDorso({
    required this.summary,
    required this.tier,
    required this.tilt,
    required this.sheen,
    required this.holo,
    required this.k,
    required this.onVolver,
  });

  static String _fecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final color = tier.textColor;
    final next = summary.nextTier;
    final visitas = summary.visitsInWindow;
    final semanas = summary.program.windowWeeks;
    final expiry = summary.points.nextExpiryAt;
    final expiryPts = summary.points.nextExpiryPoints;
    final pad = 18.0 * k;
    final bandaTop = 16.0 * k;
    final bandaAlto = 28.0 * k;

    final lineaVisitas = visitas == 1
        ? '1 visita en las últimas $semanas semanas'
        : '$visitas visitas en las últimas $semanas semanas';
    final String lineaSiguiente;
    if (next == null) {
      lineaSiguiente = 'Sos ${tier.name}, la categoría más alta';
    } else {
      final f = summary.nextTierFaltan;
      lineaSiguiente = f == 1
          ? 'Te falta 1 para ${next.name}'
          : 'Te faltan $f para ${next.name}';
    }

    return _Lamina(
      tier: tier,
      tilt: tilt,
      sheen: sheen,
      holo: holo,
      oscurecer: true,
      child: Stack(
        children: [
          // Banda magnética.
          Positioned(
            top: bandaTop,
            left: 0,
            right: 0,
            height: bandaAlto,
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.58)),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              pad,
              bandaTop + bandaAlto + 10 * k,
              pad,
              pad,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _AnilloVisitas(
                      progreso: summary.progresoHaciaSiguiente,
                      visitas: visitas,
                      meta: next?.minVisits,
                      color: color,
                      size: 58 * k,
                    ),
                    SizedBox(width: 14 * k),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            lineaVisitas,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: color,
                              fontSize: 12.5 * k,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                              letterSpacing: -0.1,
                            ),
                          ),
                          SizedBox(height: 3 * k),
                          Text(
                            lineaSiguiente,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: color.withValues(alpha: 0.86),
                              fontSize: 11.5 * k,
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                            ),
                          ),
                          if (expiry != null && expiryPts > 0) ...[
                            SizedBox(height: 3 * k),
                            Row(
                              children: [
                                Icon(
                                  Icons.hourglass_bottom_rounded,
                                  size: 11 * k,
                                  color: color.withValues(alpha: 0.8),
                                ),
                                SizedBox(width: 4 * k),
                                Flexible(
                                  child: Text(
                                    '${_pts.format(expiryPts)} pts vencen el ${_fecha(expiry)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: color.withValues(alpha: 0.8),
                                      fontSize: 10.5 * k,
                                      fontWeight: FontWeight.w600,
                                      height: 1.2,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'CLIENTE ${tier.name.toUpperCase()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color.withValues(alpha: 0.7),
                          fontSize: 9.5 * k,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2 * k,
                        ),
                      ),
                    ),
                    SizedBox(width: 8 * k),
                    _PillTarjeta(
                      label: 'Volver',
                      icon: Icons.flip_rounded,
                      color: color,
                      k: k,
                      onTap: onVolver,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Anillo de progreso visitas / meta de la siguiente categoría.
class _AnilloVisitas extends StatelessWidget {
  final double progreso;
  final int visitas;
  final int? meta;
  final Color color;
  final double size;

  const _AnilloVisitas({
    required this.progreso,
    required this.visitas,
    required this.meta,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: progreso.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => CustomPaint(
          painter: _AnilloPainter(progreso: v, color: color),
          child: Center(
            child: Text(
              meta == null ? '$visitas' : '$visitas/$meta',
              style: TextStyle(
                color: color,
                fontSize: size * 0.24,
                fontWeight: FontWeight.w900,
                height: 1,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnilloPainter extends CustomPainter {
  final double progreso;
  final Color color;
  const _AnilloPainter({required this.progreso, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.11;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = color.withValues(alpha: 0.2),
    );
    if (progreso > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * progreso,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AnilloPainter old) =>
      old.progreso != progreso || old.color != color;
}

// ═══════════════════════════════════════════════════════════════════════════
// APAGADA — vidrio gris (sin programa / sin categoría)
// ═══════════════════════════════════════════════════════════════════════════

class _CaraApagada extends StatelessWidget {
  final LoyaltySummary summary;
  final int? saldo;
  final Animation<int> numero;
  final double k;
  final bool compact;

  const _CaraApagada({
    required this.summary,
    required this.saldo,
    required this.numero,
    required this.k,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final nombre = summary.clientName.trim().toUpperCase();
    final anio = summary.memberSinceYear;
    final pad = (compact ? 16.0 : 18.0) * k;

    return LiquidGlass(
      padding: EdgeInsets.all(pad),
      borderRadius: MonacoCard.radio,
      tintOpacity: 0.09,
      pressable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MonacoLogo.wordmark(width: (compact ? 84 : 96) * k),
              const Spacer(),
              Text(
                'TUS PUNTOS',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 10 * k,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.2 * k,
                  height: 1.1,
                ),
              ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AnimatedBuilder(
              animation: numero,
              builder: (context, _) => Text(
                _textoSaldo(saldo, numero.value),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: (compact ? 36 : 44) * k,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  letterSpacing: -1.5 * k,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          SizedBox(height: 2 * k),
          Text(
            'PUNTOS',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 10 * k,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.4 * k,
              height: 1.1,
            ),
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  nombre.isEmpty ? 'CLIENTE MONACO' : nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: (compact ? 12 : 13) * k,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4 * k,
                    height: 1.1,
                    shadows: [
                      Shadow(
                        color: Colors.white.withValues(alpha: 0.18),
                        offset: const Offset(0, 1),
                      ),
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        offset: const Offset(0, -1),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 10 * k),
              Text(
                anio == null ? 'MIEMBRO MONACO' : 'MIEMBRO DESDE $anio',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 9.5 * k,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2 * k,
                  height: 1.1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
