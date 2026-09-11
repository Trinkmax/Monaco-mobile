import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/theme/monaco_colors.dart';
import 'core/auth/install_guard.dart';
import 'core/auth/secure_local_storage.dart';
import 'core/auth/secure_storage.dart';
import 'core/deeplink/deep_link_handler.dart';
import 'core/push/push_handler.dart';
import 'core/push/push_service.dart';
import 'core/router/app_router.dart';
import 'core/utils/constants.dart';
import 'features/onboarding/presentation/screens/arranque_fallido_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  // Zona raíz: captura errores async no manejados (ej: AuthApiException que
  // dispara el recoverSession del supabase_flutter cuando el refresh_token
  // es inválido — ocurre de forma fire-and-forget dentro de un completer).
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Los tres caminos por los que un error puede escaparse (framework, motor,
    // zona) se enganchan ACÁ, antes de Firebase, y consultan `_crashlyticsListo`
    // en cada disparo. Reasignarlos después de `Firebase.initializeApp` dejaría
    // ciega justo la ventana del arranque, que es donde más se rompe.
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      if (_crashlyticsListo && !_isIgnorableAuthError(details.exception)) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      }
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      // Devolvemos `true` (= manejado) SIEMPRE, que es lo que pide Crashlytics
      // para no duplicar el reporte con el handler del motor. Como eso también
      // se come el volcado que antes hacía la plataforma, lo imprimimos
      // nosotros: sin Firebase configurado, este debugPrint es lo único que
      // queda del error.
      if (_isIgnorableAuthError(error)) return true;
      debugPrint('[platform] Uncaught error: $error\n$stack');
      _reportarCrash(error, stack);
      return true;
    };

    await initializeDateFormatting('es_AR');
    Intl.defaultLocale = 'es_AR';

    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: MonacoColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    // Firebase — si los options son placeholders (todavía no se corrió
    // `flutterfire configure`), salteamos la init: Firebase tira NSException
    // nativo que NO se captura con try/catch de Dart (mata el proceso).
    try {
      final opts = DefaultFirebaseOptions.currentPlatform;
      final isPlaceholder = opts.apiKey.startsWith('PLACEHOLDER') ||
          opts.appId.startsWith('PLACEHOLDER') ||
          opts.projectId.startsWith('PLACEHOLDER');
      if (isPlaceholder) {
        debugPrint('[main] Firebase skip: firebase_options.dart tiene placeholders. '
            'Ejecutá `flutterfire configure` para habilitar push.');
      } else {
        await Firebase.initializeApp(options: opts);
        _firebaseReady = true;
        await _prenderCrashlytics();
      }
    } catch (e, stack) {
      debugPrint('[main] Firebase.initializeApp falló: $e\n$stack');
    }

    await _arrancar();
  }, (error, stack) {
    if (_isIgnorableAuthError(error)) return;
    debugPrint('[zone] Uncaught error: $error\n$stack');
    _reportarCrash(error, stack);
  });
}

bool _firebaseReady = false;
bool _crashlyticsListo = false;

/// Prende la telemetría de crashes. Va en su propio `try` porque un fallo acá
/// **no puede** costarle el push a la app: `_firebaseReady` ya quedó en true y
/// `PushService.bootstrap()` tiene que correr igual.
///
/// En debug la recolección va apagada: los stacks de la Mac ensucian el panel
/// del dueño y encima llegan sin deofuscar.
Future<void> _prenderCrashlytics() async {
  try {
    await FirebaseCrashlytics.instance
        .setCrashlyticsCollectionEnabled(!kDebugMode);
    _crashlyticsListo = true;
  } catch (e) {
    debugPrint('[main] Crashlytics no arrancó: $e');
  }
}

/// Manda el error a Crashlytics si está disponible. Sin Firebase configurado
/// —el estado de hoy— no hace nada y el error queda sólo en el log.
void _reportarCrash(Object error, StackTrace? stack) {
  if (!_crashlyticsListo) return;
  unawaited(FirebaseCrashlytics.instance.recordError(error, stack, fatal: true));
}

/// Todo lo que viene después de Firebase: el guard de reinstalación, Supabase
/// y la app. Está separado de `main()` porque es lo que el botón "Reintentar"
/// de [ArranqueFallidoApp] vuelve a correr entero.
///
/// **Nunca pantalla negra.** Pase lo que pase, acá se llama a `runApp`: con
/// la app real si Supabase arrancó, o con una pantalla de error en español si
/// no. Antes, una excepción en `Supabase.initialize` (un blob del Keystore que
/// no se puede descifrar, típico tras un update de OS en Samsung/Xiaomi)
/// dejaba a `runApp` sin correr, y como el dato corrupto persiste, la app se
/// abría en negro en CADA intento hasta desinstalarla.
Future<void> _arrancar() async {
  // Reinstalación en iOS: el Keychain sobrevive a borrar la app. Si no está la
  // marca de instalación pero la caja fuerte tiene datos, son de la instalación
  // anterior y se borran ANTES de que Supabase lea la sesión.
  final guard = await InstallGuard.ejecutar();
  debugPrint('[main] install guard: ${guard.name}');

  try {
    await _inicializarSupabase();
  } catch (e, stack) {
    debugPrint('[main] Supabase no arrancó ni con el storage limpio: $e\n$stack');
    runApp(ArranqueFallidoApp(onReintentar: _arrancar));
    return;
  }

  // El navigator lo necesitan los push Y los deep links (la vuelta del
  // checkout de Mercado Pago), así que se registra siempre: hoy Firebase
  // está sin configurar y sin esta línea los deep links no navegarían.
  PushHandler.setNavigatorKey(rootNavigatorKey);
  if (_firebaseReady) {
    await PushService.bootstrap();
    PushHandler.init();
  }

  // `monaco://pago?deposit=<id>` — best-effort: si nunca llega, el cliente
  // igual encuentra su pago en Mis turnos.
  unawaited(DeepLinkHandler.init());

  runApp(const ProviderScope(child: MonacoApp()));
}

/// `Supabase.initialize` con UN reintento tras limpiar el almacenamiento
/// seguro. Si el segundo intento también falla, propaga y `_arrancar` muestra
/// la pantalla de error.
///
/// La lectura de prueba ([SecureLocalStorage.comprobarLectura]) va ANTES de
/// `Supabase.initialize` a propósito: `initialize` marca la instancia como
/// inicializada antes de leer la sesión, así que si reventara adentro, un
/// segundo `initialize` devolvería esa instancia a medias sin volver a
/// intentar nada. Probando el storage primero, el reintento real es posible.
Future<void> _inicializarSupabase() async {
  Future<void> intento() async {
    await SecureLocalStorage.comprobarLectura();
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      // `anonKey` quedó deprecado en supabase_flutter 2.13+; el parámetro
      // nuevo es un rename puro (`publishableKey ?? anonKey`) y acepta la
      // misma clave anon legacy que ya usamos.
      publishableKey: AppConstants.supabaseAnonKey,
      authOptions: FlutterAuthClientOptions(
        localStorage: SecureLocalStorage(),
        autoRefreshToken: true,
        // La app NO usa OAuth de Supabase por deep link: Google y Apple van
        // por `client-auth` con el `id_token`, y el único deep link propio es
        // `monaco://pago?deposit=<id>`. Con el observer prendido,
        // `supabase_flutter` abría un segundo `AppLinks` sobre el mismo canal
        // y trataba como callback de auth cualquier link con `code` o
        // `error_description` — una clase entera de conflictos que no tiene
        // por qué existir.
        detectSessionInUri: false,
      ),
    );
  }

  try {
    await intento();
    return;
  } catch (e, stack) {
    debugPrint('[main] Supabase.initialize falló, limpio el storage y '
        'reintento: $e\n$stack');
  }

  // Un Keystore/Keychain que no se puede descifrar no se arregla solo: lo que
  // hay adentro ya no sirve. Se borra y el cliente vuelve a entrar con el
  // código (comportamiento aceptado). Cada borrado es best-effort: si uno
  // falla, el otro igual se intenta.
  try {
    await SecureLocalStorage.borrarSesionGuardada();
  } catch (e) {
    debugPrint('[main] no se pudo borrar la sesión guardada: $e');
  }
  try {
    await SecureStorageService.clearAll();
  } catch (e) {
    debugPrint('[main] no se pudo limpiar el storage seguro: $e');
  }

  await intento();
}

/// Un refresh token revocado/inexistente no es fatal: el AuthNotifier se
/// encarga de limpiar la sesión y mandar al usuario a /welcome.
bool _isIgnorableAuthError(Object error) {
  if (error is AuthApiException) {
    final code = error.code;
    if (code == 'refresh_token_not_found' ||
        code == 'refresh_token_already_used' ||
        code == 'invalid_refresh_token') {
      return true;
    }
    final msg = error.message.toLowerCase();
    if (msg.contains('refresh token')) return true;
  }
  return false;
}
