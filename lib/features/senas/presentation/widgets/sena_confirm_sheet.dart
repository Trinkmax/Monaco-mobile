import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/core/utils/constants.dart';
import 'package:monaco_mobile/features/appointments/data/fechas.dart';

import '../../data/sena_models.dart';

/// Lo que el cliente está por reservar, para que el resumen de la hoja no
/// dependa del estado del wizard.
class ResumenTurnoSena {
  final String sucursal;
  final String servicios;

  /// 'yyyy-MM-dd' (hora de pared de la sucursal).
  final String fecha;

  /// 'HH:MM'.
  final String hora;
  final String? barbero;

  const ResumenTurnoSena({
    required this.sucursal,
    required this.servicios,
    required this.fecha,
    required this.hora,
    this.barbero,
  });

  /// "Corte + Barba · Jue 4 sep 18:30" — el texto corto del cartel de
  /// "retomá tu pago".
  String get linea {
    final partes = [
      if (servicios.trim().isNotEmpty) servicios.trim(),
      '${Fechas.fechaCortaDeStr(fecha)} ${Fechas.hhmm(hora)}',
    ];
    return partes.join(' · ');
  }
}

/// Hoja de confirmación de la seña. Es la última pantalla antes de que salga
/// plata, así que muestra las cuatro cosas juntas: qué se reserva, cuánto se
/// cobra ahora, cuánto queda para el local y la política **completa** que
/// mandó el server.
///
/// Devuelve `true` si el cliente aceptó pagar.
Future<bool> mostrarHojaDeSena(
  BuildContext context, {
  required SenaIntencion intencion,
  required ResumenTurnoSena resumen,
}) async {
  final ok = await showLiquidSheet<bool>(
    context,
    // El título lo escribe el server ("Seña $8.000 ARS"): es el mismo número
    // que va a cobrar, y duplicar el formateo acá es cómo se llega a que la
    // pantalla diga una cosa y el cobro haga otra.
    title: intencion.politica.titulo.isEmpty
        ? 'Seña ${Fechas.moneda(intencion.monto)}'
        : intencion.politica.titulo,
    // Sin subtítulo a propósito: decía lo mismo que el primer párrafo de la
    // política y empujaba "Ahora no" y el aviso de Mercado Pago abajo del
    // pliegue. En la hoja donde sale plata, todo tiene que entrar sin scrollear.
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
    builder: (ctx) => _CuerpoHoja(intencion: intencion, resumen: resumen),
  );
  return ok == true;
}

class _CuerpoHoja extends StatefulWidget {
  final SenaIntencion intencion;
  final ResumenTurnoSena resumen;

  const _CuerpoHoja({required this.intencion, required this.resumen});

  @override
  State<_CuerpoHoja> createState() => _CuerpoHojaState();
}

class _CuerpoHojaState extends State<_CuerpoHoja> {
  /// El acto de aceptación. Arranca en false SIEMPRE: una casilla premarcada
  /// no es consentimiento, es una casilla premarcada.
  bool _aceptado = false;

  late final TapGestureRecognizer _terminos = TapGestureRecognizer()
    ..onTap = () => _abrir(AppConstants.termsOfServiceUrl);

  Future<void> _abrir(String url) async {
    try {
      // Sin `canLaunchUrl`: en iOS 17+ devuelve false para https si el scheme
      // no está declarado (mismo criterio que `LegalFooter`).
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[sena] no se pudo abrir $url: $e');
    }
  }

  @override
  void dispose() {
    _terminos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final intencion = widget.intencion;
    final resumen = widget.resumen;
    final parrafos = intencion.politica.parrafos;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ResumenTurno(resumen: resumen),
        const SizedBox(height: 12),
        _Montos(intencion: intencion),
        const SizedBox(height: 12),
        if (parrafos.isNotEmpty) ...[
          _Politica(parrafos: parrafos),
          const SizedBox(height: 10),
        ],
        // El botón de arrepentimiento va donde está el derecho: al lado del
        // párrafo que lo anuncia. En la web el mismo párrafo lleva el link a
        // /arrepentimiento; sin él, la app anunciaba un derecho y no decía
        // dónde ejercerlo (Res. 424/2020 pide que esté accesible).
        if (intencion.politica.arrepentimiento != null) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _abrir('${AppConstants.apiBaseUrl}/arrepentimiento'),
              icon: const Icon(Icons.undo_rounded, size: 15),
              label: const Text(
                'Botón de arrepentimiento',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white.withValues(alpha: 0.75),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: const Size(0, 34),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
        // La aceptación, pegada al botón que cobra y con el monto adentro.
        // El turnero web exige lo mismo; sin este acto, "lo leyó" es una
        // suposición nuestra. El art. 1111 CCyC pide la información sobre
        // revocación "en caracteres destacados inmediatamente antes de la
        // aceptación": los párrafos de arriba son esa información, y esto es
        // la aceptación.
        _Aceptacion(
          aceptado: _aceptado,
          monto: Fechas.moneda(intencion.monto),
          terminos: _terminos,
          onChanged: (v) => setState(() => _aceptado = v),
        ),
        const SizedBox(height: 12),
        Opacity(
          opacity: _aceptado ? 1 : 0.55,
          child: LiquidButton(
            // Blanco: es el CTA de la pantalla, y el verde de Monaco quedó para
            // lo que significa algo del negocio (turno confirmado, sin espera).
            // Acá todavía no hay nada confirmado.
            tint: MonacoColors.seleccion,
            onPressed: _aceptado ? () => Navigator.of(context).pop(true) : null,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_rounded, size: 17, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'Pagar seña ${Fechas.moneda(intencion.monto)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 9),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_outlined,
                size: 13, color: Colors.white.withValues(alpha: 0.4)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'El pago lo procesa Mercado Pago, en tu navegador.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.42),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white.withValues(alpha: 0.6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text(
              'Ahora no',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

/// La casilla de aceptación. Misma forma que la del pie del wizard
/// (`wizard_footer.dart`) y misma copia que la del turnero web: blanco como
/// acento de estado —el verde de Monaco significa algo del negocio, y acá
/// todavía no hay nada confirmado—.
class _Aceptacion extends StatelessWidget {
  final bool aceptado;
  final String monto;
  final TapGestureRecognizer terminos;
  final ValueChanged<bool> onChanged;

  const _Aceptacion({
    required this.aceptado,
    required this.monto,
    required this.terminos,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const accent = MonacoColors.seleccion;
    final base = TextStyle(
      color: Colors.white.withValues(alpha: 0.8),
      fontSize: 12.5,
      height: 1.35,
      fontWeight: FontWeight.w500,
    );
    return Semantics(
      checked: aceptado,
      label: 'Acepto la seña y la política de cancelación',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!aceptado),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white.withValues(alpha: aceptado ? 0.07 : 0.05),
            border: Border.all(
              color: aceptado
                  ? accent.withValues(alpha: 0.45)
                  : Colors.white.withValues(alpha: 0.12),
              width: 0.8,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: LiquidTokens.swap,
                curve: LiquidTokens.curveSwap,
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  color: aceptado ? accent : Colors.transparent,
                  border: Border.all(
                    color: aceptado ? accent : Colors.white.withValues(alpha: 0.4),
                    width: aceptado ? 0 : 1.2,
                  ),
                  boxShadow: aceptado
                      ? [BoxShadow(color: accent.withValues(alpha: 0.45), blurRadius: 10)]
                      : null,
                ),
                child: aceptado
                    ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: base,
                    children: [
                      const TextSpan(text: 'Leí y acepto la seña de '),
                      TextSpan(
                        text: monto,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const TextSpan(text: ' y la política de cancelación, y los '),
                      TextSpan(
                        text: 'términos y condiciones',
                        style: base.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white.withValues(alpha: 0.4),
                        ),
                        recognizer: terminos,
                      ),
                      const TextSpan(text: '.'),
                    ],
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

class _ResumenTurno extends StatelessWidget {
  final ResumenTurnoSena resumen;
  const _ResumenTurno({required this.resumen});

  @override
  Widget build(BuildContext context) {
    final sub = [
      resumen.sucursal,
      if (resumen.barbero != null && resumen.barbero!.isNotEmpty)
        'Te atiende ${resumen.barbero}',
    ].join(' · ');

    return LiquidGlass(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      borderRadius: 20,
      tintOpacity: 0.07,
      pressable: false,
      showVignette: false,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              color: Colors.white.withValues(alpha: 0.08),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16), width: 0.8),
            ),
            child: Icon(Icons.event_available_rounded,
                size: 20, color: Colors.white.withValues(alpha: 0.9)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${Fechas.fechaCortaDeStr(resumen.fecha)} · ${Fechas.hhmm(resumen.hora)}',
                  style: const TextStyle(
                    color: MonacoColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  resumen.servicios.isEmpty ? sub : '${resumen.servicios} · $sub',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12.5,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Montos extends StatelessWidget {
  final SenaIntencion intencion;
  const _Montos({required this.intencion});

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      borderRadius: 22,
      tintOpacity: 0.08,
      pressable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PAGÁS AHORA',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            Fechas.moneda(intencion.monto),
            style: const TextStyle(
              color: MonacoColors.textPrimary,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              height: 1.05,
              letterSpacing: -1.2,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 12),
          Container(height: 0.6, color: Colors.white.withValues(alpha: 0.10)),
          const SizedBox(height: 12),
          _Linea(
            label: 'Total del servicio',
            valor: Fechas.moneda(intencion.total),
          ),
          const SizedBox(height: 6),
          _Linea(
            label: 'Queda para el local',
            valor: Fechas.moneda(intencion.resto),
            destacado: true,
          ),
        ],
      ),
    );
  }
}

class _Linea extends StatelessWidget {
  final String label;
  final String valor;
  final bool destacado;

  const _Linea({required this.label, required this.valor, this.destacado = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: destacado ? 0.75 : 0.55),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          valor,
          style: TextStyle(
            color: destacado
                ? MonacoColors.textPrimary
                : Colors.white.withValues(alpha: 0.75),
            fontSize: 14,
            fontWeight: destacado ? FontWeight.w800 : FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Los párrafos de la política, tal como los mandó el server.
///
/// Van en la misma pantalla y pegados al botón, no detrás de un "ver más": el
/// art. 1111 CCyC pide que la información sobre revocación esté "en caracteres
/// destacados inmediatamente antes de la aceptación", y esconderla hace que el
/// plazo de arrepentimiento ni siquiera empiece a correr.
class _Politica extends StatelessWidget {
  final List<String> parrafos;
  const _Politica({required this.parrafos});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < parrafos.length; i++) ...[
            if (i > 0) const SizedBox(height: 9),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    parrafos[i],
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 12.5,
                      height: 1.42,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
