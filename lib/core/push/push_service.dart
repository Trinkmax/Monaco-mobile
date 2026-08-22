import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../firebase_options.dart';
import '../api/mobile_api.dart';
import '../auth/secure_storage.dart';
import '../utils/constants.dart';
import 'push_handler.dart';

/// Handler de mensajes en background / app cerrada. Tiene que ser función
/// top-level (el isolate de background no comparte memoria con la app).
///
/// No hace nada más que asegurar Firebase: la notificación visible la dibuja el
/// sistema a partir del bloque `notification` del payload, y el tap se
/// resuelve en [PushHandler] cuando la app vuelve al frente.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint('[push] background init falló: $e');
  }
}

/// Registro del dispositivo para push (FCM) y notificaciones locales.
///
/// Contrato (CONTRACTS.md §1.2 / §6.7):
/// - el token se registra con `POST /api/mobile/push/token`
///   `{ token, platform, device_id, app_version }` (upsert por `(client_id,
///   device_id)` del lado del server, con el JWT del cliente);
/// - al cerrar sesión se da de baja con `DELETE /api/mobile/push/token`
///   `{ device_id }` — **antes** del `signOut`, porque necesita el Bearer;
/// - Todo el servicio tolera que Firebase no esté configurado
///   (`firebase_options.dart` en placeholders): cada método devuelve sin hacer
///   nada y sin tirar.
///
/// El permiso del sistema NUNCA se pide solo: la UI muestra primero un
/// pre-prompt contextual (Apple 4.5.4) y recién entonces llama a
/// [requestPermission]. Lo que sí hace solo el servicio es re-registrar el
/// token en cada arranque/login si el permiso ya estaba concedido
/// (higiene: reactiva tokens que el sender haya apagado por un error
/// transitorio y actualiza `app_version`/`last_seen_at`).
class PushService {
  PushService._();

  static const String _tokenPath = '/api/mobile/push/token';

  /// Cada cuánto re-enviamos el mismo token aunque no haya cambiado
  /// (`last_seen_at` del lado del server).
  static const Duration _reRegisterEvery = Duration(hours: 12);

  static bool _bootstrapped = false;
  static bool _localReady = false;
  static StreamSubscription<String>? _refreshSub;
  static StreamSubscription<AuthState>? _authSub;
  static String? _lastRegisteredToken;
  static DateTime? _lastRegisteredAt;
  static Future<void>? _inFlight;
  static MobileApi? _api;

  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  /// `true` si `Firebase.initializeApp` corrió (o sea, si hay options reales).
  static bool get isAvailable => Firebase.apps.isNotEmpty;

  static FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  static MobileApi get _mobileApi =>
      _api ??= MobileApi(Supabase.instance.client);

  // ───────────────────────────────────────────────────────────────────────
  // Arranque
  // ───────────────────────────────────────────────────────────────────────

  /// Llamar una vez desde `main()` DESPUÉS de `Firebase.initializeApp` y de
  /// `Supabase.initialize`. Registra el handler de background, configura cómo
  /// se muestran las notificaciones con la app abierta (iOS: banner del
  /// sistema; Android: canal `monaco_default` + notificación local) y engancha
  /// el registro del token al ciclo de sesión de Supabase.
  static Future<void> bootstrap() async {
    if (!isAvailable || _bootstrapped) return;
    _bootstrapped = true;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    try {
      // iOS: que el sistema dibuje el banner aunque la app esté en primer
      // plano. En Android esto no aplica (lo resuelve la notificación local).
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('[push] setForegroundNotificationPresentationOptions: $e');
    }

    await _ensureLocalNotifications();

    // Registro automático cuando aparece una sesión (cold start con sesión
    // guardada, login). El `signedOut` sólo limpia memoria: la baja del token
    // la hace `unregister()` ANTES del signOut, porque necesita el JWT.
    try {
      final auth = Supabase.instance.client.auth;
      _authSub?.cancel();
      _authSub = auth.onAuthStateChange.listen((data) {
        switch (data.event) {
          case AuthChangeEvent.initialSession:
          case AuthChangeEvent.signedIn:
            if (data.session != null) unawaited(ensureRegistered());
            break;
          case AuthChangeEvent.signedOut:
            _lastRegisteredToken = null;
            _lastRegisteredAt = null;
            break;
          default:
            break;
        }
      });
      if (auth.currentSession != null) unawaited(ensureRegistered());
    } catch (e) {
      debugPrint('[push] no se pudo escuchar el auth state: $e');
    }
  }

  /// Inicializa `flutter_local_notifications` y crea el canal Android
  /// `monaco_default` (el mismo `channel_id` que manda la edge function
  /// `send-push`). Idempotente.
  static Future<void> _ensureLocalNotifications() async {
    if (_localReady) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      // Los permisos de iOS los pide `FirebaseMessaging.requestPermission`
      // (con el pre-prompt); acá no hay que volver a pedirlos.
      const ios = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _local.initialize(
        const InitializationSettings(android: android, iOS: ios),
        onDidReceiveNotificationResponse: _onLocalNotificationTap,
      );
      if (Platform.isAndroid) {
        await _local
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.createNotificationChannel(
              const AndroidNotificationChannel(
                AppConstants.androidNotificationChannelId,
                AppConstants.androidNotificationChannelName,
                description: 'Turnos, premios y novedades de Monaco',
                importance: Importance.high,
              ),
            );
      }
      _localReady = true;
    } catch (e) {
      debugPrint('[push] init de notificaciones locales falló: $e');
    }
  }

  /// Tap sobre una notificación local (Android en primer plano): el payload
  /// es el `data` del push serializado en JSON.
  static void _onLocalNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        PushHandler.handleData(Map<String, dynamic>.from(decoded));
      }
    } catch (e) {
      debugPrint('[push] payload local inválido: $e');
    }
  }

  /// Muestra una notificación local para un push recibido con la app
  /// abierta. Sólo Android: en iOS el banner lo dibuja el sistema gracias a
  /// `setForegroundNotificationPresentationOptions`.
  static Future<void> showForegroundNotification(RemoteMessage message) async {
    if (!Platform.isAndroid) return;
    final n = message.notification;
    final title = n?.title ?? (message.data['title'] as String?);
    final body = n?.body ?? (message.data['body'] as String?);
    if (title == null && body == null) return;
    await _ensureLocalNotifications();
    if (!_localReady) return;
    try {
      final id =
          (message.messageId?.hashCode ??
              DateTime.now().millisecondsSinceEpoch) &
          0x7fffffff;
      await _local.show(
        id,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            AppConstants.androidNotificationChannelId,
            AppConstants.androidNotificationChannelName,
            channelDescription: 'Turnos, premios y novedades de Monaco',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        payload: jsonEncode(message.data),
      );
    } catch (e) {
      debugPrint('[push] no se pudo mostrar la notificación local: $e');
    }
  }

  // ───────────────────────────────────────────────────────────────────────
  // Permiso del sistema
  // ───────────────────────────────────────────────────────────────────────

  /// Estado actual del permiso. `null` si Firebase no está configurado o el
  /// plugin falló (simulador sin APNs, etc.).
  static Future<AuthorizationStatus?> currentAuthorizationStatus() async {
    if (!isAvailable) return null;
    try {
      final settings = await _messaging.getNotificationSettings();
      return settings.authorizationStatus;
    } catch (e) {
      debugPrint('[push] getNotificationSettings: $e');
      return null;
    }
  }

  static bool isGranted(AuthorizationStatus? status) =>
      status == AuthorizationStatus.authorized ||
      status == AuthorizationStatus.provisional;

  /// Dispara el prompt nativo (iOS / Android 13+). Llamar SOLO después del
  /// pre-prompt contextual de la UI (Apple 4.5.4). Si el usuario acepta,
  /// registra el token en el acto. Devuelve el estado resultante (`null` si
  /// Firebase no está configurado).
  static Future<AuthorizationStatus?> requestPermission() async {
    if (!isAvailable) return null;
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      if (isGranted(settings.authorizationStatus)) {
        await ensureRegistered(force: true);
      }
      return settings.authorizationStatus;
    } catch (e) {
      debugPrint('[push] requestPermission: $e');
      return null;
    }
  }

  /// Abre la pantalla de ajustes de la app (iOS). En Android no hay un
  /// esquema de URL estándar: devuelve `false` y la UI explica el camino.
  static Future<bool> openSystemSettings() async {
    try {
      if (Platform.isIOS) {
        return await launchUrl(Uri.parse('app-settings:'));
      }
    } catch (e) {
      debugPrint('[push] openSystemSettings: $e');
    }
    return false;
  }

  // ───────────────────────────────────────────────────────────────────────
  // Registro del token
  // ───────────────────────────────────────────────────────────────────────

  /// Si hay sesión y el permiso está concedido, obtiene el token FCM y lo
  /// registra en el server. Se desduplica: no re-envía el mismo token salvo
  /// que hayan pasado [_reRegisterEvery] o se pida `force`.
  static Future<void> ensureRegistered({bool force = false}) {
    final running = _inFlight;
    if (running != null) return running;
    final fut = _ensureRegistered(force: force).whenComplete(() {
      _inFlight = null;
    });
    _inFlight = fut;
    return fut;
  }

  static Future<void> _ensureRegistered({required bool force}) async {
    if (!isAvailable) return;
    if (Supabase.instance.client.auth.currentSession == null) return;

    final status = await currentAuthorizationStatus();
    if (!isGranted(status)) return;

    String? token;
    try {
      token = await _messaging.getToken();
    } catch (e) {
      // Simulador iOS sin APNs, o Firebase a medio configurar.
      debugPrint('[push] getToken: $e');
      return;
    }
    if (token == null || token.isEmpty) return;

    _refreshSub ??= _messaging.onTokenRefresh.listen(
      (t) => unawaited(_register(t, force: true)),
      onError: (Object e) => debugPrint('[push] onTokenRefresh: $e'),
    );

    await _register(token, force: force);
  }

  static Future<void> _register(String token, {required bool force}) async {
    final now = DateTime.now();
    final sameToken = token == _lastRegisteredToken;
    final fresh =
        _lastRegisteredAt != null &&
        now.difference(_lastRegisteredAt!) < _reRegisterEvery;
    if (!force && sameToken && fresh) return;

    try {
      final deviceId = await SecureStorageService.getOrCreateDeviceId();
      await _mobileApi.postJson(_tokenPath, {
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'device_id': deviceId,
        'app_version': await MobileApi.appVersion(),
      });
      _lastRegisteredToken = token;
      _lastRegisteredAt = now;
      debugPrint('[push] token registrado');
    } on MobileApiException catch (e) {
      // 401 = sesión vencida/cerrada: no hay nada que registrar.
      debugPrint('[push] registro falló (${e.code}): ${e.message}');
    } catch (e) {
      debugPrint('[push] registro falló: $e');
    }
  }

  /// Da de baja el dispositivo (`is_active = false`). Llamar ANTES de
  /// `authNotifier.logout()`: el endpoint necesita el JWT del cliente.
  /// Best-effort: nunca tira.
  static Future<void> unregister() async {
    _refreshSub?.cancel();
    _refreshSub = null;
    _lastRegisteredToken = null;
    _lastRegisteredAt = null;
    if (!isAvailable) return;
    if (Supabase.instance.client.auth.currentSession == null) return;
    try {
      final deviceId = await SecureStorageService.getOrCreateDeviceId();
      await _mobileApi
          .deleteJson(_tokenPath, {'device_id': deviceId})
          .timeout(const Duration(seconds: 6));
      debugPrint('[push] token dado de baja');
    } catch (e) {
      debugPrint('[push] unregister falló: $e');
    }
  }
}

/// Estado del permiso de notificaciones del sistema. `null` = Firebase no
/// configurado (la UI lo muestra como "no disponible en esta versión").
/// Invalidarlo después de [PushService.requestPermission] o al volver de
/// Ajustes.
final pushPermissionProvider = FutureProvider.autoDispose<AuthorizationStatus?>(
  (ref) async {
    return PushService.currentAuthorizationStatus();
  },
);
