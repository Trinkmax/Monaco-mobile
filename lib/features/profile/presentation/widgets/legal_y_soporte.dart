import 'package:flutter/material.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/core/utils/constants.dart';
import 'package:monaco_mobile/features/appointments/presentation/widgets/turno_links.dart';
import 'package:monaco_mobile/features/senas/presentation/widgets/arrepentimiento_link.dart';

/// **Legal y soporte: una sola fila que abre una hoja** (pedido del dueño,
/// 18/sep/2026). Hasta hoy eran seis filas a la vista en el Perfil —privacidad,
/// términos, botón de arrepentimiento, soporte, WhatsApp, email— y ocupaban
/// media pantalla con la misma jerarquía que "Mis premios". El cliente entra
/// al Perfil por sus puntos y sus turnos; lo legal tiene que estar, no gritar.
///
/// Lo que NO cambia: las seis opciones siguen existiendo, con los mismos
/// nombres, a dos toques. App Store pide privacidad y términos accesibles, y
/// la Disp. 954/2025 pide el "Botón de arrepentimiento" con ese nombre exacto y
/// de fácil acceso: una hoja desde el Perfil lo es; borrarlo o renombrarlo, no.
///
/// La misma fila va en el Perfil con cuenta y en el de invitado: el que todavía
/// no tiene cuenta es justamente el que más necesita encontrar cómo pedir
/// ayuda.
class LegalYSoporteFila extends StatelessWidget {
  const LegalYSoporteFila({super.key});

  @override
  Widget build(BuildContext context) {
    return LiquidSectionCard(
      children: [
        LiquidListTile(
          icon: Icons.help_outline_rounded,
          title: 'Legal y soporte',
          subtitle: 'Privacidad, términos y cómo escribirnos',
          onTap: () => abrirLegalYSoporte(context),
        ),
      ],
    );
  }
}

/// La hoja con las seis opciones.
///
/// [contexto] es el de la pantalla que la abre y sobrevive al cierre de la
/// hoja: cada opción primero cierra la hoja y recién después abre el link, y
/// el toast de "no pudimos abrir" (`abrirUrlExterna`) necesita un context que
/// siga montado. El orden es por uso: contacto primero, lo legal después, y el
/// botón de arrepentimiento al final — está, con su nombre exacto, pero no es
/// lo primero que se lee.
Future<void> abrirLegalYSoporte(BuildContext contexto) {
  return showLiquidSheet<void>(
    contexto,
    title: 'Legal y soporte',
    builder: (ctx) {
      Future<void> ir(Future<void> Function() accion) async {
        Navigator.of(ctx).pop();
        await accion();
      }

      return LiquidSectionCard(
        children: [
          LiquidListTile(
            icon: Icons.help_outline_rounded,
            title: 'Soporte',
            subtitle: 'Preguntas frecuentes y cómo escribirnos',
            onTap: () =>
                ir(() => abrirUrlExterna(contexto, AppConstants.supportUrl)),
          ),
          LiquidListTile(
            icon: Icons.chat_rounded,
            iconColor: MonacoColors.monacoGreen,
            title: 'Soporte por WhatsApp',
            subtitle:
                '${AppConstants.supportPhoneDisplay} · en horario de atención',
            onTap: () => ir(
              () => abrirUrlExterna(contexto, AppConstants.supportWhatsappUrl),
            ),
          ),
          LiquidListTile(
            icon: Icons.alternate_email_rounded,
            title: 'Soporte por email',
            subtitle: AppConstants.supportEmail,
            onTap: () => ir(
              () => abrirUrlExterna(
                contexto,
                'mailto:${AppConstants.supportEmail}?subject=${Uri.encodeComponent('Soporte app Monaco')}',
              ),
            ),
          ),
          LiquidListTile(
            icon: Icons.shield_outlined,
            title: 'Política de privacidad',
            onTap: () => ir(
              () => abrirUrlExterna(contexto, AppConstants.privacyPolicyUrl),
            ),
          ),
          LiquidListTile(
            icon: Icons.description_outlined,
            title: 'Términos y condiciones',
            onTap: () => ir(
              () => abrirUrlExterna(contexto, AppConstants.termsOfServiceUrl),
            ),
          ),
          LiquidListTile(
            icon: Icons.undo_rounded,
            title: 'Botón de arrepentimiento',
            subtitle: 'Pedir la devolución de una seña',
            onTap: () => ir(() => abrirArrepentimiento(contexto)),
          ),
        ],
      );
    },
  );
}
