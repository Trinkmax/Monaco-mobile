import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/theme/monaco_colors.dart';
import 'core/auth/secure_local_storage.dart';
import 'core/push/push_handler.dart';
import 'core/push/push_service.dart';
import 'core/router/app_router.dart';
import 'core/utils/constants.dart';
import 'firebase_options.dart';

Future<void> main() async {
  // Zona raíz: captura errores async no manejados (ej: AuthApiException que
  // dispara el recoverSession del supabase_flutter cuando el refresh_token
  // es inválido — ocurre de forma fire-and-forget dentro de un completer).
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      return _isIgnorableAuthError(error);
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
    var firebaseReady = false;
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
        firebaseReady = true;
      }
    } catch (e, stack) {
      debugPrint('[main] Firebase.initializeApp falló: $e\n$stack');
    }

    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
      authOptions: FlutterAuthClientOptions(
        localStorage: SecureLocalStorage(),
        autoRefreshToken: true,
      ),
    );

    if (firebaseReady) {
      PushHandler.setNavigatorKey(rootNavigatorKey);
      await PushService.bootstrap();
      PushHandler.init();
    }

    runApp(const ProviderScope(child: MonacoApp()));
  }, (error, stack) {
    if (_isIgnorableAuthError(error)) return;
    debugPrint('[zone] Uncaught error: $error\n$stack');
  });
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
