import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/core/utils/constants.dart';

/// **Botón de arrepentimiento** (Disp. 954/2025 de la Secretaría de Comercio,
/// que derogó la Res. 424/2020).
///
/// La página vive en el dashboard (`/arrepentimiento`, verificada 200 el
/// 10/sep/2026) y es la misma a la que llega quien compra por la web.
///
/// **Por qué está en más de un lugar:** el art. 1110 CCyC da 10 días corridos
/// irrenunciables para revocar, y el plazo empieza a correr con el pago. O sea
/// que el momento en que el cliente más lo necesita es DESPUÉS de pagar —y
/// hasta hoy el único acceso estaba en la hoja de confirmación, o sea ANTES—.
/// La Disp. 954/2025 pide además que sea "visible y de fácil acceso" desde el
/// primer acceso, no escondido detrás del flujo de compra.
///
/// La URL vive en `AppConstants.arrepentimientoUrl`, junto a las otras que las
/// fichas de tienda declaran. Este alias queda porque lo usan los call-sites y
/// el toast de más abajo.
const String urlArrepentimiento = AppConstants.arrepentimientoUrl;

/// Abre la página de arrepentimiento en el navegador del sistema.
///
/// Sin `canLaunchUrl`: en iOS 17+ devuelve `false` para https si el scheme no
/// está declarado (mismo criterio que `LegalFooter` y que la hoja de seña).
Future<void> abrirArrepentimiento(BuildContext context) async {
  var ok = false;
  try {
    ok = await launchUrl(
      Uri.parse(urlArrepentimiento),
      mode: LaunchMode.externalApplication,
    );
  } catch (e) {
    debugPrint('[sena] no se pudo abrir $urlArrepentimiento: $e');
  }
  if (!ok && context.mounted) {
    showLiquidToast(
      context,
      'No pudimos abrir la página. Entrá a monacobarber.vercel.app/arrepentimiento.',
      tone: LiquidToastTone.error,
      duration: const Duration(seconds: 4),
    );
  }
}

/// El link, con la misma forma en las tres pantallas donde aparece (hoja de
/// seña, resultado del pago y detalle del turno señado): discreto, pero con el
/// nombre EXACTO que exige la norma —"Botón de arrepentimiento"—, que es lo que
/// el cliente va a buscar.
class ArrepentimientoLink extends StatelessWidget {
  /// Alineación dentro del ancho disponible. Izquierda en la hoja (va pegado
  /// al párrafo que anuncia el derecho), centrada en las pantallas de estado.
  final Alignment alineacion;

  const ArrepentimientoLink({super.key, this.alineacion = Alignment.centerLeft});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alineacion,
      child: TextButton.icon(
        onPressed: () => abrirArrepentimiento(context),
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
    );
  }
}
