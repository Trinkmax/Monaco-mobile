import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:monaco_mobile/features/rewards/providers/premios_provider.dart';

import 'push_service.dart';

/// Dónde está parado el router cuando llega un push, a los efectos de decidir
/// si su ruta se navega, se guarda o se descarta.
enum EsperaDePush {
  /// El router está en una pantalla normal: se puede navegar ya.
  navegar,

  /// Candado local (splash / biometría / PIN): hay sesión o se está
  /// resolviendo, así que la ruta pendiente se guarda hasta que salga.
  gate,

  /// Sin sesión (bienvenida / login): la ruta se descarta tras el tope corto.
  sinSesion,
}

/// Resuelve qué hacer con un push: a dónde navegar y qué marcar como leído.
///
/// Contrato del payload (CONTRACTS.md §6.7), todo string:
/// `data = { type, value?, deep_link?, notification_id?, loyalty_kind? }`.
/// - Si viene `deep_link` y es un path interno (empieza con `/`), gana.
/// - Si viene `loyalty_kind` (fidelización, `loyalty_notify` en la mig 197:
///   el `type` es `reward` o `points` y la familia viaja aparte), se resuelve
///   por familia ([loyaltyRouteFor]).
/// - Si no, se decide por `type`: `appointment_*` → `/turnos`, `reward` →
///   `/rewards`, `points` → `/points`, `campaign`/default → `/home`.
/// - Si viene `notification_id`, se marca `client_notifications.read_at`
///   (UPDATE por RLS `cn_client_update`).
///
/// La misma tabla de ruteo la usa la bandeja in-app ([routeFor]), así un tap
/// en la notificación del sistema y un tap en la bandeja llevan al mismo lugar.
class PushHandler {
  PushHandler._();

  static GlobalKey<NavigatorState>? _navigatorKey;
  static bool _initialized = false;

  /// Ruta pendiente si el push llegó antes de que el árbol estuviera montado
  /// (app abierta desde la notificación: el router todavía está en /splash).
  static String? _pendingRoute;
  static Timer? _pendingTimer;
  static int _pendingTries = 0;
  static EsperaDePush? _ultimaEspera;

  /// Rutas que viven en el shell con dock: se navegan con `go` (reemplazan la
  /// pestaña) y no con `push` (que las apilaría sin dock).
  static const Set<String> _shellPaths = {
    '/home',
    '/turnos',
    '/occupancy',
    '/rewards',
    '/profile',
  };

  /// La usa también la bandeja (`notifications_screen`), que abre las filas con
  /// el mismo criterio: una sola lista, no dos que se desincronizan.
  static bool esRutaDeShell(String route) {
    try {
      return _shellPaths.contains(Uri.parse(route).path);
    } catch (_) {
      return false;
    }
  }

  /// Gates: hay (o puede haber) sesión, pero el cliente todavía no pasó el
  /// candado local. La ruta pendiente **no se descarta** acá: se navega en
  /// cuanto el router sale del gate.
  static const Set<String> _gatePaths = {'/splash', '/biometric', '/pin'};

  /// Sin sesión: acá sí tiene sentido rendirse (nadie va a llegar a la
  /// pantalla que promete el push).
  static const Set<String> _loginPaths = {'/welcome', '/login'};

  /// Tope de reintentos con el router afuera de un gate (sin sesión, o todavía
  /// sin árbol montado): 40 × 500 ms = 20 s.
  static const int _maxTriesSinSesion = 40;

  /// Tope de reintentos mientras el cliente resuelve PIN/biometría: 10 min.
  /// Antes eran los mismos 20 s, y un Face ID que falla o un PIN tipeado
  /// despacio dejaban al cliente en Home después de tocar "Te faltan 20 pts
  /// para tu premio" — justo a los que activaron seguridad.
  static const int _maxTriesEnGate = 1200;

  static const Duration _esperaEntreIntentos = Duration(milliseconds: 500);

  /// Categoría de espera de la ruta donde está parado el router.
  static EsperaDePush esperaPara(String path) {
    if (_gatePaths.contains(path)) return EsperaDePush.gate;
    if (_loginPaths.contains(path) || path.startsWith('/login/')) {
      return EsperaDePush.sinSesion;
    }
    return EsperaDePush.navegar;
  }

  /// Rutas cuyo contenido sale de los providers de fidelización (globales,
  /// cacheados de por vida): un push que aterriza ahí promete un dato nuevo
  /// ("Sumaste 110 pts") y sin refrescar la pantalla mostraba la última carga.
  static const Set<String> _rutasDeFidelizacion = {
    '/home',
    '/points',
    '/rewards',
    '/mis-premios',
    '/categoria',
    '/invitar',
  };

  /// La usa también la bandeja (`notifications_screen`): un tap ahí y un tap
  /// en la notificación del sistema tienen que refrescar igual.
  static bool esRutaDeFidelizacion(String route) {
    try {
      return _rutasDeFidelizacion.contains(Uri.parse(route).path);
    } catch (_) {
      return false;
    }
  }

  static void _refrescarSiFidelizacion(BuildContext context, String route) {
    if (!esRutaDeFidelizacion(route)) return;
    try {
      invalidarFidelizacionEn(ProviderScope.containerOf(context));
    } catch (e) {
      // Sin ProviderScope todavía (arranque muy temprano) no hay nada
      // cacheado que refrescar: la pantalla se computa fresca al montarse.
      debugPrint('[push] refresco de fidelización: $e');
    }
  }

  /// `main.dart` lo llama con `rootNavigatorKey` del router.
  static void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  /// Engancha los tres caminos de FCM. Idempotente y seguro sin Firebase.
  static void init() {
    if (_initialized || !PushService.isAvailable) return;
    _initialized = true;

    // App cerrada → abierta desde la notificación.
    FirebaseMessaging.instance
        .getInitialMessage()
        .then((message) {
          if (message != null) handleMessage(message);
        })
        .catchError((Object e) {
          debugPrint('[push] getInitialMessage: $e');
        });

    // App en background → tap.
    FirebaseMessaging.onMessageOpenedApp.listen(
      handleMessage,
      onError: (Object e) => debugPrint('[push] onMessageOpenedApp: $e'),
    );

    // App en primer plano → mostrar (Android: local; iOS: el sistema).
    FirebaseMessaging.onMessage.listen(
      _onForegroundMessage,
      onError: (Object e) => debugPrint('[push] onMessage: $e'),
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // Ruteo
  // ───────────────────────────────────────────────────────────────────────

  /// Path interno válido: empieza con `/`, no es protocol-relative (`//`) y
  /// no esconde un esquema. Cualquier otra cosa se ignora (un push no puede
  /// sacar al cliente de la app).
  static bool isInternalPath(String? link) {
    if (link == null) return false;
    final l = link.trim();
    if (l.length < 2 || !l.startsWith('/')) return false;
    if (l.startsWith('//')) return false;
    if (l.contains('://') || l.contains('\\')) return false;
    return true;
  }

  /// Tabla de ruteo única para push y bandeja.
  static String routeFor({
    String? deepLink,
    String? type,
    String? value,
    String? loyaltyKind,
  }) {
    if (isInternalPath(deepLink)) return deepLink!.trim();
    // Fidelización: las reglas de `loyalty_notification_rules` mandan
    // `deep_link` (que gana arriba); esto es el respaldo si una regla se
    // guardó sin él, para que un `benefit_new` no caiga en `/rewards`.
    final porFamilia = loyaltyRouteFor(loyaltyKind);
    if (porFamilia != null) return porFamilia;
    final v = (value ?? '').trim();
    switch (type) {
      case 'appointment_reminder':
      case 'appointment_update':
      case 'appointment':
        return '/turnos';
      case 'reward':
        return '/rewards';
      case 'points':
        return '/points';
      case 'review_request':
      case 'review':
        return v.isNotEmpty ? '/review/$v' : '/reviews';
      case 'branch':
        return v.isNotEmpty ? '/branch/$v' : '/occupancy';
      case 'billboard':
        return '/billboard';
      case 'campaign':
      case 'promo':
      case 'alert':
      case 'test':
      default:
        return '/home';
    }
  }

  /// Ruta por familia del `kind` de `loyalty_notification_rules` (`tier_up`,
  /// `near_tier`, `points_expiring`, `benefit_new`, `referral_completed_*`…),
  /// que `loyalty_notify` manda en `data.loyalty_kind` — el `type` de esas
  /// notificaciones es `reward` o `points`, nunca `loyalty_*` (el CHECK de
  /// `client_notifications` no lo admite). `null` si no es de fidelización.
  static String? loyaltyRouteFor(String? kind) {
    final k = kind?.trim();
    if (k == null || k.isEmpty) return null;
    if (k.startsWith('tier') || k == 'near_tier') return '/categoria';
    if (k.startsWith('referral')) return '/invitar';
    if (k.startsWith('points')) return '/points';
    if (k == 'benefit_new') return '/mis-premios';
    if (k.contains('reward')) return '/rewards';
    return '/categoria';
  }

  static String? _str(Object? v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  /// Resuelve la ruta de un `data` de push (o de una fila de la bandeja).
  static String routeForData(Map<String, dynamic> data) {
    return routeFor(
      deepLink: _str(data['deep_link']),
      type: _str(data['type']),
      value: _str(data['value']) ?? _str(data['token']),
      loyaltyKind: _str(data['loyalty_kind']),
    );
  }

  /// Tap sobre una notificación del sistema.
  static void handleMessage(RemoteMessage message) {
    handleData(Map<String, dynamic>.from(message.data));
  }

  /// Tap resuelto a partir del `data`: marca leída y navega.
  static void handleData(Map<String, dynamic> data) {
    final notificationId = _str(data['notification_id']);
    if (notificationId != null) {
      unawaited(markNotificationRead(notificationId));
    }
    navigateTo(routeForData(data));
  }

  /// Navega con el navigator raíz. Si el árbol todavía no está listo (push que
  /// abre la app), guarda la ruta y reintenta: hasta 20 s sin sesión, hasta 10
  /// min mientras el cliente esté resolviendo su PIN o su biometría.
  static void navigateTo(String route) {
    _pendingRoute = route;
    _pendingTries = 0;
    _ultimaEspera = null;
    _pendingTimer?.cancel();
    _tryNavigate();
  }

  /// Ruta que todavía espera para navegarse (`null` si no hay ninguna).
  @visibleForTesting
  static String? get rutaPendiente => _pendingRoute;

  /// Suelta la ruta pendiente y su timer. Sólo para tests: un timer vivo al
  /// final de un test de widgets lo hace fallar.
  @visibleForTesting
  static void debugReset() {
    _pendingRoute = null;
    _pendingTries = 0;
    _ultimaEspera = null;
    _pendingTimer?.cancel();
    _pendingTimer = null;
  }

  static void _tryNavigate() {
    final route = _pendingRoute;
    if (route == null) return;

    // Sin árbol montado todavía no sabemos dónde está el router: se trata como
    // "sin sesión" (tope corto), que es el caso del arranque en frío.
    var espera = EsperaDePush.sinSesion;
    GoRouter? router;
    BuildContext? ctx;

    final context = _navigatorKey?.currentContext;
    if (context != null && context.mounted) {
      final r = GoRouter.maybeOf(context);
      if (r != null) {
        router = r;
        ctx = context;
        espera = esperaPara(r.routerDelegate.currentConfiguration.uri.path);
      }
    }

    if (espera == EsperaDePush.navegar && router != null && ctx != null) {
      _pendingRoute = null;
      _pendingTimer?.cancel();
      _refrescarSiFidelizacion(ctx, route);
      _go(router, route);
      return;
    }

    // Cambiar de categoría (p. ej. /welcome → login → /pin) reinicia la
    // cuenta: los intentos gastados esperando otra cosa no cuentan.
    if (_ultimaEspera != espera) {
      _ultimaEspera = espera;
      _pendingTries = 0;
    }

    final tope = espera == EsperaDePush.gate
        ? _maxTriesEnGate
        : _maxTriesSinSesion;
    if (_pendingTries++ >= tope) {
      _pendingRoute = null;
      _pendingTimer?.cancel();
      _pendingTimer = null;
      return;
    }
    _pendingTimer = Timer(_esperaEntreIntentos, _tryNavigate);
  }

  static void _go(GoRouter router, String route) {
    try {
      final path = Uri.parse(route).path;
      // Ya estamos ahí: no apilar una segunda copia. Pasa con el deep link de
      // vuelta del checkout de Mercado Pago (la app ya empujó `/pago/<id>`
      // antes de abrir el navegador) y con un push de una pantalla abierta.
      if (router.routerDelegate.currentConfiguration.uri.path == path) return;
      if (_shellPaths.contains(path)) {
        router.go(route);
      } else {
        router.push(route);
      }
    } catch (e) {
      debugPrint('[push] navegación a $route falló: $e');
      try {
        router.go('/home');
      } catch (_) {}
    }
  }

  // ───────────────────────────────────────────────────────────────────────
  // Bandeja
  // ───────────────────────────────────────────────────────────────────────

  /// Marca una notificación como leída (`read_at` + `is_read`). Pasa por la
  /// RLS `cn_client_update`, así que sólo afecta filas del propio cliente.
  /// Tolera que la columna `read_at` todavía no exista (mig 193 pendiente):
  /// en ese caso escribe sólo `is_read`.
  static Future<void> markNotificationRead(String notificationId) async {
    final client = Supabase.instance.client;
    if (client.auth.currentSession == null) return;
    final now = DateTime.now().toUtc().toIso8601String();
    try {
      await client
          .from('client_notifications')
          .update({'is_read': true, 'read_at': now})
          .eq('id', notificationId);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST204' || e.code == '42703') {
        try {
          await client
              .from('client_notifications')
              .update({'is_read': true})
              .eq('id', notificationId);
        } catch (e2) {
          debugPrint('[push] markNotificationRead fallback: $e2');
        }
      } else {
        debugPrint('[push] markNotificationRead: ${e.message}');
      }
    } catch (e) {
      debugPrint('[push] markNotificationRead: $e');
    }
  }

  // ───────────────────────────────────────────────────────────────────────
  // Primer plano
  // ───────────────────────────────────────────────────────────────────────

  static void _onForegroundMessage(RemoteMessage message) {
    // iOS: el sistema dibuja el banner (setForegroundNotificationPresentation
    // Options). Android: notificación local en el canal `monaco_default`. La
    // bandeja in-app se actualiza sola por Realtime sobre client_notifications.
    unawaited(PushService.showForegroundNotification(message));
  }
}
