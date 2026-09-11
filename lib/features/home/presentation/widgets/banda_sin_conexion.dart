import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';

/// ¿Alguna de las fuentes del Home se cayó por RED?
///
/// El Home es la única pantalla que **no** tiene un `LiquidErrorState`: sus
/// secciones colapsan solas (`error: (_, _) => const SizedBox.shrink()`) porque
/// una sección vacía es mejor que media pantalla de error. El precio de eso es
/// que un arranque en frío sin internet se ve exactamente igual que un cliente
/// nuevo sin nada: saludo, tarjeta y nada más, sin una palabra que lo explique.
/// Esta banda es esa palabra.
///
/// Sólo mira errores de red ([LiquidErrorState.isNetworkError]): un 500 del
/// server o una fila mal formada no son "sin conexión", y decirlo mandaría al
/// cliente a revisar su wifi por algo nuestro.
bool sinConexionEn(Iterable<AsyncValue<Object?>> fuentes) =>
    fuentes.any((v) => v.hasError && LiquidErrorState.isNetworkError(v.error));

/// ¿Quedó algo de la corrida anterior para mostrar? Cambia el copy: "esto es
/// viejo" no es lo mismo que "no pudimos traer nada".
bool hayDatosPreviosEn(Iterable<AsyncValue<Object?>> fuentes) =>
    fuentes.any((v) => v.hasValue);

/// **Sin conexión.** Banda fina arriba de la tarjeta.
///
/// No reemplaza al contenido: lo que ya estaba cargado sigue en pantalla (los
/// providers guardan el último valor y el Home lo lee con `valueOrNull`), y la
/// banda dice de dónde salió.
class BandaSinConexion extends StatelessWidget {
  /// `true` si hay datos de antes en pantalla.
  final bool conDatosPrevios;
  final VoidCallback onReintentar;

  /// Margen inferior (0 cuando la banda no se dibuja: lo decide el llamador).
  final double espacioAbajo;

  const BandaSinConexion({
    super.key,
    required this.conDatosPrevios,
    required this.onReintentar,
    this.espacioAbajo = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: espacioAbajo),
      child: LiquidGlass(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        borderRadius: 20,
        tint: MonacoColors.warning,
        tintOpacity: 0.10,
        pressable: false,
        showVignette: false,
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: MonacoColors.warning.withValues(alpha: 0.16),
                border: Border.all(
                  color: MonacoColors.warning.withValues(alpha: 0.4),
                ),
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 17,
                color: MonacoColors.warning,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sin conexión',
                    style: TextStyle(
                      color: MonacoColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    conDatosPrevios
                        ? 'Mostrando lo último disponible.'
                        : 'No pudimos traer tus datos todavía.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 12.5,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            LiquidPill(
              onTap: onReintentar,
              borderRadius: 14,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded, size: 15, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Reintentar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
