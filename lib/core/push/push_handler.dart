import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'push_service.dart';

/// Resuelve qué hacer con un push: a dónde navegar y qué marcar como leído.
///
/// Contrato del payload (CONTRACTS.md §6.7), todo string:
/// `data = { type, value?, deep_link?, notification_id? }`.
/// - Si viene `deep_link` y es un path interno (empieza con `/`), gana.
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

  /// Rutas que viven en el shell con dock: se navegan con `go` (reemplazan la
  /// pestaña) y no con `push` (que las apilaría sin dock).
  static const Set<String> _shellPaths = {
    '/home',
    '/turnos',
    '/occupancy',
    '/rewards',
    '/profile',
  };

  /// Mientras el router esté en alguna de estas rutas, no se puede navegar
  /// todavía (la sesión se está resolviendo o no hay sesión).
  static const Set<String> _notReadyPaths = {
    '/splash',
    '/welcome',
    '/login',
    '/login/codigo',
    '/login/nombre',
    '/biometric',
    '/pin',
  };

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
  static String routeFor({String? deepLink, String? type, String? value}) {
    if (isInternalPath(deepLink)) return deepLink!.trim();
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

  /// Navega con el navigator raíz. Si el árbol todavía no está listo (push
  /// que abre la app), guarda la ruta y reintenta hasta ~20 s.
  static void navigateTo(String route) {
    _pendingRoute = route;
    _pendingTries = 0;
    _pendingTimer?.cancel();
    _tryNavigate();
  }

  static void _tryNavigate() {
    final route = _pendingRoute;
    if (route == null) return;

    final context = _navigatorKey?.currentContext;
    if (context != null && context.mounted) {
      final router = GoRouter.maybeOf(context);
      if (router != null) {
        final current = router.routerDelegate.currentConfiguration.uri.path;
        if (!_notReadyPaths.contains(current)) {
          _pendingRoute = null;
          _pendingTimer?.cancel();
          _go(router, route);
          return;
        }
      }
    }

    // Todavía no: reintentar (40 × 500 ms = 20 s; después se descarta, que
    // es lo que pasa si el cliente no tiene sesión y se queda en /welcome).
    if (_pendingTries++ >= 40) {
      _pendingRoute = null;
      return;
    }
    _pendingTimer = Timer(const Duration(milliseconds: 500), _tryNavigate);
  }

  static void _go(GoRouter router, String route) {
    try {
      final path = Uri.parse(route).path;
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
