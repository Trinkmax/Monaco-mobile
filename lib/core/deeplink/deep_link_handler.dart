import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import '../push/push_handler.dart';
import '../utils/constants.dart';

/// Deep links propios de la app. Hoy hay uno solo:
///
///     monaco://pago?deposit=<uuid>
///
/// Es la vuelta del checkout de Mercado Pago. MP sólo acepta `back_urls`
/// **https** (una URL sin la "s" la descarta en silencio) y no admite esquemas
/// propios, así que el camino real es: MP → `https://…/pago/<id>` → esa página
/// rebota a este esquema.
///
/// **El parámetro no puede llamarse `code`.** `supabase_flutter` engancha todos
/// los deep links del proceso y cualquiera que traiga `code` lo trata como
/// callback de OAuth: intenta canjearlo por una sesión, falla, y de paso puede
/// ensuciar la sesión buena del cliente.
///
/// Todo esto es **best-effort**: el deep link puede no llegar nunca (el cliente
/// vuelve con el botón de atrás, o el navegador se quedó abierto en otra app).
/// Por eso la pantalla de pago también se alcanza desde "Mis turnos" y desde el
/// cartel de "retomá tu pago", y por eso acá no hay ningún estado que la app
/// necesite: esto sólo ahorra toques.
class DeepLinkHandler {
  DeepLinkHandler._();

  static StreamSubscription<Uri>? _sub;
  static bool _initialized = false;

  /// Idempotente. Se llama desde `main()` después de inicializar Supabase.
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final links = AppLinks();
      _sub = links.uriLinkStream.listen(
        manejar,
        onError: (Object e) => debugPrint('[deeplink] stream: $e'),
      );
      // App cerrada y abierta POR el link: el stream no reemite ese primero.
      final inicial = await links.getInitialLink();
      if (inicial != null) manejar(inicial);
    } catch (e) {
      // Sin deep links la app funciona igual, sólo con un toque más.
      debugPrint('[deeplink] no se pudo inicializar: $e');
    }
  }

  /// Ruta interna para un link entrante, o `null` si no es nuestro.
  ///
  /// Es `visibleForTesting` para poder fijar en un test que
  /// `monaco://pago?deposit=…` mapea a `/pago/…` y que nada más lo hace: un
  /// deep link que navega a cualquier lado es una puerta abierta.
  @visibleForTesting
  static String? rutaPara(Uri uri) {
    if (uri.scheme.toLowerCase() != AppConstants.deepLinkScheme) return null;
    if (uri.host.toLowerCase() != AppConstants.deepLinkPagoHost) return null;
    final id = uri.queryParameters[AppConstants.deepLinkPagoParam]?.trim() ?? '';
    if (id.isEmpty) return null;
    // El id viaja en el path, así que no puede traer barras ni nada que
    // reescriba la ruta.
    if (!RegExp(r'^[A-Za-z0-9-]{8,64}$').hasMatch(id)) {
      debugPrint('[deeplink] id de seña con forma rara, lo ignoro');
      return null;
    }
    return '/pago/$id';
  }

  static void manejar(Uri uri) {
    final ruta = rutaPara(uri);
    if (ruta == null) return;
    // `PushHandler.navigateTo` ya resuelve los dos problemas de navegar desde
    // afuera del árbol: que el router todavía no esté montado (arranque en
    // frío) y que el cliente esté en el login. Reusarlo evita tener dos
    // implementaciones de la misma espera.
    PushHandler.navigateTo(ruta);
  }

  static Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _initialized = false;
  }
}
