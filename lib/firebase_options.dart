// PLACEHOLDER — lo reemplaza `flutterfire configure` antes del primer release
// con push. Mientras tenga estos valores:
//
//   - `main.dart` detecta los `PLACEHOLDER_*` y SALTEA `Firebase.initializeApp`
//     (inicializar con options falsas tira una NSException nativa en iOS que
//     no se puede atrapar desde Dart).
//   - `PushService` / `PushHandler` consultan `Firebase.apps.isEmpty` y no
//     hacen nada: no se pide permiso, no se registra token, no se rutea nada.
//   - Las pantallas de Perfil y Preferencias muestran "No disponible en esta
//     versión" en el bloque de notificaciones del sistema.
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
//      `ios/Runner/GoogleService-Info.plist` (agregarlo al target Runner en
//      Xcode si el CLI no lo hizo) y `android/app/google-services.json`.
//   4. Android: plugin `com.google.gms.google-services` en
//      `android/settings.gradle.kts` (`apply false`) y en
//      `android/app/build.gradle.kts`; en `AndroidManifest.xml`:
//        <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
//        <meta-data android:name="com.google.firebase.messaging.default_notification_channel_id"
//                   android:value="monaco_default"/>
//      (el canal `monaco_default` lo crea `PushService.bootstrap()`).
//   5. iOS: `Runner.entitlements` (Debug) con `aps-environment = development`;
//      Release ya tiene `RunnerRelease.entitlements` con `production`.
//   6. Backend: cargar `FCM_SERVICE_ACCOUNT_JSON` (service account del MISMO
//      proyecto Firebase) como secreto de la edge function `send-push`.
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
