import 'package:flutter/material.dart' hide AnimatedBuilder;
import 'package:flutter/material.dart' as m show AnimatedBuilder;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';

final _pts = NumberFormat.decimalPattern('es_AR');

/// La tarjeta de la billetera: **vidrio gris**, como el resto de la app.
///
/// Se probó en blanco sólido (era lo que mostraba el mockup) y el dueño la
/// rechazó: la lámina clara rompe el lenguaje Liquid Glass y hace que el Home
/// parezca de otra app. La jerarquía la sostienen el tamaño del número y el
/// único elemento claro de la tarjeta —el botón de regalo—, no el fondo.
///
/// De la versión wallet queda lo que sí aportaba: número grande arriba, un
/// destino propio para ir a gastar los puntos, y la línea de progreso hacia el
/// próximo premio real del catálogo.
class WalletPointsCard extends StatefulWidget {
  final int saldo;

  /// Línea de progreso. `null` = no mostrar barra (ver [pie]).
  final double? progreso;

  /// "A 1.760 pts de Café" / "Podés canjear 2 premios" / "Sumás puntos en cada
  /// visita". Nunca se inventa: sale del catálogo real.
  final String pie;

  final VoidCallback onTap;
  final VoidCallback onPremios;

  const WalletPointsCard({
    super.key,
    required this.saldo,
    required this.progreso,
    required this.pie,
    required this.onTap,
    required this.onPremios,
  });

  @override
  State<WalletPointsCard> createState() => _WalletPointsCardState();
}

class _WalletPointsCardState extends State<WalletPointsCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<int> _contador;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _contador = IntTween(begin: 0, end: widget.saldo).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant WalletPointsCard old) {
    super.didUpdateWidget(old);
    if (old.saldo != widget.saldo) {
      _contador = IntTween(begin: old.saldo, end: widget.saldo).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
      );
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Tenés ${widget.saldo} puntos. ${widget.pie}. Ver detalle',
      child: LiquidGlass(
        onTap: widget.onTap,
        borderRadius: 26,
        padding: const EdgeInsets.fromLTRB(22, 20, 18, 20),
        tintOpacity: 0.09,
        scalePressed: 0.98,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Tus puntos',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  m.AnimatedBuilder(
                    animation: _contador,
                    builder: (context, _) => Text(
                      _pts.format(_contador.value),
                      style: const TextStyle(
                        color: MonacoColors.textPrimary,
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                        letterSpacing: -2,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.pie,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                      letterSpacing: -0.1,
                    ),
                  ),
                  if (widget.progreso != null) ...[
                    const SizedBox(height: 12),
                    _BarraProgreso(valor: widget.progreso!),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            _BotonRegalo(onTap: widget.onPremios),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .slideY(begin: 0.08, end: 0, duration: 500.ms);
  }
}

/// Barra de progreso blanca sobre el vidrio. Blanca y no verde: el verde de
/// marca ya lo usan el CTA de reservar y las pastillas de estado, y sobre una
/// lámina gris a 6 px de alto se lee como un rayón de color.
class _BarraProgreso extends StatelessWidget {
  final double valor;
  const _BarraProgreso({required this.valor});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 6,
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: Colors.white.withValues(alpha: 0.10)),
            ),
            FractionallySizedBox(
              // Con 0 % la barra desaparece y parece que falta un elemento; un
              // hilo mínimo comunica "todavía no arrancaste". El piso es 0.055
              // y **el relleno no lleva radio propio**: con 6 px de alto y
              // `borderRadius: 999`, un 3 % se renderizaba como un punto suelto.
              // El redondeo lo pone el ClipRRect de afuera.
              widthFactor: valor.clamp(0.055, 1.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.95),
                      Colors.white.withValues(alpha: 0.62),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botón circular con el regalo → Premios. Es el **único elemento claro** de la
/// tarjeta: en una lámina de vidrio gris, lo sólido es lo que el ojo encuentra
/// primero, y acá eso tiene que ser la acción de gastar los puntos. Es un
/// destino propio: tocar el número lleva al detalle, tocar el regalo a la
/// tienda.
class _BotonRegalo extends StatelessWidget {
  final VoidCallback onTap;
  const _BotonRegalo({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Ver premios para canjear',
      child: LiquidTapEffect(
        onTap: onTap,
        scaleTo: 0.9,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 16,
                spreadRadius: -3,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.card_giftcard_rounded,
            color: MonacoColors.background,
            size: 25,
          ),
        ),
      ),
    );
  }
}
