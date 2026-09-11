import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme/monaco_colors.dart';
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

/// Ícono chico de las notificaciones (barra de estado). Android lo dibuja como
/// **máscara alfa**: un ícono a color se ve como un cuadrado blanco. Por eso NO
/// va `@mipmap/ic_launcher` (adaptativo, con fondo opaco) sino la silueta
/// blanca `res/drawable-*/ic_notification.png`, que es la misma que ya declara
/// el manifest para los push que dibuja FCM con la app cerrada
/// (`com.google.firebase.messaging.default_notification_icon`). Sin esto, el
/// mismo push se veía distinto según la app estuviera abierta o no.
///
/// `res/raw/keep.xml` conserva el drawable ante `shrinkResources`.
const String _iconoNotificacionAndroid = '@drawable/ic_notification';

/// Estado del permiso de notificaciones tal como lo necesita la UI.
///
/// **No es lo mismo que [AuthorizationStatus]**, y esa confusión era un bug:
/// en Android el plugin de FCM no tiene `notDetermined` — `getPermissions()`
/// devuelve `areNotificationsEnabled ? 1 : 0` y el mapeo Dart convierte el 0
/// en [AuthorizationStatus.denied]. O sea que **una instalación limpia de
/// Android 13+ ya se lee `denied`**, y la app lo trataba como "bloqueado en el
/// sistema": nunca llamaba a `requestPermission()`, el diálogo de
/// POST_NOTIFICATIONS no aparecía jamás y no se registraba ningún token.
///
/// La única señal confiable de "bloqueado" en Android es haber pedido el
/// permiso de verdad y seguir en `denied`; por eso el pedido deja una marca
/// ([_PermisoPedido]).
enum PushPermiso {
  /// Firebase sin configurar (`firebase_options.dart` en placeholders): no hay
  /// nada que mostrar. La UI **oculta** la sección entera.
  noDisponible,

  /// `authorized` o `provisional`.
  concedido,

  /// Todavía no se disparó el prompt del sistema: el botón dice "Activar".
  sinPedir,

  /// Se pidió y el sistema dijo que no (o el cliente lo apagó desde Ajustes):
  /// el prompt nativo ya no vuelve a aparecer, hay que ir a Ajustes.
  bloqueado,

  /// El plugin no contestó (simulador de iOS sin APNs, Firebase a medias).
  desconocido,
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
///
/// **Pendiente conocido — badge de iOS.** `send-push` manda
/// `apns.payload.aps.badge` con la cantidad de notificaciones sin leer, pero la
/// app no puede ponerlo en 0 al abrir la bandeja: `firebase_messaging` no
/// expone el badge y `flutter_local_notifications` tampoco lo hace en iOS
/// (`DarwinNotificationDetails.badgeNumber` sólo sirve para una notificación
/// que la app misma programe). Resolverlo pide un MethodChannel en
/// `AppDelegate.swift` (`UNUserNotificationCenter.setBadgeCount` en iOS 16+,
/// `applicationIconBadgeNumber` antes) o una dependencia nueva, las dos cosas
/// fuera de Dart. Hasta entonces el número del ícono queda hasta el push
/// siguiente. Anotado también en el README.
class PushService {
  PushService._();

  static const String _tokenPath = '/api/mobile/push/token';

  /// Cada cuánto re-enviamos el mismo token aunque no haya cambiado
  /// (`last_seen_at` del lado del server).
  static const Duration _reRegisterEvery = Duration(hours: 12);

  /// Intentos de `getToken()`. En iOS el primero suele fallar con
  /// `apns-token-not-set` si APNs todavía no contestó (pasa justo cuando el
  /// cliente acaba de aceptar el prompt, que es el peor momento para perderlo).
  static const int _intentosDeToken = 3;

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

    // El listener del token va ANTES de cualquier `getToken()`: en iOS el
    // primer `getToken()` puede fallar con `apns-token-not-set` y el token
    // real llega después por este stream. Enganchándolo recién después de un
    // `getToken()` exitoso, ese token se perdía hasta el próximo arranque en
    // frío — el cliente veía "Activadas" y no le llegaba ningún recordatorio.
    _escucharTokenRefresh();

    // Registro automático cuando aparece una sesión (cold start con sesión
    // guardada, login). El `signedOut` sólo limpia memoria: la baja del token
    // la hace `unregister()` ANTES del signOut, porque necesita el JWT.
    try {
      final auth = Supabase.instance.client.auth;
      await _authSub?.cancel();
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
      const android = AndroidInitializationSettings(_iconoNotificacionAndroid);
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
            icon: _iconoNotificacionAndroid,
            // El `default_notification_color` del manifest sólo tiñe lo que
            // dibuja FCM; la notificación local lleva el suyo.
            color: MonacoColors.monacoGreen,
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

  /// Estado crudo del plugin. `null` si Firebase no está configurado o el
  /// plugin falló (simulador sin APNs, etc.). Para la UI usar [currentPermiso]:
  /// este valor NO alcanza para decidir si el permiso está bloqueado.
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

  /// Traduce el estado crudo del plugin + la marca de "ya lo pedimos" al
  /// estado que la UI sabe dibujar. Pura, para poder testearla sin plataforma.
  ///
  /// La regla que importa está en [PushPermiso]: en Android `denied` es el
  /// estado de fábrica, así que **sólo es "bloqueado" si ya se pidió**. En iOS
  /// el estado de fábrica es `notDetermined`, así que un `denied` siempre
  /// implica un prompt ya contestado.
  @visibleForTesting
  static PushPermiso mapearPermiso({
    required bool disponible,
    required AuthorizationStatus? status,
    required bool yaSePidio,
    required bool esAndroid,
  }) {
    if (!disponible) return PushPermiso.noDisponible;
    if (isGranted(status)) return PushPermiso.concedido;
    if (status == null) return PushPermiso.desconocido;
    if (status == AuthorizationStatus.notDetermined) return PushPermiso.sinPedir;
    if (esAndroid && !yaSePidio) return PushPermiso.sinPedir;
    return PushPermiso.bloqueado;
  }

  /// Estado del permiso para la UI.
  static Future<PushPermiso> currentPermiso() async {
    if (!isAvailable) return PushPermiso.noDisponible;
    final status = await currentAuthorizationStatus();
    return mapearPermiso(
      disponible: true,
      status: status,
      yaSePidio: await _PermisoPedido.leer(),
      esAndroid: Platform.isAndroid,
    );
  }

  /// Dispara el prompt nativo (iOS / Android 13+). Llamar SOLO después del
  /// pre-prompt contextual de la UI (Apple 4.5.4). Si el cliente acepta,
  /// registra el token en el acto.
  ///
  /// En Android 13+ ésta es la ÚNICA forma de que aparezca el diálogo de
  /// POST_NOTIFICATIONS: `getNotificationSettings()` nunca lo dispara. Si el
  /// permiso ya está concedido es un no-op, y si está bloqueado contesta
  /// `denied` al instante sin mostrar nada — por eso la marca se escribe
  /// igual: es lo que después distingue "sin pedir" de "bloqueado".
  static Future<PushPermiso> requestPermission() async {
    if (!isAvailable) return PushPermiso.noDisponible;
    AuthorizationStatus? status;
    try {
      // Se marca ANTES de abrir el diálogo: si el proceso muere con el prompt
      // en pantalla, es preferible ofrecer Ajustes de más que dejar un botón
      // "Activar" que no vuelve a mostrar nada.
      await _PermisoPedido.marcar();
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      status = settings.authorizationStatus;
    } catch (e) {
      debugPrint('[push] requestPermission: $e');
      return PushPermiso.desconocido;
    }
    if (isGranted(status)) {
      await ensureRegistered(force: true);
    }
    return mapearPermiso(
      disponible: true,
      status: status,
      yaSePidio: true,
      esAndroid: Platform.isAndroid,
    );
  }

  /// Abre los ajustes de la app. iOS: `app-settings:`. Android: la ficha de la
  /// app (`ACTION_APPLICATION_DETAILS_SETTINGS`), desde donde se llega a
  /// Notificaciones — antes devolvía `false` y la UI sólo podía dictar el
  /// camino en un toast, que se lee como un botón roto.
  ///
  /// Se usa `Geolocator.openAppSettings()` porque es el único paquete YA
  /// instalado que expone ese intent (es genérico: abre la ficha de la app, no
  /// tiene nada de ubicación). Si algún día entra `permission_handler` o
  /// `app_settings` al pubspec, se reemplaza por su `openAppSettings()`.
  static Future<bool> openSystemSettings() async {
    if (Platform.isIOS) {
      try {
        if (await launchUrl(Uri.parse('app-settings:'))) return true;
      } catch (e) {
        debugPrint('[push] openSystemSettings (iOS): $e');
      }
    }
    try {
      return await Geolocator.openAppSettings();
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

    // El listener ya quedó armado en `bootstrap()`; se re-asegura acá por si
    // `requestPermission` corrió antes de que bootstrap terminara.
    _escucharTokenRefresh();

    final token = await _obtenerToken();
    if (token == null) return;

    await _register(token, force: force);
  }

  /// `getToken()` con reintentos cortos. En iOS falla con `apns-token-not-set`
  /// mientras FCM no tenga el token de APNs, que es exactamente la carrera que
  /// se abre cuando el cliente acaba de aceptar el prompt. Si igual no sale,
  /// no se pierde: el token llega después por `onTokenRefresh`.
  static Future<String?> _obtenerToken() async {
    for (var intento = 1; intento <= _intentosDeToken; intento++) {
      try {
        final token = await _messaging.getToken();
        if (token != null && token.isNotEmpty) return token;
      } catch (e) {
        debugPrint('[push] getToken ($intento/$_intentosDeToken): $e');
      }
      if (intento == _intentosDeToken) break;
      await Future<void>.delayed(Duration(seconds: intento));
    }
    return null;
  }

  /// Escucha `onTokenRefresh` una sola vez por proceso. El callback vuelve a
  /// chequear sesión y permiso: puede llegar en cualquier momento, incluso con
  /// el cliente deslogueado.
  static void _escucharTokenRefresh() {
    if (_refreshSub != null) return;
    try {
      _refreshSub = _messaging.onTokenRefresh.listen(
        (t) => unawaited(_registrarTokenRefrescado(t)),
        onError: (Object e) => debugPrint('[push] onTokenRefresh: $e'),
      );
    } catch (e) {
      debugPrint('[push] no se pudo escuchar onTokenRefresh: $e');
    }
  }

  static Future<void> _registrarTokenRefrescado(String token) async {
    if (token.isEmpty) return;
    if (Supabase.instance.client.auth.currentSession == null) return;
    if (!isGranted(await currentAuthorizationStatus())) return;
    await _register(token, force: true);
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
  ///
  /// **No** cancela `onTokenRefresh`: la suscripción es de por vida del
  /// proceso (se arma en `bootstrap()`) y su callback ya chequea sesión y
  /// permiso. Cancelándola acá, un cliente que cerraba sesión y volvía a
  /// entrar sin reiniciar la app se quedaba sin listener.
  static Future<void> unregister() async {
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

/// Marca "ya disparamos el prompt del sistema alguna vez", que es lo único que
/// distingue `sinPedir` de `bloqueado` en Android (ver [PushPermiso]).
///
/// Vive en la misma caja fuerte que el resto (`SecureStorageService` usa estas
/// mismas opciones), así el `InstallGuard` la limpia junto con todo lo demás
/// cuando detecta una reinstalación: cuenta nueva, prompt nuevo.
class _PermisoPedido {
  static const _key = 'push_permission_asked';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static bool? _cache;

  static Future<bool> leer() async {
    final cached = _cache;
    if (cached != null) return cached;
    try {
      final v = await _storage.read(key: _key);
      return _cache = v == 'true';
    } catch (e) {
      debugPrint('[push] no se pudo leer $_key: $e');
      return false;
    }
  }

  static Future<void> marcar() async {
    _cache = true;
    try {
      await _storage.write(key: _key, value: 'true');
    } catch (e) {
      debugPrint('[push] no se pudo guardar $_key: $e');
    }
  }
}

/// Estado del permiso de notificaciones del sistema.
/// [PushPermiso.noDisponible] = Firebase sin configurar: la UI **oculta** la
/// sección (no muestra una función "próximamente", que es rechazo de Apple
/// 2.1). Invalidarlo después de [PushService.requestPermission] o al volver de
/// Ajustes.
final pushPermisoProvider = FutureProvider.autoDispose<PushPermiso>((
  ref,
) async {
  return PushService.currentPermiso();
});
