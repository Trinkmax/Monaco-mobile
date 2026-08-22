# CLAUDE.md — Monaco (app de clientes, Flutter)

Guía para Claude Code al trabajar en `Monaco-mobile/`. El contrato compartido del rediseño
2026-08 (API mobile, auth OTP, push, rutas) manda sobre lo que diga el código viejo.

## Qué es

App **mono-organización** de Monaco Barber Studio (`organization_id a0eebc99-…-6bb9bd380a11`,
slug `monaco`). El cliente elige **sucursal** (Rondeau, Parana, Caseros; `test` sólo en modo
prueba). Comparte Supabase (`gzsfoqpxvnwmvngfoqqk`) con `../MonacoSmartBarber` y consume sus
route handlers `/api/mobile/**` en `https://monaco-smart-barber.vercel.app`.

```
package: monaco_mobile · Flutter 3.38.4 / Dart 3.10.3 · Riverpod (sin codegen) · go_router
```

## Comandos

```bash
flutter pub get
dart analyze lib/ test/                  # flutter analyze crashea a veces; este es el confiable
flutter test                             # 166 tests
flutter run [--dart-define=API_BASE_URL=http://localhost:3000]
dart run flutter_launcher_icons          # regenerar íconos desde assets/brand/
dart run flutter_native_splash:create    # regenerar splash nativo
flutter build apk --debug                # smoke de lo nativo Android
flutter build ios --debug --no-codesign  # smoke de lo nativo iOS
flutter build appbundle --release        # Play (firma con android/key.properties)
flutter build ipa --release              # App Store (Team pago)
./scripts/instalar-en-iphone.sh          # iPhone por cable con Apple ID gratuito

# QA visual: recorre TODA la app en el simulador y guarda capturas en build/qa-shots/
#   (antes: `npm run dev` en ../MonacoSmartBarber y `xcrun simctl boot <udid>`)
QA_SHOTS_DIR=build/qa-shots flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/qa_flow_test.dart -d <udid-simulador> \
  --dart-define=API_BASE_URL=http://localhost:3000 --dart-define=QA_PHONE=1100000000
```

Ojo con el QA drive: si las capturas salen todas iguales (la pantalla de lanzamiento con la M),
el simulador quedó con una instancia vieja de la app: `xcrun simctl shutdown/boot` del simulador
y volver a correr. Desde que `client-auth` es v2 (OTP), `QA_PHONE` necesita el secret
`AUTH_TEST_PHONES` en Supabase. Para mirar SÓLO el dock sin login ni red:
`integration_test/dock_shot_test.dart` (mismo driver; capturas `dock_0*.png`).

**Dock = Liquid Glass real** (`liquid_glass_renderer`, shaders, sólo Impeller): barra + burbuja
arrastrable en `lib/app/widgets/glass/liquid_dock.dart`; `LiquidGlassWarmup` en el splash
precarga los shaders (sin eso el dock aparece sin vidrio los primeros frames).

**`path_provider_foundation` queda fijado `<2.5.0`** (pubspec): la 2.5+ usa "native assets"
(`objective_c.framework`) que Flutter 3.38 deja firmado ad-hoc y el iPhone rechaza al instalar
("invalid signature" en `Frameworks/objective_c.framework`). Si aparece ese error después de tocar
dependencias: `flutter clean` (el framework viejo queda en `build/native_assets/`) y rebuild. El teléfono de QA crea un cliente real en prod: borrarlo al terminar
(`delete_client_account` + `auth.users`).

`pubspec.yaml`, `lib/main.dart`, `lib/app/app.dart`, `lib/core/router/app_router.dart`,
`lib/core/utils/constants.dart`, `lib/app/theme/*` y `lib/app/widgets/glass/*` los mantiene
el coordinador del rediseño: si hace falta una ruta/dep/token nuevo, se pide, no se improvisa.

## Arquitectura

```
lib/
├── app/
│   ├── app.dart                 # MaterialApp.router, locale es_AR, textScaler acotado 0.85–1.3
│   ├── theme/                   # MonacoColors (#0A0A0A, verde #22C55E), Poppins bundleada, MonacoTheme.dark
│   └── widgets/glass/           # Liquid Glass: LiquidGlass/Pill/Button/Dock/AppBarScaffold/Sheet/Toast/
│                                #   Dialog/TextField/CodeField/Skeleton/Empty/ErrorState/Chip/Avatar/MonacoLogo
├── core/
│   ├── api/mobile_api.dart      # MobileApi (Bearer del cliente, timeout 15 s, MobileApiException tipada)
│   ├── auth/                    # AuthNotifier/AuthState (OTP), auth_service (client-auth), secure_storage,
│   │                            #   secure_local_storage (sesión Supabase en Keychain), biometric, pin local
│   ├── branch/                  # selectedBranch*Provider
│   ├── location/                # geolocator best-effort (ordenar sucursales)
│   ├── push/                    # push_service (token → /api/mobile/push/token), push_handler (deep links)
│   ├── router/app_router.dart   # rutas + redirect por AuthStatus + shell con LiquidDock
│   ├── supabase/                # supabaseClientProvider
│   └── utils/                   # constants, formatters
├── features/
│   ├── onboarding/              # splash, welcome, login_phone, login_code, login_name, biometric_gate, utils/phone_format
│   ├── branch_selection/        # branch_picker (onboarding y cambio de sucursal)
│   ├── home/                    # home_screen + widgets (points_card, occupancy_mini_card)
│   ├── appointments/            # data (booking_api, modelos, fechas), providers, my_appointments,
│   │                            #   booking_wizard, appointment_detail, cancel_dialog
│   ├── occupancy/               # lista y detalle de sucursal con fila en vivo
│   ├── points/ rewards/ catalog/ reviews/ billboard/ convenios/ visits/
│   ├── notifications/           # bandeja client_notifications + preferencias
│   └── profile/                 # perfil, pin_setup, pin_verify, modo prueba (7 toques en la versión)
├── firebase_options.dart        # PLACEHOLDER hasta `flutterfire configure`
└── main.dart
```

**Dock** (5): Inicio `/home` · Turnos `/turnos` · Sucursales `/occupancy` · Premios `/rewards` · Perfil `/profile`.
Rutas fuera del shell: `/splash /welcome /login /login/codigo /login/nombre /biometric /pin /pin-setup
/elegir-sucursal /turnos/reservar /turnos/:id /notificaciones /notificaciones/preferencias /branch/:id
/points /catalog /reviews /review/:token /reward-qr/:id /billboard /convenios /convenio/:id /mis-canjes /visits`.

## Auth — OTP por WhatsApp (`client-auth` v2)

1. `/login` teléfono → `start` → si el dispositivo ya es conocido (login silencioso con
   `device_secret`) → home; si no → `otp_sent`.
2. `/login/codigo` (6 casillas, auto-submit, reenviar con `resend_in`) → si `client_known=false`
   → `/login/nombre` ANTES de `verify` (el nombre viaja en `verify`).
3. `verify` → sesión Supabase (`{phone}@monaco.internal` + `device_secret` como password).
   Sesión persistida en **Keychain/EncryptedSharedPreferences** (`SecureLocalStorage`).
4. `AuthStatus`: `initial → unauthenticated | needsBiometric | needsBranch | authenticated`.
   `needsBranch` = hay sesión pero falta elegir sucursal (onboarding).

Biometría y PIN son **gates locales** (PIN hasheado en SecureStorage; los RPC
`set_client_pin/verify_client_pin` ya no se usan). Teléfonos de prueba (`AUTH_TEST_PHONES` en la
edge function) no reciben WhatsApp: código fijo para reviewers y tests.

`ArPhone` (`features/onboarding/utils/phone_format.dart`) sólo limpia y dibuja ("351 212-5249",
máscara "+54 9 351 ••• 5249"); **la validez la decide el server**.

## Turnos — nativos vía `/api/mobile` (un solo motor)

La app NO reimplementa disponibilidad ni reserva: todo pasa por route handlers del dashboard que
llaman a `getAvailableSlots` / `createAppointment` / `cancelAppointment`.

| Endpoint | Uso |
|---|---|
| `GET /api/mobile/turnos/branches` | sucursales + `bookable`, `open_now`, `is_test`, `server_today` |
| `GET /api/mobile/turnos/[slug]` | bootstrap del wizard (settings, servicios, barberos, branding, `client.upcoming`) |
| `GET /api/mobile/turnos/[slug]/slots?date&service_ids&staff_id` | slots; **si el motor falla devuelve `error`, nunca `[]`** |
| `POST /api/mobile/turnos/[slug]/book` | reserva; 409 `SLOT_TAKEN / PHONE_QUOTA_EXCEEDED / ALREADY_BOOKED_TODAY / TOO_LATE / …` |
| `POST /api/mobile/turnos/cancel` | cancela (`ALREADY_CLOSED`, `TOO_LATE_TO_CANCEL`) |
| `GET/POST /api/mobile/me` | validar sesión / renombrar |
| `POST/DELETE /api/mobile/push/token` | alta/baja del token FCM por `(client_id, device_id)` |

Reglas: identidad por **JWT** (el server saca teléfono y `client_id` del Bearer, nunca del body);
"hoy" es `server_today`, no `DateTime.now()`; `appointment_date + start_time` son hora de PARED de
la sucursal y `Fechas` (`features/appointments/data/fechas.dart`) convierte con offset fijo UTC-3,
nunca con la zona del teléfono ni con `toIso8601String()`.

## Push — FCM

`PushService` registra el token con `POST /api/mobile/push/token` (platform, device_id,
app_version), lo refresca y lo da de baja en logout. Payload `data = { type, value?, deep_link?,
notification_id? }`; `PushHandler` navega por `deep_link` (sólo paths internos que empiezan con
`/`) o por `type` (`appointment_*→/turnos`, `reward→/rewards`, `points→/points`, default `/home`)
y marca `client_notifications.read_at`. Canal Android `monaco_default`
(`AppConstants.androidNotificationChannelId` == `@string/default_notification_channel_id` del manifest
== `android.notification.channel_id` que manda la edge function `send-push`).

**Todo el código tolera `Firebase.apps.isEmpty`**: mientras `firebase_options.dart` tenga
placeholders, `main.dart` no inicializa Firebase y la app funciona sin push.

## Modo prueba

`SecureStorageService.isTestModeEnabled()`: se activa con 7 toques sobre "Versión x.y.z" en Perfil.
Con él, `branchesProvider` deja de esconder la sucursal `is_test` (slug `test`).

## Nativo — lo que está configurado y por qué (no deshacer)

**iOS** (`ios/Runner/Info.plist`, `project.pbxproj`):
- `CFBundleDisplayName`/`CFBundleName` = **Monaco**; `CFBundleDevelopmentRegion = es` +
  `CFBundleLocalizations [es]` (la ficha dice español; `developmentRegion = es` en el pbxproj).
- `TARGETED_DEVICE_FAMILY = 1` (sólo iPhone). Con `"1,2"` y sólo portrait el upload muere con
  **ITMS-90474**; la UI (dock flotante) es phone-only.
- `LSApplicationQueriesSchemes [https, mailto, whatsapp, tel]`: sin eso `canLaunchUrl` devuelve
  false y los links de política/soporte del perfil no hacen nada.
- `NSLocationDefaultAccuracyReduced = true` (alcanza para ordenar sucursales; coherente con
  `CoarseLocation` en `PrivacyInfo.xcprivacy`). Sin usage strings de cámara/galería: no se usan.
- `UIBackgroundModes [remote-notification]` + `RunnerRelease.entitlements` con `aps-environment
  production`. Debug usa `Runner.entitlements` vacío a propósito (Personal Team no firma push).
- `AppDelegate.swift` setea `UNUserNotificationCenter.current().delegate = self`
  (flutter_local_notifications + firebase_messaging conviven así).
- Splash: `LaunchScreen.storyboard` generado por flutter_native_splash (fondo #0A0A0A + logo);
  el `backgroundColor` de la vista también es #0A0A0A para que no haya frame blanco.
- `ITSAppUsesNonExemptEncryption = false`. Min iOS 14.0.

**Android** (`android/app/`):
- `MainActivity : FlutterFragmentActivity` — **obligatorio** para `local_auth`
  (con `FlutterActivity` la huella falla en silencio con `no_fragment_activity`).
- `android:label="@string/app_name"` = Monaco; `allowBackup=false` (EncryptedSharedPreferences no
  sobrevive a un restore en otro equipo); `enableOnBackInvokedCallback=true`.
- Permisos explícitos: `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_COARSE/FINE_LOCATION`,
  `POST_NOTIFICATIONS`, `VIBRATE`, `RECEIVE_BOOT_COMPLETED`, `USE_BIOMETRIC`.
- `<queries>`: VIEW `https/mailto/tel/whatsapp` (+ PROCESS_TEXT del engine).
- Meta-data FCM: `default_notification_channel_id = monaco_default`,
  `default_notification_icon = @drawable/ic_notification` (silueta blanca generada desde
  `assets/brand/app_icon_foreground.png`), `default_notification_color = @color/notification_accent`.
- Receivers de `flutter_local_notifications` para notificaciones programadas.
- `LaunchTheme`/`NormalTheme` **oscuros** (`Theme.Black.NoTitleBar`, `windowBackground =
  @color/monaco_background`) en `values`, `values-night`, `values-v31`, `values-night-v31`: sin flash
  blanco. Si se corre `flutter_native_splash:create` de nuevo, revisar que `NormalTheme` siga así.
- `build.gradle.kts`: desugaring (`desugar_jdk_libs 2.1.4`, lo pide flutter_local_notifications),
  `signingConfigs.release` desde `android/key.properties` con **fallback a debug** si no existe
  (el build local no se rompe; el log avisa), `proguard-rules.pro` (GSON de
  flutter_local_notifications), plugin `com.google.gms.google-services` declarado en
  `settings.gradle.kts` y **aplicado sólo si existe `app/google-services.json`**.
- `res/raw/keep.xml` evita que `shrinkResources` tire los drawables que se referencian desde Dart.

## Tests (`test/`)

- `unit/mobile_api_test.dart` — MobileApi con `MockClient`: headers, URL, 2xx, mapeo de errores
  (`SLOT_TAKEN`, 401, `HTTP_5xx`, `BAD_RESPONSE`), red (`NETWORK`), timeout con `fakeAsync`.
- `unit/auth_state_test.dart`, `unit/constants_test.dart`, `unit/formatters_test.dart`,
  `unit/fechas_test.dart`, `unit/phone_format_test.dart`, `unit/appointment_model_test.dart`.
- `widget/occupancy_mini_card_test.dart` (carga Poppins real: con Ahem la pastilla desborda),
  `widget/points_history_tile_test.dart`.
- Las pantallas con animaciones en loop (LED que pulsa) no admiten `pumpAndSettle`: bombear frames.

## Convenciones

- UI y comentarios en español rioplatense; sin emojis en UI (íconos Material `_rounded`); sin `TODO` sin dueño.
- Código nuevo: `withValues(alpha:)` (no `withOpacity`), `debugPrint('[modulo] …')` (no `print`).
- Toda lista: skeleton / `LiquidEmptyState` / `LiquidErrorState` con reintentar / `RefreshIndicator`;
  padding inferior 120 dentro del shell (el dock tapa).
- Fechas: `Fechas.*` para turnos; `Formatters.*` para el resto; locale `es_AR`.

## Riesgos conocidos

1. **Firebase a medias es peor que sin Firebase**: correr `flutterfire configure` sin subir la APNs
   key y sin Developer Program deja el prompt de permiso prendido y el token nunca llega.
2. Reinstalar la app regenera `device_secret`: el cliente vuelve a pasar por OTP (esperado).
3. `FlutterFragmentActivity` + biometría hay que probarlos en un Android real (no hay emulador con huella).
4. Los `defaultValue` de `AppConstants` apuntan a producción: un `flutter run` pelado pega a prod.
5. El Personal Team `A3WAXVR55Z` no puede archivar para App Store ni firmar push: hace falta el
   Apple Developer Program pago (ver `ENTREGA.md`).
