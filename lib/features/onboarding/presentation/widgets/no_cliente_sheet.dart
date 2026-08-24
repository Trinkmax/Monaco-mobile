import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/core/utils/constants.dart';

/// "¿Aún no sos cliente?" — la app NO crea cuentas: la cuenta nace cuando el
/// cliente se registra en la tablet de check-in del local (decisión del dueño,
/// 22/ago/2026). Esta hoja lo explica en tres pasos y deja una salida para el
/// caso raro del cliente que sí vino pero tiene el número cargado distinto.
Future<void> showNoClienteSheet(BuildContext context) {
  return showLiquidSheet<void>(
    context,
    title: '¿Aún no sos cliente?',
    subtitle: 'La app es para clientes de Monaco. La cuenta se crea en tu primera visita.',
    builder: (_) => const _NoClienteBody(),
  );
}

class _NoClienteBody extends StatelessWidget {
  const _NoClienteBody();

  Future<void> _abrirWhatsapp() async {
    try {
      await launchUrl(
        Uri.parse(AppConstants.supportWhatsappUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 6),
        const _Paso(
          numero: 1,
          icon: Icons.storefront_rounded,
          titulo: 'Vení a la barbería',
          texto:
              'No hace falta registrarse antes: la cuenta se crea sola con tu primera visita a cualquiera de nuestras sucursales.',
        ),
        const SizedBox(height: 10),
        const _Paso(
          numero: 2,
          icon: Icons.tablet_mac_rounded,
          titulo: 'Registrate en la tablet del local',
          texto:
              'Al llegar, en la tablet de check-in ponés tu número de celular y tu nombre. Con eso ya sos cliente de Monaco.',
        ),
        const SizedBox(height: 10),
        const _Paso(
          numero: 3,
          icon: Icons.phone_iphone_rounded,
          titulo: 'Entrá a la app con ese mismo número',
          texto:
              'Desde ese momento la app te reconoce: te mandamos un código por WhatsApp, lo ingresás y listo. Sin contraseñas.',
        ),
        const SizedBox(height: 18),
        LiquidGlass(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          borderRadius: 16,
          pressable: false,
          showVignette: false,
          tintOpacity: 0.05,
          blur: LiquidTokens.blurSubtle,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: Colors.white.withValues(alpha: 0.6)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '¿Ya viniste y la app no te reconoce? Puede que tu número esté cargado distinto. Escribinos y lo revisamos.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12.5,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LiquidButton(
          onPressed: _abrirWhatsapp,
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.chat_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                'Escribinos por WhatsApp',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: Text(
            'Entendido',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _Paso extends StatelessWidget {
  final int numero;
  final IconData icon;
  final String titulo;
  final String texto;

  const _Paso({
    required this.numero,
    required this.icon,
    required this.titulo,
    required this.texto,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
      borderRadius: 18,
      pressable: false,
      showVignette: false,
      tintOpacity: 0.06,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  MonacoColors.monacoGreen.withValues(alpha: 0.3),
                  MonacoColors.monacoGreen.withValues(alpha: 0.1),
                ],
              ),
              border: Border.all(
                color: MonacoColors.monacoGreen.withValues(alpha: 0.45),
                width: 0.8,
              ),
            ),
            child: Icon(icon, size: 19, color: MonacoColors.monacoGreen),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$numero. $titulo',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  texto,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12.5,
                    height: 1.38,
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
