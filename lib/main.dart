import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/app.dart';
import 'core/utils/constants.dart';
import 'firebase_options.dart';

Future<void> main() async {
  // Zona raíz: captura errores async no manejados (ej: AuthApiException que
  // dispara el recoverSession del supabase_flutter cuando el refresh_token
  // es inválido — ocurre de forma fire-and-forget dentro de un completer).
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Errores del framework
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
    };

    // Errores async de la plataforma (Flutter 3.3+)
    PlatformDispatcher.instance.onError = (error, stack) {
      return _isIgnorableAuthError(error);
    };

    await initializeDateFormatting('es');

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF242424),
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    // Firebase — si los options son placeholders (flutterfire configure no corrió),
    // saltamos la init porque Firebase tira NSException nativo que NO puede
    // capturarse con try/catch de Dart (hace crash el proceso).
    try {
      final opts = DefaultFirebaseOptions.currentPlatform;
      final isPlaceholder = opts.apiKey.startsWith('PLACEHOLDER') ||
          opts.appId.startsWith('PLACEHOLDER') ||
          opts.projectId.startsWith('PLACEHOLDER');
      if (isPlaceholder) {
        debugPrint(
          '[main] Firebase skip: firebase_options.dart tiene placeholders. '
          'Ejecutá `flutterfire configure` para habilitar push notifications.',
        );
      } else {
        await Firebase.initializeApp(options: opts);
      }
    } catch (e, stack) {
      debugPrint('[main] Firebase.initializeApp falló: $e\n$stack');
    }

    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
    );

    runApp(const ProviderScope(child: MonacoApp()));
  }, (error, stack) {
    if (_isIgnorableAuthError(error)) return;
    debugPrint('[zone] Uncaught error: $error\n$stack');
  });
}

/// Un refresh token revocado/inexistente no es fatal: el AuthNotifier se
/// encarga de limpiar la sesión y mandar al usuario a /welcome. Silenciamos
/// el stack para que no aparezca como "Unhandled Exception".
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
