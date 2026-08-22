# Monaco — app de clientes (Flutter)

App móvil de **Monaco Barber Studio** para sus clientes: puntos y premios, turnos nativos
(reservar, ver, cancelar), fila en vivo por sucursal, reseñas, cartelera, convenios y
notificaciones push. Comparte el backend Supabase con el dashboard
[`../MonacoSmartBarber`](../MonacoSmartBarber) y consume su API mobile (`/api/mobile/*`).

| | |
|---|---|
| Package | `monaco_mobile` |
| Flutter / Dart | 3.38.4 / 3.10.3 |
| Plataformas | iOS 14+ (sólo iPhone, vertical) · Android 7+ (minSdk 24, target 36) |
| Bundle / applicationId | `com.monacobarber.monacoMobile` / `com.monacobarber.monaco_mobile` |
| Nombre visible | **Monaco** |
| Backend | Supabase `gzsfoqpxvnwmvngfoqqk` + `https://monaco-smart-barber.vercel.app/api/mobile` |

## Correr

```bash
flutter pub get
flutter run                      # simulador o dispositivo conectado
flutter run --dart-define=API_BASE_URL=http://localhost:3000   # contra el dashboard local
```

Las constantes (`lib/core/utils/constants.dart`) tienen `defaultValue` con **producción**:
un build sin `--dart-define` apunta al proyecto real. Overrides disponibles:
`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `API_BASE_URL`, `ORGANIZATION_ID`, `ORGANIZATION_SLUG`.

## Calidad

```bash
dart analyze lib/ test/          # (si `flutter analyze` se cae, usar este)
flutter test                     # 166 tests: unit (API, auth, fechas, teléfono, modelos) + widget
```

## Íconos y splash

Los assets fuente están en `assets/brand/` (`app_icon.png`, `app_icon_foreground.png`,
`splash_logo.png`, 1024×1024). Los nativos se **regeneran**, no se editan a mano:

```bash
dart run flutter_launcher_icons          # iOS AppIcon.appiconset + Android mipmap/adaptive/monochrome
dart run flutter_native_splash:create    # LaunchScreen.storyboard + Android launch_background/values-v31
```

Después de `flutter_native_splash:create` revisar que `android/app/src/main/res/values*/styles.xml`
sigan con `NormalTheme` → `@color/monaco_background` (el tool sólo toca `LaunchTheme`).

## Push (Firebase Cloud Messaging)

El código ya está, Firebase **todavía no**: `lib/firebase_options.dart` tiene placeholders y
`main.dart` saltea `Firebase.initializeApp` mientras los detecte. Para activarlo:

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=<id-del-proyecto-firebase> \
  --ios-bundle-id=com.monacobarber.monacoMobile \
  --android-package-name=com.monacobarber.monaco_mobile
```

Eso reescribe `firebase_options.dart`, deja `android/app/google-services.json` y
`ios/Runner/GoogleService-Info.plist`. El Gradle aplica `com.google.gms.google-services`
**sólo si el JSON existe** (sin él la app compila igual, sin push). En iOS el plist es opcional
porque Firebase se inicializa con `firebase_options.dart`; APNs requiere además subir la
APNs key al proyecto Firebase y tener el Apple Developer Program pago (ver `ENTREGA.md`).

## Build y release

```bash
# Android — release firmado con android/key.properties (ver android/key.properties.example)
flutter build appbundle --release        # → build/app/outputs/bundle/release/app-release.aab
flutter build apk --release

# iOS — requiere Apple Developer Program (Team pago) para archivar y subir
flutter build ipa --release              # → build/ios/ipa/*.ipa

# iPhone físico con Apple ID gratuito (caduca a los 7 días)
./scripts/instalar-en-iphone.sh          # release; --debug para hot reload; --reinstalar sin recompilar
```

Sin `android/key.properties` el release Android se firma con la clave de **debug** (sirve para
probar, no para Play). La versión sale de `pubspec.yaml` (`version: x.y.z+build`).

## Estructura

```
lib/
├── app/            # MonacoApp, tema (MonacoColors/Typography/Theme), widgets Liquid Glass
├── core/           # api (MobileApi), auth (OTP + sesión segura), push, router, supabase, utils
└── features/       # onboarding, branch_selection, home, appointments, occupancy, points,
                    # rewards, catalog, reviews, billboard, convenios, visits, notifications, profile
```

Más detalle en `CLAUDE.md` (arquitectura, contratos, trampas) y `ENTREGA.md` (estado de entrega,
checklist de tiendas, pendientes del dueño).
