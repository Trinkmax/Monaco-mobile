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
/// **El parámetro se llama `deposit` y no `code`.** Cuando el observer de deep
/// links de `supabase_flutter` está prendido, cualquier link con `code` lo
/// trata como callback de OAuth: intenta canjearlo por una sesión, falla, y de
/// paso puede ensuciar la sesión buena del cliente. Desde el 10/sep/2026 ese
/// observer está apagado (`detectSessionInUri: false` en `main.dart`: la app no
/// usa OAuth de Supabase por deep link, el login social va por `client-auth`
/// con el `id_token`), así que hoy el nombre ya no es lo único que nos separa
/// de ese choque — **pero se mantiene igual**: `detectSessionInUri` es una
/// línea que alguien puede revertir mientras agrega otra cosa, y el precio de
/// no depender de ella es cero. Fijado en `test/unit/deep_link_test.dart`.
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
  /// Es la ÚNICA regla que decide qué link entrante es legítimo, y por eso la
  /// usan los dos caminos por los que puede llegar uno: este handler (vía
  /// `app_links`) y el `redirect` del router, que recibe la URI cruda cuando el
  /// motor de Flutter se adelanta. Un deep link que navega a cualquier lado es
  /// una puerta abierta; tener dos implementaciones de esta regla es tenerla
  /// abierta a medias.
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

// ── Destinos que la app abre desde un link cargado a mano ────────────────

/// Destinos internos que la app sabe abrir cuando la ruta la **tipea una
/// persona**: los `link_value` de la cartelera y de las campañas, que el dueño
/// carga a mano en `/dashboard/app-movil`.
///
/// Es una lista blanca y no un `startsWith('/')` porque un valor que no matchea
/// ninguna ruta ya no falla en silencio: desde que el router tiene
/// `errorBuilder`, `context.push('/promo')` le pinta al cliente la pantalla de
/// "no encontramos esa página" —y un typo del dueño se ve como una app rota—.
/// Con la lista, un destino desconocido simplemente no navega.
///
/// **Espeja las rutas de `app_router.dart`** (que este archivo no puede
/// importar sin ciclo) y a propósito NO están todas: las de login, el gate de
/// PIN y el splash no son destinos de una promo. `test/unit/deep_link_test.dart`
/// verifica que cada entrada exista de verdad en el router.
const Set<String> rutasInternasDeContenido = {
  '/home',
  '/turnos',
  '/turnos/reservar',
  '/occupancy',
  '/rewards',
  '/profile',
  '/points',
  '/categoria',
  '/invitar',
  '/mis-premios',
  '/mis-canjes',
  '/convenios',
  '/reviews',
  '/visits',
  '/billboard',
  '/notificaciones',
};

/// ¿El valor es una URL que hay que abrir en el navegador?
///
/// Sólo `http`/`https`: un `javascript:` o un esquema propio de otra app
/// entrado por un campo de texto del dashboard no es un destino de cartelera.
bool esUrlExterna(String valor) {
  final v = valor.toLowerCase();
  return v.startsWith('http://') || v.startsWith('https://');
}

/// Rutas con id: se valida la FORMA, no el id. Que el id exista lo resuelve la
/// pantalla, que ya sabe decir "no lo encontramos".
const List<String> _prefijosInternosDeContenido = ['/branch/', '/convenio/'];

/// ¿`ruta` es un destino interno que la app sabe abrir?
///
/// Acepta query string (`/turnos/reservar?branch=rondeau` es un link legítimo
/// del local: el wizard lee ese parámetro y saltea el paso de sucursal), y por
/// eso valida sólo el camino. Quien navega manda el valor **entero**.
bool esRutaInternaDeContenido(String ruta) {
  if (!ruta.startsWith('/')) return false;
  final camino = ruta.split(RegExp(r'[?#]')).first;
  if (rutasInternasDeContenido.contains(camino)) return true;
  return _prefijosInternosDeContenido.any(
    (p) => camino.startsWith(p) && camino.length > p.length,
  );
}
