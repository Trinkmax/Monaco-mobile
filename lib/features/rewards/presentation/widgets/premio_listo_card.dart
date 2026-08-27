import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';

/// Tarjeta de la tira **"Listos para usar"**: un premio ya canjeado, esperando
/// que el cliente lo muestre en el local.
///
/// Lleva el QR de verdad —chico— y no un ícono: es lo que hace que la tarjeta se
/// lea como un voucher y no como otro ítem del catálogo. Tocarla lo abre a
/// pantalla completa, que es el tamaño con el que el barbero lo escanea.
class PremioListoCard extends StatelessWidget {
  /// Fila de `get_client_wallet`.
  final Map<String, dynamic> reward;
  final VoidCallback onTap;

  const PremioListoCard({super.key, required this.reward, required this.onTap});

  static const double alto = 158;
  static const double ancho = 178;

  @override
  Widget build(BuildContext context) {
    final nombre = (reward['reward_name'] as String?)?.trim();
    final qr = (reward['qr_code'] as String?)?.trim() ?? '';
    final vence = _vencimiento(reward['expires_at']);

    return Semantics(
      button: true,
      label: 'Premio listo para usar: ${nombre ?? 'Premio'}. Ver código',
      child: LiquidGlass(
        onTap: onTap,
        width: ancho,
        height: alto,
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        borderRadius: 22,
        tint: MonacoColors.monacoGreen,
        tintOpacity: 0.13,
        showVignette: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MiniQr(data: qr),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LISTO',
                        style: TextStyle(
                          color: MonacoColors.monacoGreen.withValues(alpha: 0.95),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        nombre ?? 'Premio',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: MonacoColors.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (vence != null)
              Text(
                vence,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  'Mostrar código',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// "Vence hoy" / "Vence el 12 de sep". `null` si no vence o ya venció (un
  /// premio vencido no debería estar en esta tira, y si llega, no le metemos
  /// una fecha vieja al cliente en la cara).
  static String? _vencimiento(Object? raw) {
    final s = raw?.toString();
    if (s == null || s.isEmpty) return null;
    final d = DateTime.tryParse(s)?.toLocal();
    if (d == null) return null;
    final dias = d.difference(DateTime.now()).inDays;
    if (dias < 0) return null;
    if (dias == 0) return 'Vence hoy';
    return 'Vence el ${DateFormat("d 'de' MMM", 'es').format(d)}';
  }
}

/// QR chico sobre blanco. Si el premio no trae código —no debería pasar— cae a
/// un ícono en vez de dibujar un QR de la cadena vacía, que sería un cuadrado
/// escaneable que no lleva a ningún lado.
class _MiniQr extends StatelessWidget {
  final String data;
  const _MiniQr({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            spreadRadius: -3,
          ),
        ],
      ),
      child: data.isEmpty
          ? const Icon(Icons.qr_code_2_rounded, color: Colors.black87, size: 28)
          : QrImageView(
              data: data,
              version: QrVersions.auto,
              padding: EdgeInsets.zero,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Colors.black,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Colors.black,
              ),
            ),
    );
  }
}
