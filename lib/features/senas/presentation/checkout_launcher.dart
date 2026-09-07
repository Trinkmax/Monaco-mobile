import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart' as ct;
import 'package:url_launcher/url_launcher.dart' as ul;

import 'package:monaco_mobile/app/theme/monaco_colors.dart';

/// Abre el checkout de Mercado Pago.
///
/// **Nunca en un WebView.** Mercado Pago deshabilitó ese modelo para todas las
/// integraciones: además de estar prohibido, un WebView no comparte la sesión
/// del navegador ni las credenciales guardadas, así que el cliente termina
/// tipeando su tarjeta cuando podía pagar con dinero en cuenta en dos toques.
///
/// - **Android → Custom Tabs** (`flutter_custom_tabs`): el checkout se ve
///   dentro de la app, con la barra de URL del navegador, y vuelve solo al
///   cerrarse. Necesita el bloque `<queries>` con VIEW/https + BROWSABLE en el
///   manifest; sin eso, en API 30+ no resuelve navegador y el botón "no hace
///   nada".
/// - **iOS → Safari de verdad** (`url_launcher` en `externalApplication`). Es
///   la única forma de que los universal links de Mercado Pago puedan saltar a
///   la app de MP si el cliente la tiene instalada, que con `wallet_only` es la
///   diferencia entre pagar en dos toques y tipear una tarjeta.
///   Contrapartida: no hay botón "Listo" para volver, así que el regreso
///   depende del deep link `monaco://pago?deposit=<id>` — y por eso la pantalla
///   de estado tiene que funcionar igual si ese deep link nunca llega.
///
/// Devuelve `false` si no se pudo abrir NADA. En ese caso no hay que dar el
/// pago por iniciado: si el navegador nunca abrió, no hay cobro posible.
Future<bool> abrirCheckoutSena(String initPoint) async {
  final uri = Uri.tryParse(initPoint);
  if (uri == null || !uri.isScheme('https')) {
    // El motor ya valida que la back_url y la notification_url sean https;
    // esto ataja un init_point corrupto antes de mandar al cliente a la nada.
    debugPrint('[sena] init_point inválido: $initPoint');
    return false;
  }

  final esAndroid = !kIsWeb && Platform.isAndroid;
  if (esAndroid) {
    try {
      await ct.launchUrl(
        uri,
        customTabsOptions: ct.CustomTabsOptions(
          colorSchemes: ct.CustomTabsColorSchemes.defaults(
            colorScheme: ct.CustomTabsColorScheme.dark,
            toolbarColor: MonacoColors.background,
            navigationBarColor: MonacoColors.background,
          ),
          showTitle: true,
          // La barra de URL se queda fija: en una pantalla de pago, ver el
          // dominio de Mercado Pago es parte de poder confiar en ella.
          urlBarHidingEnabled: false,
          // `CustomTabsCloseButtonIcons.back` es un getter, no una constante:
          // este bloque no puede ser `const`.
          closeButton: ct.CustomTabsCloseButton(
            icon: ct.CustomTabsCloseButtonIcons.back,
          ),
        ),
      );
      return true;
    } catch (e) {
      // Equipo sin ningún navegador con soporte de Custom Tabs: se cae al
      // navegador externo antes de darse por vencido.
      debugPrint('[sena] custom tabs falló, voy a navegador externo: $e');
    }
  }

  try {
    final ok = await ul.launchUrl(uri, mode: ul.LaunchMode.externalApplication);
    if (ok) return true;
  } catch (e) {
    debugPrint('[sena] launchUrl externo falló: $e');
  }

  // Último intento: que el sistema decida. Un pago que no abre es peor que un
  // pago que abre en una vista que no elegimos.
  try {
    return await ul.launchUrl(uri, mode: ul.LaunchMode.platformDefault);
  } catch (e) {
    debugPrint('[sena] launchUrl platformDefault falló: $e');
    return false;
  }
}

/// Cierra el Custom Tab si quedó abierto (Android). En iOS, con Safari externo,
/// no hay nada que cerrar: lo llamamos igual porque el plugin lo ignora.
Future<void> cerrarCheckoutSena() async {
  try {
    await ct.closeCustomTabs();
  } catch (e) {
    debugPrint('[sena] closeCustomTabs: $e');
  }
}
