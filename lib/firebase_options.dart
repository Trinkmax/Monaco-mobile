// Configuración de Firebase — generada por `flutterfire configure` el 18/9/2026
// contra el proyecto `monaco-barber-studio` (apps iOS y Android registradas).
// Los valores de abajo son REALES: `main.dart` inicializa Firebase y con eso
// hay push (FCM) y Crashlytics.
//
// Cómo se regenera (si cambia el proyecto o se suma una plataforma):
//
//   flutterfire configure --project=monaco-barber-studio \
//       --platforms=ios,android \
//       --ios-bundle-id=com.monacobarber.monacoMobile \
//       --android-package-name=com.monacobarber.monaco_mobile \
//       --ios-target=Runner --ios-out=ios/Runner/GoogleService-Info.plist \
//       --android-out=android/app/google-services.json \
//       --yes --overwrite-firebase-options
//
//   Sin `--ios-out`/`--android-out` el CLI pregunta el path y, corrido sin
//   terminal interactiva, muere con un RangeError. Y CONSERVA los comentarios
//   de este archivo al reescribirlo: por eso el preflight mira los valores
//   (`apiKey`/`appId`/`projectId`) y no la palabra PLACEHOLDER.
//
// Lo que el CLI dejó además de este archivo:
//   - `ios/Runner/GoogleService-Info.plist`, agregado al target Runner como
//     recurso, y un build phase "FlutterFire: flutterfire
//     upload-crashlytics-symbols" que sube los dSYM a Crashlytics en cada
//     archive (busca `flutterfire` en `$HOME/.pub-cache/bin`; está en el PATH
//     del script).
//   - `android/app/google-services.json`: `build.gradle.kts` aplica
//     `google-services` y `firebase-crashlytics` sólo si este archivo existe.
//   - `firebase.json` en la raíz, con el mapeo app ↔ archivo.
//
// Lo que sigue siendo del dueño y no es código (PUBLICAR.md, Parte 4):
//   - subir la APNs Auth Key `62X53C5773` en Firebase → Cloud Messaging →
//     Apple app configuration: sin eso el push en iOS no sale;
//   - Service accounts → Generate new private key → secret
//     `FCM_SERVICE_ACCOUNT_JSON` de la edge function `send-push` (acepta el
//     JSON crudo o en base64, `parseServiceAccountJson`). Sin él la función
//     marca `failed "FCM no configurado"` y no tira;
//   - si FCM contesta 403 PERMISSION_DENIED, darle a la service account el
//     rol "Firebase Cloud Messaging API Admin" en Google Cloud.
//
// Volver al modo sin Firebase (no debería hacer falta): `main.dart` saltea
// `Firebase.initializeApp` cuando `apiKey`/`appId`/`projectId` empiezan con
// `PLACEHOLDER`, y Perfil/Preferencias esconden el bloque de notificaciones
// del sistema.
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

  /// Valores reales del proyecto `monaco-barber-studio` (18/9/2026). Si alguno
  /// vuelve a empezar con `PLACEHOLDER`, `main.dart` no inicializa Firebase: se
  /// regenera con `flutterfire configure`, no se edita a mano.

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAE0aBl1cmsZHxScMiNNAhDaYAvTKLU748',
    appId: '1:124357327492:ios:76034a674967a3e1a7a0d1',
    messagingSenderId: '124357327492',
    projectId: 'monaco-barber-studio',
    storageBucket: 'monaco-barber-studio.firebasestorage.app',
    iosBundleId: 'com.monacobarber.monacoMobile',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAJ7NMopr8ksnmvDMrldqZ8h6xyLsKm_pQ',
    appId: '1:124357327492:android:f3f49466f348ace7a7a0d1',
    messagingSenderId: '124357327492',
    projectId: 'monaco-barber-studio',
    storageBucket: 'monaco-barber-studio.firebasestorage.app',
  );
}
