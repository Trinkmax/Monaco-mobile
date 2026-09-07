import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/core/auth/secure_storage.dart';
import 'package:monaco_mobile/core/utils/feedback_confirmacion.dart';
import 'package:monaco_mobile/features/loyalty/data/loyalty_models.dart';
import 'package:monaco_mobile/features/loyalty/presentation/widgets/monaco_card.dart';

/// Festejo de subida de categoría: pantalla completa, la tarjeta cambiando de
/// color (morph del gradiente desde la categoría anterior), partículas y
/// "Llegaste a Cliente Oro".
///
/// Se dispara **una vez por subida**: se guarda en el Keychain el `code` de la
/// última categoría que el cliente vio (`loyalty_last_tier_seen`) y sólo se
/// festeja cuando la actual tiene un `sort` mayor. La primera vez (sin
/// registro) sólo se guarda: enrolar no es subir, y un cliente que entra por
/// primera vez como Platinum ya lo ve en la tarjeta.
class TierUpCelebration {
  TierUpCelebration._();

  static bool _mostrando = false;

  /// Compara la categoría actual con la última vista y, si subió, festeja.
  /// Llamarlo con el árbol montado (post-frame) cada vez que `loyaltyProvider`
  /// trae datos. Nunca tira.
  static Future<void> check(BuildContext context, LoyaltySummary summary) async {
    if (_mostrando) return;
    final tier = summary.programEnabled ? summary.tier : null;
    if (tier == null) return;
    try {
      final visto = await SecureStorageService.getLoyaltyLastTierSeen();
      if (visto == tier.code) return;
      if (visto == null) {
        await SecureStorageService.setLoyaltyLastTierSeen(tier.code);
        return;
      }
      final anterior = summary.tierPorCode(visto);
      await SecureStorageService.setLoyaltyLastTierSeen(tier.code);
      if (anterior == null || tier.sort <= anterior.sort) return;
      if (!context.mounted) return;
      await mostrar(context, summary: summary, desde: anterior, hasta: tier);
    } catch (e) {
      debugPrint('[loyalty] celebración: $e');
    }
  }

  /// Muestra el overlay (público para el banco de pruebas visual).
  static Future<void> mostrar(
    BuildContext context, {
    required LoyaltySummary summary,
    required LoyaltyTier desde,
    required LoyaltyTier hasta,
  }) async {
    if (_mostrando) return;
    _mostrando = true;
    try {
      await showGeneralDialog<void>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        barrierLabel: 'Subiste de categoría',
        barrierColor: Colors.black.withValues(alpha: 0.86),
        transitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (ctx, _, _) => _Celebracion(
          summary: summary,
          desde: desde,
          hasta: hasta,
          onCerrar: () => Navigator.of(ctx).pop(),
        ),
        transitionBuilder: (ctx, anim, _, child) {
          final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
              child: child,
            ),
          );
        },
      );
    } finally {
      _mostrando = false;
    }
  }
}

class _Celebracion extends StatefulWidget {
  final LoyaltySummary summary;
  final LoyaltyTier desde;
  final LoyaltyTier hasta;
  final VoidCallback onCerrar;

  const _Celebracion({
    required this.summary,
    required this.desde,
    required this.hasta,
    required this.onCerrar,
  });

  @override
  State<_Celebracion> createState() => _CelebracionState();
}

class _CelebracionState extends State<_Celebracion> with TickerProviderStateMixin {
  late final AnimationController _morph = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final AnimationController _particulas = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  late final List<_Particula> _puntos;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random(widget.hasta.code.hashCode);
    _puntos = List.generate(40, (_) => _Particula.aleatoria(rnd));
    // El morph arranca cuando el velo ya se ve; el sonido, con el morph.
    Future<void>.delayed(const Duration(milliseconds: 380), () {
      if (!mounted) return;
      _morph.forward();
      _particulas.forward();
      FeedbackConfirmacion.reproducir();
    });
  }

  @override
  void dispose() {
    _morph.dispose();
    _particulas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasta = widget.hasta;
    final desde = widget.desde;
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    top: -120,
                    bottom: -120,
                    left: -40,
                    right: -40,
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _particulas,
                        builder: (context, _) => CustomPaint(
                          painter: _ParticulasPainter(
                            t: Curves.easeOutCubic.transform(_particulas.value),
                            color: hasta.colorSecondary,
                            puntos: _puntos,
                          ),
                        ),
                      ),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _morph,
                    builder: (context, _) {
                      final v = Curves.easeInOutCubic.transform(_morph.value);
                      final tier = hasta.copyWith(
                        colorPrimary: Color.lerp(desde.colorPrimary, hasta.colorPrimary, v),
                        colorSecondary: Color.lerp(desde.colorSecondary, hasta.colorSecondary, v),
                        textColor: Color.lerp(desde.textColor, hasta.textColor, v),
                      );
                      return MonacoCard(
                        summary: widget.summary,
                        saldo: widget.summary.points.balance,
                        tier: tier,
                        conDorso: false,
                        animarContador: false,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 34),
              Text(
                'Llegaste a Cliente ${hasta.name}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: MonacoColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Ahora sumás puntos al ${hasta.multiplierPct} % en cada visita',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 30),
              LiquidButton(
                tint: MonacoColors.seleccion,
                onPressed: widget.onCerrar,
                padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 15),
                child: const Text(
                  'Genial',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Particula {
  final double x; // -1..1 (relativo al centro)
  final double y; // -1..1
  final double vx;
  final double vy;
  final double r;
  final double retraso;

  const _Particula(this.x, this.y, this.vx, this.vy, this.r, this.retraso);

  factory _Particula.aleatoria(math.Random rnd) {
    final ang = rnd.nextDouble() * 2 * math.pi;
    final vel = 0.35 + rnd.nextDouble() * 0.65;
    return _Particula(
      (rnd.nextDouble() - 0.5) * 0.6,
      (rnd.nextDouble() - 0.5) * 0.4,
      math.cos(ang) * vel,
      math.sin(ang) * vel - 0.35,
      2 + rnd.nextDouble() * 3.5,
      rnd.nextDouble() * 0.25,
    );
  }
}

/// 40 puntos del color secundario de la categoría nueva que salen del centro
/// de la tarjeta, suben y se apagan. Sin paquete extra.
class _ParticulasPainter extends CustomPainter {
  final double t;
  final Color color;
  final List<_Particula> puntos;

  const _ParticulasPainter({required this.t, required this.color, required this.puntos});

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in puntos) {
      final lt = ((t - p.retraso) / (1 - p.retraso)).clamp(0.0, 1.0);
      if (lt <= 0) continue;
      final x = cx + (p.x + p.vx * lt) * size.width * 0.5;
      final y = cy + (p.y + p.vy * lt + 0.25 * lt * lt) * size.height * 0.5;
      final alpha = (1 - lt) * 0.95;
      paint.color = color.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), p.r * (1 - lt * 0.4), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticulasPainter old) => old.t != t || old.color != color;
}
