// PLACEHOLDER — lo reemplaza `flutterfire configure` antes del primer release
// con push. Mientras tenga estos valores:
//
//   - `main.dart` detecta los `PLACEHOLDER_*` y SALTEA `Firebase.initializeApp`
//     (inicializar con options falsas tira una NSException nativa en iOS que
//     no se puede atrapar desde Dart).
//   - `PushService` / `PushHandler` consultan `Firebase.apps.isEmpty` y no
//     hacen nada: no se pide permiso, no se registra token, no se rutea nada.
//   - Perfil y Preferencias **ocultan** el bloque de notificaciones del
//     sistema (la bandeja in-app y los toggles por tipo siguen a la vista):
//     un interruptor que no se puede prender es contenido de relleno y App
//     Review lo rechaza por la 2.1.
//
// Para habilitar push de verdad (una sola vez, lo hace el dueño):
//
//   1. Crear el proyecto en https://console.firebase.google.com (o usar uno
//      existente) y registrar las dos apps:
//        - iOS:     bundle id `com.monacobarber.monacoMobile`
//        - Android: applicationId `com.monacobarber.monaco_mobile`
//   2. En el proyecto Firebase → Cloud Messaging → Apple app configuration:
//      subir la APNs Auth Key (.p8) de la cuenta de Apple Developer PAGA
//      (con Personal Team no hay APNs: ver CLAUDE.md de Monaco-mobile).
//   3. En esta carpeta:
//        dart pub global activate flutterfire_cli
//        flutterfire configure --project=<firebase-project-id> \
//            --platforms=ios,android \
//            --ios-bundle-id=com.monacobarber.monacoMobile \
//            --android-package-name=com.monacobarber.monaco_mobile
//      Eso sobreescribe ESTE archivo con los valores reales y deja
//      `ios/Runner/GoogleService-Info.plist` y `android/app/google-services.json`.
//      Dos cosas del CLI que conviene mirar en el `git diff` antes de commitear:
//        - agrega al target Runner un build phase "FlutterFire: flutterfire
//          bundle-service-file" que necesita `flutterfire` en el PATH del build.
//          Si falla, se puede borrar: en iOS la init es por Dart
//          (`DefaultFirebaseOptions`), el plist es opcional.
//        - puede volver a inyectar `com.google.gms.google-services` en
//          `android/settings.gradle.kts` / `android/app/build.gradle.kts`. Este
//          repo ya lo declara y lo aplica SÓLO si existe `google-services.json`;
//          si el CLI lo duplica o lo aplica siempre, dejar la forma del repo.
//   4. Android: **no hay que tocar el manifest**. `POST_NOTIFICATIONS`, el
//      `default_notification_channel_id = monaco_default`, el ícono
//      `@drawable/ic_notification` y el color ya están declarados.
//   5. iOS: `Runner.entitlements` (Debug) con `aps-environment = development`;
//      Release ya tiene `RunnerRelease.entitlements` con `production`.
//   6. Backend, y son TRES cosas, no una:
//        - en Google Cloud (mismo proyecto): habilitar "Firebase Cloud
//          Messaging API (V1)";
//        - darle a la service account el rol "Firebase Cloud Messaging API
//          Admin". Sin eso FCM contesta 403 PERMISSION_DENIED, que
//          `classifyFcmResponse` clasifica como `fatal` y deja la fila de
//          `push_outbox` en `failed` sin reintento;
//        - cargar `FCM_SERVICE_ACCOUNT_JSON` como secreto de la edge function
//          `send-push`. Acepta el JSON crudo **o en base64**
//          (`parseServiceAccountJson`), que es lo cómodo para
//          `supabase secrets set`.
//
// Trampa al terminar: si `google-services.json` y este archivo difieren en
// `apiKey` o `storageBucket`, `Firebase.initializeApp` TIRA (chequeo de
// firebase_core contra la app nativa por default) y `main.dart` se lo come con
// un `debugPrint` — o sea, push apagado y la app funcionando. Después de correr
// el CLI, arrancar con `flutter run` y confirmar que NO aparece
// "[main] Firebase.initializeApp falló".
//
// Nada del código Dart cambia: el contrato del payload y el registro del token
// ya están implementados en `lib/core/push/`.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions no está configurado para web. '
        'Ejecutá `flutterfire configure` para generar este archivo.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions no soporta esta plataforma. '
          'Ejecutá `flutterfire configure`.',
        );
    }
  }

  /// Placeholders: `main.dart` los reconoce por el prefijo `PLACEHOLDER` y no
  /// inicializa Firebase. NO borrar el prefijo a mano: si se quiere probar
  /// push, hay que correr `flutterfire configure`.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'PLACEHOLDER_IOS_API_KEY',
    appId: 'PLACEHOLDER_IOS_APP_ID',
    messagingSenderId: 'PLACEHOLDER_SENDER_ID',
    projectId: 'PLACEHOLDER_PROJECT_ID',
    storageBucket: 'PLACEHOLDER_PROJECT_ID.appspot.com',
    iosBundleId: 'com.monacobarber.monacoMobile',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'PLACEHOLDER_ANDROID_API_KEY',
    appId: 'PLACEHOLDER_ANDROID_APP_ID',
    messagingSenderId: 'PLACEHOLDER_SENDER_ID',
    projectId: 'PLACEHOLDER_PROJECT_ID',
    storageBucket: 'PLACEHOLDER_PROJECT_ID.appspot.com',
  );
}
