# Monaco — app de clientes (Flutter)

App móvil de **Monaco Barber Studio** para sus clientes: puntos y premios, turnos nativos
(reservar, ver, cancelar), fila en vivo por sucursal, reseñas, cartelera, convenios y
notificaciones push. Comparte el backend Supabase con el dashboard
[`../MonacoSmartBarber`](../MonacoSmartBarber) y consume su API mobile (`/api/mobile/*`).

| | |
|---|---|
| Package | `monaco_mobile` |
| Flutter / Dart | 3.38.4 / 3.10.3 |
| Plataformas | iOS 15+ (sólo iPhone, vertical) · Android 7+ (minSdk 24, target 36) |
| Bundle / applicationId | `com.monacobarber.monacoMobile` / `com.monacobarber.monaco_mobile` |
| Nombre visible | **Monaco** en el teléfono · **Monaco Barber Studio** en las fichas de las tiendas |
| Backend | Supabase `gzsfoqpxvnwmvngfoqqk` + `https://monacobarber.vercel.app/api/mobile` |

**Para publicar**, el paso a paso está en [`PUBLICAR.md`](PUBLICAR.md) (cuentas, credenciales,
compilar y subir) y el material de las fichas en [`store/`](store/README.md). Este README es para
trabajar en la app.

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
dart analyze lib/ test/ integration_test/   # (si `flutter analyze` se cae, usar este)
flutter test                                # unit (API, auth, fechas, teléfono, modelos) + widget
```

La barra es **0 errores, 0 warnings y 0 infos**. Desde el 10/sep/2026 el baseline está
limpio: si `dart analyze` imprime algo, es nuevo. `analysis_options.yaml` explica qué reglas
están prendidas y —más importante— cuáles quedaron afuera a propósito, con la cuenta de
hallazgos que tendría cada una hoy.

`pubspec.lock` **se commitea**: esto es una app publicada, no un paquete. Sin el lock, dos
máquinas resuelven versiones distintas y el binario que sale de acá no es el que se probó.

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
`main.dart` saltea `Firebase.initializeApp` mientras los detecte. Con placeholders,
`PushService.isAvailable` es `false` y Perfil/Preferencias **ocultan** el bloque de notificaciones
del sistema (la bandeja in-app y los toggles por tipo siguen funcionando).

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=<id-del-proyecto-firebase> \
  --platforms=ios,android \
  --ios-bundle-id=com.monacobarber.monacoMobile \
  --android-package-name=com.monacobarber.monaco_mobile
```

Eso reescribe `firebase_options.dart`, deja `android/app/google-services.json` y
`ios/Runner/GoogleService-Info.plist`. Además:

- **Android no necesita ningún cambio a mano**: `POST_NOTIFICATIONS`, el
  `default_notification_channel_id = monaco_default`, el ícono `@drawable/ic_notification` y el
  color ya están en el manifest. El Gradle aplica `com.google.gms.google-services` **y
  `com.google.firebase.crashlytics`** sólo si el JSON existe (sin él la app compila igual, sin push
  y sin subida del mapping de R8). Revisar el `git diff` por si el CLI duplicó esa declaración.
- **iOS**: el CLI agrega al target Runner un build phase *"FlutterFire: flutterfire
  bundle-service-file"* que pide `flutterfire` en el PATH del build; si estorba se puede borrar,
  porque la init es por Dart y el `.plist` es opcional. Falta además `aps-environment = development`
  en `Runner.entitlements` (Debug); Release ya lo tiene en `production`. APNs pide subir la **APNs
  Auth Key (.p8)** al proyecto Firebase y tener el Apple Developer Program pago (ver `ENTREGA.md`).
- **Backend (`send-push`), tres cosas**: habilitar *Firebase Cloud Messaging API (V1)* en Google
  Cloud, darle a la service account el rol *Firebase Cloud Messaging API Admin* (sin eso FCM
  contesta 403 `PERMISSION_DENIED` y la fila de `push_outbox` queda `failed` sin reintento) y
  cargar `FCM_SERVICE_ACCOUNT_JSON` como secreto — acepta el JSON crudo **o en base64**, que es lo
  cómodo para `supabase secrets set`.
- **Chequeo final**: si `google-services.json` y `firebase_options.dart` difieren en `apiKey` o
  `storageBucket`, `Firebase.initializeApp` tira y `main.dart` se lo come con un `debugPrint`
  (push apagado, app andando). Arrancar con `flutter run` y confirmar que no aparece
  `[main] Firebase.initializeApp falló`.

### Pendientes conocidos de push

- **Badge de iOS**: `send-push` manda `aps.badge` con las no leídas, pero la app no lo puede poner
  en 0 al abrir la bandeja. Ni `firebase_messaging` ni `flutter_local_notifications` exponen el
  badge en iOS; hace falta un MethodChannel en `AppDelegate.swift`
  (`UNUserNotificationCenter.setBadgeCount` en iOS 16+, `applicationIconBadgeNumber` antes) o una
  dependencia nueva. Hasta entonces el número del ícono queda hasta el push siguiente.
- **Imagen de campaña en iOS**: `send-push` manda `notification.image`, pero iOS sólo la muestra si
  la app tiene un target **Notification Service Extension** (y el push, `mutable-content: 1`). El
  proyecto tiene un solo target, así que hoy la foto de una campaña **se ve sólo en Android**;
  en iPhone llega el texto. Agregar la extensión requiere Team pago y tocar el proyecto Xcode.
- **Abrir Ajustes en Android** usa `Geolocator.openAppSettings()` (intent genérico
  `ACTION_APPLICATION_DETAILS_SETTINGS`) porque es el único paquete ya instalado que lo expone. Si
  algún día entra `permission_handler` o `app_settings` al pubspec, reemplazarlo por su
  `openAppSettings()`.

## Build y release

**El camino para publicar es un solo comando:**

```bash
./scripts/crear-keystore.sh               # una vez en la vida de la app: la llave de firma de Play
cp .env.release.example .env.release      # una vez: client IDs de Google, Team ID, interruptores
./scripts/preflight-tiendas.sh            # ¿está todo? (no compila nada, se puede correr siempre)
./scripts/build-release.sh                # preflight + AAB + IPA, ofuscados
./scripts/build-release.sh android        # sólo una plataforma
./scripts/build-release.sh --dry          # imprime los comandos sin compilar
```

`scripts/crear-keystore.sh` genera el keystore en `~/.monaco-keys/`, **fuera de todo repo**, y por
un motivo concreto: el ejemplo viejo (`storeFile=../../monaco-release.jks`) lo mandaba a
`MSB_FULL/`, el directorio wrapper, que no tuvo `.gitignore` hasta el 10/sep/2026 — un `git add -A`
parado ahí se llevaba la clave de firma. (Ahora existe `MSB_FULL/.gitignore` como red, pero la
llave sigue yendo afuera.) El script escribe `android/key.properties` con la ruta absoluta e
imprime el SHA-1/SHA-256 que pide Google Cloud para el client OAuth de Android. Es **idempotente y
nunca pisa un keystore existente**: perder o sobreescribir esa llave significa no poder actualizar
la app publicada.

`scripts/preflight-tiendas.sh` recorre lo que, si queda a medias, se sube igual y falla recién en
la revisión o en el teléfono del cliente: placeholders del `Info.plist` y de `firebase_options.dart`,
firma de Android, Personal Team de Apple, deployment target 15.0 en el pbxproj y el Podfile, los dos
client IDs de Google, y los secrets `GOOGLE_CLIENT_IDS`/`APPLE_BUNDLE_IDS` de la edge function
`client-auth` — ahí, **401 `SOCIAL_TOKEN_INVALID` es el resultado bueno** (la función tiene los
secrets y rechazó el token basura que le mandamos); 503 significa que faltan. Termina con `exit 1`
si algo obligatorio falla; los avisos (⚠) no cortan. `--sin-red` saltea la consulta a Supabase.

`scripts/build-release.sh` hace tres cosas que a mano se olvidan:

1. Corre `scripts/preflight-tiendas.sh` **antes** de compilar y no sigue si falla.
2. Convierte `.env.release` en `--dart-define` (una clave vacía **no** se manda: mandarla
   pisaría el default de `AppConstants` — `--dart-define=SOCIAL_LOGIN_ENABLED=` apagaría los
   botones sociales del build que se sube).
3. Ofusca con `--obfuscate --split-debug-info=build/symbols/<version>/<plataforma>`.

**Los símbolos de Dart hay que archivarlos, no son opcionales.** Con `--obfuscate`, un stack de
Dart en Crashlytics llega ilegible y sólo se traduce con los símbolos de **ese** build:

```bash
flutter symbolize -d build/symbols/2.0.0+20/android/app.android-arm64.symbols -i stack.txt
```

Copiá `build/symbols/<version>/` a donde esté el keystore apenas termina el build: `build/`
está en `.gitignore` y cualquier `flutter clean` se lo lleva. Los stacks de Java/Kotlin usan
el `mapping.txt` de R8, que el plugin de Crashlytics sube solo cuando existe
`android/app/google-services.json`.

Los comandos crudos, si hace falta:

```bash
# Android — release firmado con android/key.properties (ver android/key.properties.example)
flutter build appbundle --release        # → build/app/outputs/bundle/release/app-release.aab
flutter build apk --release

# iOS — requiere Apple Developer Program (Team pago) para archivar y subir
flutter build ipa --release              # → build/ios/ipa/*.ipa

# iPhone físico con Apple ID gratuito (caduca a los 7 días)
./scripts/instalar-en-iphone.sh          # release; --debug para hot reload; --reinstalar sin recompilar
```

Sin `android/key.properties`, `flutter build apk --release` se firma con la clave de **debug** y
compila igual (sirve para probar en un equipo, no para Play), pero **`flutter build appbundle
--release` falla a propósito y antes de compilar**: Play rechaza un AAB firmado en debug y no hay
ningún uso legítimo de ese archivo, así que cortar temprano es mejor que cinco minutos de R8 para
nada. Para saltear el guard en una prueba de empaquetado:
`flutter build appbundle --release -PpermitirFirmaDebug=true`.

La versión sale de `pubspec.yaml` (`version: x.y.z+build`). Cada subida a App Store Connect o a
Play necesita un **build number mayor** que el anterior.

## Deuda de dependencias

Medido el **10/sep/2026**, a días de publicar. Lo que sigue **no se tocó a propósito**: son
majors que cambian APIs o migran datos, y el riesgo de hacerlo ahora es mayor que el beneficio.
Está en este orden porque el orden importa.

### 1. `flutter_secure_storage` 9.2.4 → 10.x → 11.x — **NUNCA saltar la 10**

Es donde viven el `device_secret` y la sesión de Supabase de **todos** los clientes.

- La 9.2.4 usa `androidx.security:security-crypto 1.1.0-alpha06` (EncryptedSharedPreferences),
  que Google **deprecó en abril/2025** y cuya `alpha06` es la última que va a existir. Funciona
  en Android 16 y trae el privacy manifest de iOS, así que para publicar hoy está bien.
- La **10.x** migra el dato existente a `AES_GCM_NoPadding` en la primera lectura. La **11.x**
  eliminó el parámetro `encryptedSharedPreferences` y su changelog dice, textual, que los datos
  de la 9 quedan *"unusable after this upgrade"* si no se pasó por la 10.
- O sea: `flutter pub upgrade --major-versions` de 9 a 11 en un solo salto **desloguea a toda la
  base instalada**, y con `allowBackup=false` no hay vuelta atrás — cada cliente vuelve a pasar
  por el OTP de WhatsApp.
- Camino correcto: subir a `^10.3.1` con
  `AndroidOptions(encryptedSharedPreferences: true, migrateOnAlgorithmChange: true, resetOnError: true)`,
  **publicar esa versión y esperar adopción**, probar en un equipo real que tenía sesión de la
  9.2.4, y recién entonces la 11.

### 2. El salto de Flutter 3.38.4 → 3.44

Desde junio/2026 los plugins de `flutter.dev` cortaron en `flutter: >=3.44.0`, así que esta
línea quedó fuera de su rango de mantenimiento. Lo que se está perdiendo hoy:

| Paquete | Fijo en | Qué trae la versión que no entra |
|---|---|---|
| `google_sign_in_android` | 7.2.11 | 7.2.15 arregla un `IllegalStateException` ("Reply already submitted") cuando el resultado de la autorización llega dos veces (process death). Hoy el impacto es nulo: el botón de Google está oculto sin client IDs. |
| `sign_in_with_apple` | 7.0.1 | 8.2.0 pide Dart ^3.12 |
| `flutter_custom_tabs` | 2.5.0 | 2.6.0 pide Dart ^3.12 |
| `local_auth_android` / `url_launcher_android` / `shared_preferences_android` / `sqflite_common` | — | sólo mantenimiento |
| `path_provider_foundation` | 2.4.x (pin explícito) | 2.5+ usa *native assets* (`objective_c.framework` firmado ad-hoc) y el iPhone rechaza la instalación con "invalid signature" |

Cuando se suba Flutter, el pin de `path_provider_foundation` se prueba a soltar y se **verifica
en un iPhone físico** que `Runner.app/Frameworks/` no tenga `objective_c.framework`.

### 3. Firebase (`firebase_core` 3.15.2 / `firebase_messaging` 15.2.10 → 4.x / 16.x)

Compila con Xcode 26 y cumple el requisito de SDK de Apple, pero la línea 11.x del SDK nativo
ya no recibe fixes. La 12.x sube el mínimo de iOS a 15 — que **ya está** en el Podfile y el
pbxproj desde el 10/sep, así que ese obstáculo cayó. Va en el mismo ciclo que el salto de
Flutter, y `firebase_crashlytics` sube con ellos (`^4.3.10` → `^5.x`): las tres son una sola
migración, no tres. `flutterfire configure` hay que correrlo con las versiones **actuales** del
pubspec para que `firebase_options.dart` sea compatible con `firebase_core` 3.x.

### 4. Majors de higiene, todas juntas y en un PR aparte

- `share_plus` 10.1.4 → 13.x: `Share.share` está deprecada; el reemplazo es
  `SharePlus.instance.share(ShareParams(...))`. Dos call-sites (`invitar_screen.dart`,
  `redemption_card.dart`).
- `package_info_plus` 8.3.1 → 10.x, `geolocator` 13 → 14, `smooth_page_indicator` 1.2 → 3:
  mantenimiento.
- **`local_auth` 2.3.0 → 3.x va aparte**: lanza `LocalAuthException` en vez de
  `PlatformException`, y `biometric_service.dart` sólo captura la segunda. El `catch (e)`
  genérico evita el crash, pero el mapeo `NotEnrolled`/`LockedOut` se pierde en silencio y todo
  error de biometría pasa a leerse como `BiometricOutcome.failed`. Hay que reescribir
  `authenticateDetailed` con `on LocalAuthException catch (e) => switch (e.code)` en el mismo
  commit.

### 5. Lints y análisis estricto

`analysis_options.yaml` deja fuera, con la cuenta medida el 10/sep/2026: `unawaited_futures`
(37 hallazgos en 22 archivos), `prefer_const_constructors` (21), `directives_ordering` (52),
`unnecessary_lambdas` (8), `avoid_dynamic_calls` (2) y `analyzer: strict-casts` (21, y ésos son
**errores**, no infos). Ninguno cambia comportamiento; son un commit mecánico que conviene hacer
**después** de publicar, porque hoy sólo agregaría 58 infos que nadie va a leer en la semana del
release. `unawaited_futures` es el que más vale la pena: esta app maneja seña de Mercado Pago y
OTP, y "un Future que nadie esperó" es exactamente el patrón del Known Risk #13 del dashboard.

### 6. `liquid_glass_renderer` 0.2.0-dev.4

Sigue siendo la **última** versión publicada (10 meses) y su README dice *"EXPERIMENTAL"*. No
hay a dónde subir. Lo que se hizo en su lugar es un kill-switch
(`lib/app/widgets/glass/liquid_glass_capability.dart`): `--dart-define=LIQUID_GLASS=false` o un
fallo al compilar los shaders dejan el dock en vidrio simple (`BackdropFilter`) en vez de
desaparecer. **Sigue faltando probarlo en un Android real de gama baja** con GPU Mali (Samsung
J/A 2017-2019, API 24-28) y medir frames con `flutter run --profile`.

## Estructura

```
lib/
├── app/            # MonacoApp, tema (MonacoColors/Typography/Theme), widgets Liquid Glass
├── core/           # api (MobileApi), auth (OTP + sesión segura), branch (modo prueba),
│                   #   location, push, router, supabase, utils
└── features/       # onboarding, home, appointments, occupancy, points, rewards,
                    #   reviews, billboard, convenios, visits, notifications, profile

integration_test/   # bancos visuales (corren en simulador con `flutter drive`, sin red)
scripts/            # preflight-tiendas · crear-keystore · build-release · instalar-en-iphone
store/              # material de las fichas: textos, capturas, ícono 512, feature graphic
```

`integration_test/` no son tests de CI: pintan pantallas con datos fijos para mirarlas.
`wallet_preview_test.dart` (Home y Premios), `alta_preview_test.dart` (alta e invitado),
`sena_preview_test.dart` (seña), `dock_shot_test.dart` (el dock) y **`store_shots_test.dart`, que
es el único que monta el shell real y cuyas capturas son las que van a las tiendas** — hay que
correrlo en un **iPhone 17 Pro Max**, porque su pantalla es exactamente el tamaño 6.9" que pide
App Store Connect. Comandos y post-proceso en `store/README.md`.

Más detalle en `CLAUDE.md` (arquitectura, contratos, trampas), `ENTREGA.md` (estado de entrega,
checklist de tiendas, pendientes del dueño) y `PUBLICAR.md` (publicar, paso a paso).
