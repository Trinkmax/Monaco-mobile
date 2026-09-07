import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/features/rewards/data/premio_item.dart';

final _pts = NumberFormat.decimalPattern('es_AR');

/// Tarjeta de premio de la grilla de 2 columnas: lámina de imagen arriba con la
/// pastilla de precio encima, y abajo nombre + categoría + puntos.
///
/// Sirve igual para el catálogo de la barbería (cuesta puntos) y para un
/// convenio (dice **GRATIS**): la diferencia la trae el [PremioItem], no el
/// widget.
class PremioCard extends StatelessWidget {
  final PremioItem premio;
  final int saldo;
  final VoidCallback onTap;

  /// Ancho fijo para el carrusel del Home; `null` = ocupa la celda de la grilla.
  final double? width;

  const PremioCard({
    super.key,
    required this.premio,
    required this.saldo,
    required this.onTap,
    this.width,
  });

  /// Alto que necesita la tarjeta para un ancho dado, sin desbordar.
  ///
  /// Lo usan el carrusel del Home (alto fijo) y la grilla de Premios
  /// (`childAspectRatio`). Está acá y no duplicado en cada pantalla porque la
  /// relación entre la lámina, el nombre de dos líneas y la barra de canje es
  /// del widget, no de quien lo dibuja.
  /// Alto que necesita la tarjeta para un ancho dado, sin desbordar.
  ///
  /// `ancho / 1.5` es la lámina; el resto es la suma EXACTA del bloque de
  /// texto, que tiene alturas fijas justamente para que esta cuenta cierre.
  static double altoPara(double ancho) => ancho / 1.5 + _altoTexto;

  // Piezas del bloque inferior. Cambiar una sin cambiar la suma es lo que hacía
  // desbordar la tarjeta 7–15 px según el ancho.
  static const double _lhNombre = 1.2;
  static const double _altoNombre = 14 * _lhNombre * 2; // dos líneas
  static const double _lhSubtitulo = 1.25;
  static const double _altoSubtitulo = 11.5 * _lhSubtitulo;
  static const double _altoBarra = 7 + 7 + 12.5 * 1.2 + 1.6; // padding+texto+borde
  /// Colchón medido, no calculado: la suma nominal de las piezas se queda
  /// ~16 px corta porque las métricas reales de Poppins (ascent/descent) y el
  /// ícono del chevron no coinciden con `fontSize × height`. Verificado con
  /// `test/widget/wallet_widgets_test.dart`, que renderiza la tarjeta con la
  /// fuente real en las dos medidas que usa la app.
  static const double _colchon = 18;
  static const double _altoTexto =
      10 + _altoNombre + 3 + _altoSubtitulo + 10 + _altoBarra + 12 + _colchon;

  /// `childAspectRatio` para un `SliverGridDelegateWithFixedCrossAxisCount`.
  static double aspectoGrilla(double anchoCelda) =>
      anchoCelda / altoPara(anchoCelda);

  @override
  Widget build(BuildContext context) {
    final alcanza = premio.alcanza(saldo);
    final agotado = premio.agotado;
    final bloqueado = premio.lockedByTier;
    final disponible = premio.puedeCanjear(saldo);

    return Semantics(
      button: true,
      label: _semantica(),
      child: Opacity(
        // Bloqueado por categoría se atenúa más que "te faltan puntos": lo
        // segundo se resuelve viniendo; lo primero, subiendo de categoría.
        opacity: disponible ? 1 : (bloqueado ? 0.62 : 0.74),
        child: LiquidGlass(
          onTap: onTap,
          width: width,
          padding: EdgeInsets.zero,
          borderRadius: 22,
          // El tinte dice QUÉ ES (categoría), no si le alcanza: eso lo dice la
          // pastilla de precio. Con el verde en las dos cosas, la grilla entera
          // quedaba del mismo color.
          tint: premio.categoria.acento,
          tintOpacity: disponible ? 0.07 : 0.04,
          showVignette: false,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  // La lámina se lleva ~2/3 del ancho de alto; el resto es para
                  // nombre (hasta 2 líneas), subtítulo y la barra de canje.
                  // Va junto con `PremioCard.altoPara()`: si cambia uno, cambia
                  // el otro o la tarjeta desborda.
                  aspectRatio: 1.5,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _Lamina(premio: premio, apagado: !disponible),
                      const _SombraInferior(),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: _PrecioPill(premio: premio, destacado: disponible),
                      ),
                      if (agotado)
                        const Positioned(
                          top: 10,
                          right: 10,
                          child: LiquidStatusPill(
                            label: 'AGOTADO',
                            color: MonacoColors.occupancyClosed,
                            pulse: false,
                            compact: true,
                          ),
                        )
                      else if (bloqueado || !alcanza)
                        const Positioned(top: 10, right: 10, child: _CandadoChico()),
                      // La pill "Solo Oro" va ABAJO a la izquierda, sobre la
                      // sombra de la lámina, y no al lado del precio: "Solo
                      // Platinum" + "2.000 pts" no entran juntos en los 168 px
                      // de la celda y se pisaban.
                      if (bloqueado)
                        Positioned(
                          left: 10,
                          bottom: 10,
                          child: _PillSoloTier(nombre: premio.tierRequiredName),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // El bloque de texto va en un Flexible: si el nombre del
                        // premio o el alto de la tarjeta cambian, lo que cede es
                        // el texto (una línea menos), NO la tarjeta con la barra
                        // amarilla de overflow. La pastilla de canje nunca se
                        // recorta: es lo accionable.
                        // Altura FIJA de dos líneas, no Flexible. Con Flexible
                        // el Text de dos líneas recibía menos alto del que pide
                        // y Flutter lo recortaba a media línea (la segunda línea
                        // del nombre quedaba pisada por el subtítulo); sin
                        // Flexible pedía su alto natural y desbordaba. Fijo, el
                        // layout es determinista: `altoPara()` cierra la cuenta
                        // y todas las barras de canje de la grilla quedan
                        // alineadas aunque los nombres midan distinto.
                        SizedBox(
                          height: _altoNombre,
                          child: Text(
                            premio.nombre,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: MonacoColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                              height: _lhNombre,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        SizedBox(
                          height: _altoSubtitulo,
                          child: Text(
                            premio.subtitulo ?? premio.categoria.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              height: _lhSubtitulo,
                            ),
                          ),
                        ),
                        const Spacer(),
                        _Pie(premio: premio, saldo: saldo),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _semantica() {
    if (premio.lockedByTier) {
      final t = premio.tierRequiredName;
      return t == null
          ? '${premio.nombre}, exclusivo por categoría'
          : '${premio.nombre}, exclusivo para clientes $t';
    }
    if (premio.agotado) return '${premio.nombre}, agotado';
    if (premio.esGratis) return '${premio.nombre}, beneficio gratis';
    if (premio.alcanza(saldo)) {
      return '${premio.nombre}, ${premio.puntos} puntos, te alcanza';
    }
    return '${premio.nombre}, te faltan ${premio.faltan(saldo)} puntos';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PIE — la línea que cambia según el estado
// ═══════════════════════════════════════════════════════════════════════════

class _Pie extends StatelessWidget {
  final PremioItem premio;
  final int saldo;
  const _Pie({required this.premio, required this.saldo});

  @override
  Widget build(BuildContext context) {
    if (premio.lockedByTier) {
      // Lo accionable no es cuánto cuesta: es qué categoría lo destraba.
      final t = premio.tierRequiredName;
      return Text(
        t == null ? 'Exclusivo por categoría' : 'Subí a $t para canjearlo',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.55),
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    if (premio.agotado) {
      return Text(
        'Sin stock por ahora',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    if (premio.alcanza(saldo)) {
      // Una sola barra de ancho completo. La versión anterior era pastilla +
      // Spacer + "Canjear" + chevron y **desbordaba 6,6 px** en la tarjeta de
      // 162 del carrusel (verificado en el simulador): tres elementos de ancho
      // fijo en 138 px útiles no entran, y encima la pastilla "Te alcanza"
      // repetía lo que ya dice la pastilla verde del precio.
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          color: Colors.white.withValues(alpha: 0.13),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 0.8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                premio.esGratis ? 'Activar' : 'Canjear',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.1,
                  height: 1.2,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 15, color: Colors.white),
          ],
        ),
      );
    }

    // Falta saldo: el dato accionable es cuánto falta, no cuánto cuesta.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Te faltan ${_pts.format(premio.faltan(saldo))} pts',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.62),
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        _Barra(value: premio.progreso(saldo)),
      ],
    );
  }
}

class _Barra extends StatelessWidget {
  final double value;
  const _Barra({required this.value});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 4,
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: Colors.white.withValues(alpha: 0.08)),
            ),
            FractionallySizedBox(
              widthFactor: value,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.7),
                      Colors.white.withValues(alpha: 0.4),
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

// ═══════════════════════════════════════════════════════════════════════════
// LÁMINA — foto del premio, o el fallback (que hoy es el caso normal)
// ═══════════════════════════════════════════════════════════════════════════

class _Lamina extends StatelessWidget {
  final PremioItem premio;
  final bool apagado;
  const _Lamina({required this.premio, required this.apagado});

  @override
  Widget build(BuildContext context) {
    final accent = apagado ? Colors.white : premio.categoria.acento;
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.18),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
      ),
      child: Center(
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                accent.withValues(alpha: 0.30),
                accent.withValues(alpha: 0.10),
              ],
            ),
            border: Border.all(color: accent.withValues(alpha: 0.4), width: 0.8),
          ),
          child: Icon(premio.icono, color: accent, size: 24),
        ),
      ),
    );

    final url = premio.imagenUrl;
    if (url == null || url.isEmpty) return fallback;
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, _) => fallback,
      errorWidget: (_, _, _) => fallback,
    );
  }
}

class _SombraInferior extends StatelessWidget {
  const _SombraInferior();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: 40,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.35)],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PASTILLA DE PRECIO — "450 pts" o "GRATIS"
// ═══════════════════════════════════════════════════════════════════════════

class _PrecioPill extends StatelessWidget {
  final PremioItem premio;
  final bool destacado;
  const _PrecioPill({required this.premio, required this.destacado});

  @override
  Widget build(BuildContext context) {
    final texto =
        premio.esGratis ? 'GRATIS' : '${_pts.format(premio.puntos)} pts';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: destacado
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [MonacoColors.monacoGreen, MonacoColors.monacoGreenDeep],
              )
            : LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.40),
                ],
              ),
        border: Border.all(
          color: Colors.white.withValues(alpha: destacado ? 0.25 : 0.18),
          width: 0.8,
        ),
        boxShadow: destacado
            ? [
                BoxShadow(
                  color: MonacoColors.monacoGreen.withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: -2,
                ),
              ]
            : null,
      ),
      child: Text(
        texto,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.1,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// "Solo Oro": el premio exige una categoría que el cliente no tiene. El
/// nombre sale del server (`tier_required_name`), nunca de acá.
class _PillSoloTier extends StatelessWidget {
  final String? nombre;
  const _PillSoloTier({required this.nombre});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.black.withValues(alpha: 0.55),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            size: 12,
            color: Colors.white.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 4),
          Text(
            nombre == null ? 'Exclusivo' : 'Solo $nombre',
            maxLines: 1,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _CandadoChico extends StatelessWidget {
  const _CandadoChico();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.45),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 0.8),
      ),
      child: Icon(
        Icons.lock_rounded,
        size: 13,
        color: Colors.white.withValues(alpha: 0.85),
      ),
    );
  }
}
