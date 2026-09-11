# CLAUDE.md — Monaco (app de clientes, Flutter)

Guía para Claude Code al trabajar en `Monaco-mobile/`. El contrato compartido del rediseño
2026-08 (API mobile, auth OTP, push, rutas) manda sobre lo que diga el código viejo.

Documentos hermanos: `README.md` (cómo correr y compilar), `ENTREGA.md` (estado de entrega y qué
falta que haga el dueño), `PUBLICAR.md` (el paso a paso de publicar, escrito para él) y `store/`
(el material de las fichas).

## Qué es

App **mono-organización** de Monaco Barber Studio (`organization_id a0eebc99-…-6bb9bd380a11`,
slug `monaco`). Comparte Supabase (`gzsfoqpxvnwmvngfoqqk`) con `../MonacoSmartBarber` y consume sus
route handlers `/api/mobile/**` en `https://monacobarber.vercel.app` (el alias viejo
`monaco-smart-barber.vercel.app` está muerto desde el 25/ago/2026; el default vive en
`AppConstants.apiBaseUrl`).

**La app NO tiene sucursal** (rediseño del 24/ago/2026). Es la app de Monaco entera: el Home
saluda sin nombrar un local, la fila en vivo muestra las tres y los puntos ya eran globales. La
sucursal se elige **una sola vez y donde importa**: el paso 1 de la reserva de turno. Antes había
un gate de onboarding "¿a qué sucursal vas?" (`AuthStatus.needsBranch`), una pill para cambiarla en
el Home y una tarjeta en Perfil; los tres se eliminaron junto con `features/branch_selection/`, los
4 campos `selectedBranch*` de `AuthState` y sus keys del Keychain (que `_init()` borra una vez).
Lo único que sobrevivió de esa feature es `testModeProvider`, que se mudó a
`core/branch/test_mode_provider.dart`.

```
package: monaco_mobile · Flutter 3.38.4 / Dart 3.10.3 · Riverpod (sin codegen) · go_router
```

## Comandos

```bash
flutter pub get
dart analyze lib/ test/ integration_test/   # flutter analyze crashea a veces; este es el confiable
flutter test                               # 417 tests
flutter run [--dart-define=API_BASE_URL=http://localhost:3000]
dart run flutter_launcher_icons            # regenerar íconos desde assets/brand/
dart run flutter_native_splash:create      # regenerar splash nativo
flutter build apk --debug                  # smoke de lo nativo Android
flutter build ios --debug --no-codesign    # smoke de lo nativo iOS
./scripts/preflight-tiendas.sh             # ¿está todo para subir? (placeholders, firma, secrets)
./scripts/crear-keystore.sh                # keystore de Play, UNA vez en la vida de la app
./scripts/build-release.sh [android|ios]   # preflight + AAB + IPA ofuscados, con los --dart-define
./scripts/instalar-en-iphone.sh            # iPhone por cable con Apple ID gratuito

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

**El baseline de `dart analyze` es 0 errores / 0 warnings / 0 infos** (10/sep/2026). No es "sin
errores": si aparece un info, es nuevo y hay que mirarlo. `analysis_options.yaml` lista qué lints
quedaron afuera **a propósito** y con cuántos hallazgos tendría cada uno hoy (`unawaited_futures`
37, `directives_ordering` 52, `prefer_const_constructors` 21, `strict-casts` 21…): la regla para
agregar un lint es que dé **0 hallazgos hoy**, porque uno que nace con 40 infos que nadie va a
arreglar no protege nada — enseña a ignorar la salida del analizador.

**Los builds de tienda salen de `scripts/build-release.sh`, no de `flutter build` a mano.** Corre
el preflight antes de compilar (ocho minutos de build para descubrir que faltaba un client ID es
justo lo que ese chequeo evita), convierte `.env.release` en `--dart-define` y ofusca con
`--split-debug-info=build/symbols/<version>/<plataforma>`. Dos trampas que el script ya resuelve y
que a mano se pagan: **una clave vacía no se manda** (`--dart-define=SOCIAL_LOGIN_ENABLED=` no
significa "usá el default", pisa el default con `false` y apagaría los botones sociales del build
que se sube), y **los símbolos van por versión**, porque los de la `2.0.0+20` no traducen un crash
de la `2.0.0+21` y pisarlos deja los reportes de la versión anterior ilegibles para siempre.

**`.env.release`** (gitignored; el ejemplo commiteado es `.env.release.example`) es formato
`KEY=VALOR`, una por línea, sin comillas ni `export`, y una variable de entorno con el mismo
nombre le gana. Lo leen el preflight y el build. Se convierten en `--dart-define`
`GOOGLE_IOS_CLIENT_ID`, `GOOGLE_SERVER_CLIENT_ID`, `TEST_MODE_CODE`, `SOCIAL_LOGIN_ENABLED` y
`LIQUID_GLASS`; `APPLE_TEAM_ID` vive en el mismo archivo pero **no** es un define — sólo se usa
para generar `ios/ExportOptions.plist` la primera vez. Los defaults de `AppConstants` ya apuntan a
producción, así que lo único que va ahí es lo que **no** puede quedar en su default.

**`scripts/preflight-tiendas.sh`** chequea, y falla con `exit 1` si algo obligatorio no está: el
`Info.plist` sin `PLACEHOLDER-REEMPLAZAR` (el REVERSED_CLIENT_ID de Google), `firebase_options.dart`
sin placeholders, que exista `android/key.properties`, que `DEVELOPMENT_TEAM` ya no sea el Personal
Team `A3WAXVR55Z`, que el pbxproj no haya quedado swapeado por `instalar-en-iphone.sh` (esa corrida
cambia los entitlements de Release y si muere sin restaurar, el build se sube sin push), que el
deployment target sea 15.0 en el pbxproj **y** en el Podfile, que los dos client IDs de Google
estén y tengan forma de client ID, y que la edge function `client-auth` tenga cargados
`GOOGLE_CLIENT_IDS` / `APPLE_BUNDLE_IDS`. **Ahí el resultado bueno es un 401**
(`SOCIAL_TOKEN_INVALID`: los secrets están y la función rechazó el token basura que le mandamos);
un **503 `SOCIAL_VERIFY_UNAVAILABLE`** significa que el secret falta y que el botón social va a
fallar siempre en producción.

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
│   ├── auth/                    # AuthNotifier/AuthState (OTP + social + invitado), auth_service
│   │                            #   (client-auth v3), social_auth_service (Google/Apple), secure_storage,
│   │                            #   secure_local_storage (sesión Supabase en Keychain), biometric, pin local
│   ├── branch/                  # test_mode_provider (único resto de branch_selection)
│   ├── location/                # geolocator best-effort (ordena el paso 1 del wizard, opt-in)
│   ├── push/                    # push_service (token → /api/mobile/push/token), push_handler (deep links)
│   ├── deeplink/                # deep_link_handler (monaco://pago?deposit=<id>)
│   ├── router/app_router.dart   # rutas + redirect por AuthStatus + shell con LiquidDock
│   ├── supabase/                # supabaseClientProvider
│   └── utils/                   # constants, formatters
├── features/
│   ├── onboarding/              # splash, welcome (3 puertas + invitado), login_phone, login_code
│   │                            #   (código + nombre), biometric_gate, widgets/auth_opciones,
│   │                            #   widgets/muro_login, widgets/google_g, utils/phone_format
│   ├── home/                    # home_screen + widgets (home_header, wallet_points_card,
│   │                            #   turno_tiles, occupancy_mini_card)
│   ├── appointments/            # data (booking_api, modelos, fechas), providers, my_appointments,
│   │                            #   booking_wizard (paso 1 = sucursal), appointment_detail, cancel_dialog
│   ├── occupancy/               # lista y detalle de sucursal con fila en vivo
│   ├── rewards/                 # data/premio_item, providers/premios_provider,
│   │                            #   premios_screen (tab), mis_premios_screen, qr_display
│   ├── loyalty/                 # programa de fidelización: modelos, loyaltyProvider, MonacoCard,
│   │                            #   status strip, celebración, /categoria, /invitar (QR de referido)
│   ├── senas/                   # seña de Mercado Pago: data (modelos, senas_api,
│   │                            #   sena_pendiente_store), providers/sena_estado_provider,
│   │                            #   pago_sena_screen, sena_confirm_sheet, checkout_launcher
│   ├── points/ reviews/ billboard/ convenios/ visits/
│   ├── notifications/           # bandeja client_notifications + preferencias
│   └── profile/                 # perfil, pin_setup, pin_verify, modo prueba (7 toques en la versión)
├── firebase_options.dart        # PLACEHOLDER hasta `flutterfire configure`
└── main.dart
```

**Dock** (5): Inicio `/home` · Turnos `/turnos` · Sucursales `/occupancy` · Premios `/rewards` · Perfil `/profile`.
Rutas fuera del shell: `/splash /welcome /login /login/codigo /biometric /pin /pin-setup
/turnos/reservar /turnos/:id /pago/:id /notificaciones /notificaciones/preferencias /branch/:id
/points /categoria /invitar /mis-premios /reviews /review/:token /reward-qr/:id /billboard /convenios /convenio/:id /mis-canjes /visits`.

Rutas que **ya no existen**: `/elegir-sucursal` (no hay sucursal global), `/catalog` (el catálogo
ES el tab `/rewards`) y `/login/nombre` (el nombre se pide junto con el código). Si aparece un
`context.push` a una de las tres, go_router pinta su pantalla de error en runtime — no es un error
de compilación.

## Auth — alta propia con Google/Apple/teléfono (`client-auth` v3, sep/2026)

**Cualquiera puede crearse la cuenta desde la app.** Antes no: el cliente nacía en la tablet del
local y `start` contestaba `404 CLIENT_NOT_FOUND` a todo el que no estuviera en `clients`, con una
hoja ("¿Aún no sos cliente?") que lo mandaba a la barbería. Con publicidad en marcha eso es
rechazar al 100 % de los que llegan desde un anuncio. Lo habilita
`organizations.allow_client_signup` (migración 210, hoy **sólo Monaco**).

**La identidad del negocio sigue siendo el TELÉFONO.** Es lo que ata la cuenta con la fila del
local, con WhatsApp, con los puntos y con el historial, y es lo único que la tablet sabe buscar.
Google y Apple son login de un toque y recuperación de cuenta, **no una identidad paralela**: toda
cuenta nueva termina con un teléfono verificado por OTP.

Pantalla de entrada (`/welcome`): **Continuar con Google** · **Continuar con Apple** (sólo iOS) ·
**Usar mi número de teléfono** · **Seguir mirando**. El bloque de las tres primeras es
`AuthOpciones` y lo comparten la bienvenida y el muro de login.

1. **Social** (`core/auth/social_auth_service.dart` → acción `social`). El `id_token` va a
   **nuestra edge function**, NO a `supabase.auth.signInWithIdToken`: ese camino crearía un usuario
   de Auth suelto, sin fila en `clients` y **sin `app_metadata.user_type='client'`**, que es de lo
   que depende toda la RLS de la mig 192. Respuesta `ok` → sesión de un toque; `need_phone` →
   `signup_token` (HMAC de 15 min, sólo en memoria, `signupPendienteProvider`) que viaja en `start`
   **y** en `verify`.
2. `/login` teléfono → `start` → login silencioso si el dispositivo ya es conocido, o `otp_sent`.
3. `/login/codigo` (6 casillas + reenviar con `resend_in`) → **si `name_required` es true, el campo
   Nombre está en ESTA pantalla**. `/login/nombre` se eliminó: era un tercer paso que verificaba el
   código recién ahí y, ante un código incorrecto, tenía que volver atrás arrastrando el error en el
   estado (`LoginFlow.pendingCodeError`/`code`, que ya no existen). Con `name_required` el campo se
   dibuja de entrada, y el `NAME_REQUIRED` de `verify` **no consume el desafío**, así que el caso
   raro se resuelve completando el campo y reintentando con el mismo código.
4. `verify` → sesión Supabase (`{phone}@monaco.internal` + `device_secret` como password).
   Sesión persistida en **Keychain/EncryptedSharedPreferences** (`SecureLocalStorage`).
5. `AuthStatus`: `initial → unauthenticated | guest | needsBiometric | authenticated`. **No hay
   `needsBranch`**.

Cosas que no hay que "arreglar" ingenuamente:

- **El `device_secret` NO se rota al cerrar sesión** (es la password del usuario de Auth y lo que
  habilita el login silencioso). El PIN, la biometría y la marca de invitado **sí** se borran en
  `clearSession()`: son gates de ESTA cuenta en ESTE equipo, y antes sobrevivían al logout — el que
  entraba después se encontraba con el candado del anterior y sin forma de abrirlo (el PIN es un
  hash local, no hay "olvidé mi PIN"). Fijado en `test/widget/onboarding_flow_test.dart`.
- **Apple sólo en iOS**, gateado con `Platform.isIOS`. `SignInWithApple.isAvailable()` devuelve
  `true` en Android y **no sirve como gate**: ahí el paquete abre un Custom Tab contra un servidor
  propio (deja de ser nativo) y la guideline 4.8 es de la App Store. El nombre de Apple llega
  **fuera del token** y **sólo en la primera autorización**: si no se manda en `name`, no se
  recupera nunca. El nonce va hasheado (sha256 hex) al proveedor y **crudo** a nuestro server —
  desde el 10/sep/2026 **también en Google** (`initialize(nonce: sha256hex)`, que en 7.x se fija una
  vez por proceso): sin él, un `id_token` capturado en tránsito o en un log se podía reproducir
  contra `client-auth` durante su hora de vida.
- **El `authorizationCode` de Apple viaja SIEMPRE** (`authorization_code` en el body de la acción
  `social`). Lo que Apple da una sola vez es el **nombre**, no el code: el code llega en cada
  autorización, vale 5 minutos y el server lo canjea en el acto por el `refresh_token` con el que
  después puede **revocar** la autorización al borrar la cuenta
  (`POST https://appleid.apple.com/auth/revoke`), que Apple exige desde jun/2022 para la 5.1.1(v).
  Si el server no lo guarda, el Apple ID sigue mostrando a Monaco entre sus apps autorizadas después
  del borrado y el próximo "Continuar con Apple" entra sin hoja a una cuenta que ya no existe.
- **Google 7.x**: `initialize()` una sola vez por proceso, `attemptLightweightAuthentication()` es
  silencioso y para un usuario nuevo devuelve `null` **siempre** — hay que caer a `authenticate()`.
  Sin `serverClientId` el SDK autentica pero no emite `id_token`.
- **`SOCIAL_VERIFY_UNAVAILABLE` (503) no se le echa a la cuenta del cliente**: es que no pudimos
  bajar el JWKS o faltan los client IDs. Decirle "tu cuenta de Google no sirve" lo manda a resolver
  un problema que no tiene.
- El botón de Google **no se dibuja** si no hay client id cargado (`googleConfigurado`): mejor
  esconderlo que ofrecer algo que siempre falla. Ver `ENTREGA.md` §4-bis para los valores.
- **`--dart-define=SOCIAL_LOGIN_ENABLED=false` esconde Google Y Apple**
  (`AppConstants.socialLoginEnabled`). Es el interruptor de emergencia para el día en que `client-auth` no pueda
  validar los tokens (faltan `APPLE_BUNDLE_IDS` / `GOOGLE_CLIENT_IDS`, o no baja el JWKS): un botón
  visible en la primera pantalla que siempre contesta "no pudimos verificar tu cuenta" es rechazo
  por la 2.1. **La app NO intenta detectar la configuración del backend** —sería una llamada de red
  para dibujar un botón—: se decide en el build. Apaga los dos juntos a propósito: con Google
  visible, la 4.8 obliga a que Apple esté y funcione.
- **Los dos botones sociales van con el MISMO peso visual** (lámina blanca sólida; el logo de Apple
  en negro sobre blanco, que es una de las formas que admite la HIG). El de Apple era una pastilla
  translúcida al lado de la lámina de Google y se leía como secundario, que es lo que App Review
  mira bajo la 4.8. Cuando no hay ningún social, el primario pasa a ser **"Usar mi número de
  teléfono"**: sin eso, una bienvenida de Android quedaba con una sola pastilla translúcida y
  ningún botón principal.

Biometría y PIN son **gates locales** (PIN hasheado en SecureStorage; los RPC
`set_client_pin/verify_client_pin` ya no se usan). Teléfonos de prueba (`AUTH_TEST_PHONES` en la
edge function) no reciben WhatsApp: código fijo para reviewers y tests.

## Modo invitado (`AuthStatus.guest`)

**Requisito de App Store, no una mejora.** 5.1.1: si la app no es toda "account-based", tiene que
dejar usarla sin login; 5.1.2(i): no se pueden condicionar funciones a que el usuario habilite
permisos. Antes la app exigía cuenta para todo — eso es rechazo.

- "Seguir mirando" → `continuarComoInvitado()` → marca en el Keychain (`guest_mode`) para que la
  próxima apertura **no** vuelva a plantar la bienvenida. `_estadoSinSesion()` la lee en `_init()`.
- Sin cuenta se ve: Home (con `_TarjetaInvitado` en el lugar de la tarjeta de puntos), Sucursales y
  su detalle con la fila en vivo, la cartelera, y **Premios como vidriera** (las tres categorías
  reales, sin precios). Todo eso es anon-legible: `get_org_branch_signals`,
  `get_branch_public_detail`, `billboard_items` y `services` tienen policy/grant para `anon`.
- **El catálogo real NO se puede mostrar sin sesión**: `get_loyalty_catalog()` resuelve por
  `auth.uid()` y sólo tiene grant a `authenticated`, y `reward_catalog`/`partner_benefits` tienen
  RLS por cliente. Por eso la vidriera explica el programa en vez de listar premios: inventar
  precios sería mostrar un número que después no coincide.
- El muro (`pedirCuenta` / `conCuenta`, `presentation/widgets/muro_login.dart`) aparece **al tocar
  la acción**, con copy propio por acción y **siempre con "Ahora no"**. `conCuenta` retoma la acción
  si el muro terminó con sesión: hacerlo tocar dos veces el mismo botón pierde al que recién se
  registró.
- El router tiene una **lista blanca** (`_permitidaParaInvitado`): lo que no está se redirige a
  `/home`, así que una ruta nueva no queda abierta por olvido. Los **cuatro tabs del dock están
  todos** —un ítem del dock que rebota se lee como que la app está rota— y `/turnos`, `/rewards` y
  `/profile` tienen su propia versión de invitado.
- El perfil de invitado **no dibuja el interruptor de push**: pedir ese permiso a alguien que no
  tiene cuenta es pedirlo sin nada que notificar.

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

### El wizard son TRES pasos: **Sucursal → Servicio → Día y horario**

`WizardPhase.pickBranch` era un fallback ("la sucursal que elegiste no toma turnos online"); desde
que la app no guarda sucursal es el paso 1 y siempre se pasa por él. `_init()` sólo lo saltea con el
deep-link `?branch=<slug>` (QR del local, push, link compartido); si ese slug no es reservable, el
selector aparece igual con el copy que lo explica (`originalNotBookable`).

- El índice y la etiqueta viven en `BookingWizardState.stepIndex` / `.stepLabel`, no en la pantalla.
- **`conPasos` incluye `pickBranch`, `conFooter` no**: el selector confirma al tocar la tarjeta, y un
  CTA "Continuar" permanentemente deshabilitado (`canProceed` es false en esa fase) se lee como una
  pantalla rota.
- `goBack()` desde Servicios **borra el bootstrap y el slug**: si sólo cambiara de fase, el título
  del header y el paso de horarios seguirían mostrando la sucursal anterior.
- `_loadBranches` no muestra skeleton si ya tiene la lista, y un refresco fallido no tira al cliente
  a la pantalla de error: se queda con lo que tenía.
- `BranchPickerStep` ordena **abiertas primero** y ofrece "Ordenar por cercanía" como pill opt-in:
  la ubicación se pide sólo si el cliente la toca (un prompt del sistema en medio de una reserva,
  sin haberlo pedido, se lee como que la app espía). Es el único consumidor que queda de
  `geolocator`.
- El Home decide si ofrece "Reservar" con `hayTurnosOnlineProvider`, que **falla abierto**: mostrar
  el CTA de más lleva, en el peor caso, a "por ahora no hay turnos online"; de menos, deja al
  cliente sin forma de reservar y sin explicación.

### Seña por Mercado Pago (`features/senas/`, sep/2026)

**La seña no vive en `appointments` y el turno no existe hasta que el pago se acredita.** El motor
está entero en el dashboard (`src/lib/senas/motor.ts` + migración 207); la app pregunta, muestra y
espera. Contrato compartido: `MonacoSmartBarber/src/lib/senas/contrato.ts`.

Flujo: paso 3 del wizard → "Confirmar turno" → `POST /api/mobile/turnos/<slug>/sena` →
hoja con la política → checkout de MP en el navegador → **el webhook crea el turno** →
`/pago/<id>` lo muestra.

- **`SENA_NO_APLICA` es el único código que habilita a reservar sin pagar.** Es el camino de las
  cuatro sucursales hoy (`branch_deposit_settings.is_enabled = false` en las 4) y cae al
  `POST /book` de siempre. Cualquier otro error —`MP_ERROR`, timeout, red— **no** cae ahí: si la
  sucursal cobra seña y MP tiene un hipo, reservar igual sería regalar turnos. Fijado en
  `test/unit/senas_api_test.dart`.
- **El nombre viaja en el pedido de seña**, no en `/book`: con seña la app nunca vuelve a hablar con
  `/book`, y un cliente sin nombre cargado quedaría con el turno a nombre del teléfono.
- **Nada de WebView.** Mercado Pago deshabilitó ese modelo para todas las integraciones.
  Android → Custom Tabs (`flutter_custom_tabs`, fijado `<2.6.0`: la 2.6 pide Dart ^3.12);
  iOS → Safari externo (`url_launcher` en `externalApplication`), que es lo único que deja saltar a
  la app de MP por universal link — con `wallet_only`, eso es la diferencia entre dos toques y
  tipear una tarjeta.
- **La pantalla de estado tiene DOS fuentes y ninguna alcanza sola**: Realtime sobre
  `booking_deposits` (la mig 207 le dio al cliente policy de SELECT y metió la tabla en la
  publication) y polling cada 3 s a `GET /api/mobile/senas/<id>`, con corte a los 3 minutos y
  "Ya pagué, revisá de nuevo". **El evento de Realtime es un aviso, no un dato**: trae la fila
  cruda, sin nombre de barbero ni motivo traducido, así que dispara una consulta al endpoint, que
  es la única fuente de verdad. Los query params que MP agrega a la URL de vuelta viajan por el
  browser del cliente y son falsificables.
- **`EstadoSena.desconocida` nunca se lee como turno confirmado** ni como terminal: un estado que
  esta versión no conoce sigue esperando. Misma regla que `BeneficioCanjeado`.
- **Volver es best-effort.** El deep link es `monaco://pago?deposit=<id>` (Info.plist
  `CFBundleURLTypes` + intent-filter con `launchMode=singleTop`), y **el parámetro no puede
  llamarse `code`**: `supabase_flutter` engancha todos los deep links del proceso y trata cualquiera
  con `code` como callback de OAuth. Puede no llegar nunca (el cliente vuelve con el botón de
  atrás), así que `/pago/<id>` también se alcanza desde el cartel **"Tenés un pago sin confirmar"**
  del Home y de Mis turnos (`SenaPendienteBanner` + `senaPendienteProvider`), alimentado por la
  marca local que se guarda **antes** de abrir el checkout: mientras el cliente paga, iOS puede
  matar la app.
- El `<queries>` del manifest necesita VIEW/https **con `BROWSABLE`** y
  `android.support.customtabs.action.CustomTabsService`: sin eso, en API 30+ Custom Tabs no resuelve
  navegador y el botón "Pagar seña" no hace nada.
- `AppConstants.senaTimeout` = 45 s (el general sigue en 15): del otro lado nuestro server habla con
  Mercado Pago. Una ambigüedad de plata es lo peor que puede pasar acá.
- El velo verde (`ConfirmacionVerde`) también se dispara acá: el cliente que pagó no merece menos
  celebración que el que no pagó. El resto de la pantalla usa blanco (`MonacoColors.seleccion`) para
  los CTA y ámbar/rojo para los resultados no felices.
- Banco visual: `integration_test/sena_preview_test.dart` (`sena_01…09`). De ahí salió que la hoja
  no entraba en un iPhone 17 con la política real de 4 párrafos.

### El verde es del NEGOCIO, no de la interfaz

`MonacoColors.seleccion` (blanco) es el acento de **estado de interfaz**: chip elegido, día
seleccionado, paso actual del wizard, CTA principal, tile de "Reservar turno". Lo usan
`LiquidChip` (por default), `DayStrip`, `StepProgress`, `ServicesStep`, `BarberSheet`,
`WizardFooter` y `TurnoTiles`.

`MonacoColors.monacoGreen` quedó **sólo** para lo que significa algo del negocio: "Sin espera" en la
fila en vivo, el velo `ConfirmacionVerde` de turno confirmado, los toasts de éxito y las pastillas
de estado. Decisión del dueño (27/ago/2026): con el verde tiñendo además cada chip, cada día y cada
botón, el wizard entero se leía verde y las dos cosas se confundían. Sobre vidrio oscuro, lo claro
ya comunica "elegido" sin gastar color — **no volver a poner `monacoGreen` en un estado de UI.**
En la revisión del 30/ago se sacó de tres lugares donde era decoración: el header "Tu amigo recibe /
Vos sumás" de Invitar (vidrio neutro como `_Pasos`; el verde de esa pantalla es "Completada · +150
pts"), el ícono del diálogo "Confirmar canje" y el tile de `VistaPreviaCanje` cuando NO alcanza. El
ícono de "Mi categoría" en Perfil va con `LoyaltyTier.acentoSobreOscuro` (el secundario del tier, o
blanco si es tan oscuro como Platinum), la misma regla que la línea "Cliente Oro" de Premios.

## Premios — una sola pantalla (rediseño 24/ago/2026)

El tab `/rewards` (`PremiosScreen`) es **la tienda**: grilla de 2 columnas, chips de categoría y,
arriba, una tira con los premios que el cliente ya canjeó y tiene que mostrar en el local. Antes
eran dos pantallas separadas —`/rewards` (billetera) y `/catalog` (canjear)— y el cliente podía
canjear dos veces lo mismo porque no encontraba lo que ya tenía. `/catalog` se eliminó;
`/mis-premios` (`MisPremiosScreen`, con las solapas Para usar / Historial) es el "ver todos" de la tira.

**`PremioItem` (`features/rewards/data/premio_item.dart`) unifica dos tablas.** Un premio del
catálogo (`get_loyalty_catalog()`, cuesta puntos, se canjea con `loyalty_redeem_reward`) y un
convenio (`partner_benefits`, **gratis**, se activa con `issue_benefit_redemption`) se dibujan con
la misma tarjeta; la diferencia la trae el modelo, no el widget. Los convenios muestran **GRATIS**
en vez de un precio: ponerles puntos sería mentir sobre el modelo de negocio.

**El catálogo viene con los candados resueltos** (30/ago/2026, migs 196/197). `catalogoPremiosProvider`
llama a `get_loyalty_catalog()`, que devuelve cada premio activo y vigente con `locked_by_tier`,
`tier_required_name/code`, `allowed_tiers`, `kind`, `service_name`, `validity_days`, `is_featured` y
`allow_stacking` calculados contra la categoría de ESTE cliente. La app no sabe qué categoría exige
un premio ni cuál tiene el cliente: `PremioItem.lockedByTier` se pinta (candado + pill "Solo Oro"
abajo a la izquierda de la lámina + "Subí a Oro para canjearlo"), y `puedeCanjear(saldo)` es la
única regla que decide si la tarjeta dice "Canjear". `abrirPremio` lo trata ANTES que stock y
saldo (juntar puntos no lo destraba): diálogo "Exclusivo para Oro y Platinum" —los nombres se
resuelven con `allowed_tiers` × `loyalty.tiers`— con las visitas que faltan (`min_visits` del tier
− `visits_in_window`) y CTA a `/categoria`.

**Las tres categorías se DERIVAN**, no están en la base:

| Categoría | Regla | Acento |
|---|---|---|
| Cortes | `kind = descuento` (o, sin `kind`: `is_free_service` / `discount_pct > 0`) | verde Monaco |
| Merch | `kind = merch` (o el resto de `reward_catalog`) | blanco |
| Marcas | todo `partner_benefits` | azul `#3B82F6` |

`reward_catalog.category` (migración 194, nullable, `cortes|merch`) es el **override manual** desde
`/dashboard/app-movil` → Premios → "Categoría en la app" y sigue mandando sobre `kind`. `especial`
cae a la heurística vieja. NULL = derivada.

**Orden de la grilla**: canjeables → le faltan puntos → agotados → bloqueados por categoría; los
`is_featured` arriba de su grupo (no de la grilla: un destacado con candado sigue siendo intocable).
`proximoPremioProvider` y `premiosCanjeablesProvider` ignoran los bloqueados.

**Canje (`canje.dart`)**: `loyalty_redeem_reward(p_reward_id)` devuelve `{success, error}` con 200;
los códigos son `insufficient_points` (`required`/`available`), `tier_locked` (`tier_required`),
`out_of_stock`, `expired`, `not_available`, `program_disabled`, `client_not_found`. Un shape que no
se reconoce tampoco es éxito. La confirmación muestra "Válido por N días desde el canje" con
`validity_days` del premio o, si no lo define (los dos premios reales de Monaco), con
`program.reward_validity_days` de `get_client_loyalty` (mig 200, viaja también con el programa
apagado; si tampoco llegó, no se inventa: el vencimiento real llega en el toast y en el QR) y, para
merch, "Lo retirás en cualquier sucursal mostrando el QR". Éxito → `invalidarTrasCanje` +
`invalidarLoyalty` + push directo a `/reward-qr/<client_reward_id>`. **El `catch` también
invalida**: un timeout después de que la RPC commiteó es un canje hecho que la app no vio, y con el
saldo viejo el siguiente toque emitía un segundo canje. El tile de `VistaPreviaCanje` va verde sólo
cuando el canje ES posible (misma condición que "Te quedan N pts"); en el diálogo "Te faltan N pts"
es blanco. Si `loyaltyProvider` está en error sin valor previo, `abrirPremio` pide actualizar en vez
de decidir con el 0 de relleno.

**Beneficios canjeados** (`data/beneficio_canjeado.dart`, compartido por la tira, `/mis-premios` y
el QR): estados `available` Disponible (verde) · `redeemed` Utilizado (blanco 0.5) · `expired`
Vencido (rojo) · `cancelled` Cancelado (rojo apagado, con `cancel_reason`); un status desconocido
NUNCA se lee como disponible. Etiqueta por `kind`: "20 % de descuento [en Corte]" / "Servicio
gratis" / "Retirá en la barbería" / "Beneficio especial". `cuentaRegresiva` = "Vence en 12 días"
(verde > 7, ámbar ≤ 7, rojo vencido). `/mis-premios` tiene solapas **Para usar / Historial**; el QR
de un premio no disponible muestra el estado en vez del código.

Cosas que no hay que "arreglar" ingenuamente:

- **El acento por categoría existe porque no hay fotos.** `image_url` está en la tabla y el
  dashboard tiene el input, pero **cero filas lo tienen cargado**: la grilla real son seis tarjetas
  con un ícono. Con un solo color, las seis se leen como una mancha (verificado en el simulador).
- **Los chips salen de los datos** (`categoriasConPremiosProvider`) y van **sin ícono**: con cuatro
  chips + ícono, "Marcas" se salía de la pantalla en un iPhone de 390 pt.
- **`PremioCard.altoPara(ancho)` es la única fuente del alto**, y el bloque de texto tiene
  **alturas fijas** para que esa cuenta cierre. La grilla lo usa vía `aspectoGrilla()` y el
  carrusel del Home como `height`. La tarjeta **no degrada**: o le dan el alto que declara, o
  desborda — es a propósito. Con el bloque de texto dentro de un `Flexible`, el nombre de dos
  líneas recibía menos alto del que pide y Flutter lo **recortaba a media línea** (la segunda línea
  quedaba pisada por el subtítulo); sin `Flexible`, pedía su alto natural y desbordaba. Con altura
  fija el layout es determinista y, de paso, todas las barras de canje de la grilla quedan
  alineadas. `altoPara` lleva un `_colchon` **medido, no calculado**: las métricas reales de Poppins
  no coinciden con `fontSize × height`. `test/widget/wallet_widgets_test.dart` fija las dos medidas
  reales y falla si alguien toca la proporción sin tocar `altoPara`.
- **El orden de la grilla es "lo que podés usar primero", el del carrusel del Home es
  "catálogo primero".** Son distintos a propósito: la sección del Home se llama *Canjeá tus puntos*
  y con el orden de la grilla un cliente con 0 puntos abría con tres tarjetas GRATIS.
- **`redeem_points_for_reward` devuelve `{success:false, error}` con HTTP 200.** El código viejo no
  lo miraba: un canje rechazado por stock o por saldo le decía "Premio canjeado" al cliente y lo
  mandaba a una billetera vacía. `canje.dart` chequea `success` y traduce el error.
- **`get_client_wallet` devuelve `image_url`, `points_cost` y `category`** desde la mig 194 (antes
  sólo texto, así que la tira no podía ilustrarse).
- Los convenios **vencidos** no entran a la grilla (la pantalla `/convenios` los sigue mostrando).

## Fidelización (`features/loyalty/`, 30/ago/2026)

Categorías + puntos del programa (migs 196/197). **La app sólo pinta lo que devuelve
`get_client_loyalty()`**: umbrales, multiplicadores, colores y textos salen del server; no hay un
solo número del programa escrito en Dart.

- `data/loyalty_models.dart` — `LoyaltySummary` (`program`, `tier`, `nextTier` + `nextTierFaltan`,
  `visitsInWindow`, `grace`, `points`, `referral`, `tiers`) con `fromJson` tolerante y
  `LoyaltySummary.disabled(clientName:, balance:)` para "sin programa". `colorDesdeHex` cae a un
  gris neutro si el dashboard cargó un color ilegible. Tests: `test/unit/loyalty_models_test.dart`.
- `providers/loyalty_provider.dart` — `loyaltyProvider` (atado al `clientId` como
  `clientWalletProvider`) + `invalidarLoyalty(ref)`. **`saldoPuntosProvider` lee de acá**
  (`points.balance`) y los chips Ganados/Canjeados de `/points` también (`earned_total` /
  `redeemed_total`, mig 200); `globalPointsProvider` y `get_client_global_points` ya no se usan
  desde la app. `saldoPuntosProvider` y `premiosListosProvider` derivan con `_derivar`, que
  **conserva el último valor bueno** durante el refresh y tras un refresh fallido: `whenData`
  sobre un `AsyncLoading`/`AsyncError` con valor previo lo descarta, y la tarjeta del Home
  animaba 650 → "0 PUNTOS" en cada pull-to-refresh con la red caída
  (`test/unit/saldo_puntos_provider_test.dart`).
- `presentation/widgets/monaco_card.dart` — **`MonacoCard`**: tarjeta de crédito (1.586:1, radio
  22). Con categoría: gradiente 135° del tier, banda de brillo que recorre cada ~6 s y sigue el
  acelerómetro (`card_tilt.dart`, `sensors_plus`; sin sensor → arrastre horizontal), chip EMV,
  holograma en `platinum`, contador animado, pill "Ver progreso" → flip 3D al dorso (anillo de
  visitas, "Te faltan N", próximo vencimiento). Sin categoría → **vidrio gris** sin chip ni
  etiqueta. `tier:` la dibuja con otra categoría (carrusel), `compact:` para el carrusel. La
  tipografía **no escala con el sistema** (gráfico de proporción fija; con 1.3× desbordaba a 360 pt):
  todo el contenido viaja en `Semantics`.
  - `CardTilt.forzarSinSensor = true` en tests: `sensors_plus` dispara un `invokeMethod` sin
    await y `flutter test` lo reporta como excepción. En el host además se detecta `FLUTTER_TEST`.
- `loyalty_status_strip.dart` — pills bajo la tarjeta: categoría/progreso, puntos por vencer,
  gracia en ámbar y, **siempre**, "Canjear" (es el atajo a Premios que antes era el botón de regalo
  de la tarjeta; con el programa apagado queda sólo ésa).
- `tier_up_celebration.dart` — festejo de subida, una vez por subida: compara con
  `loyalty_last_tier_seen` (Keychain, se borra con la sesión). Primera vez = sólo guarda. Lo
  dispara el Home con `ref.listenManual(loyaltyProvider, fireImmediately: true)`.
- `screens/categoria_screen.dart` (`/categoria`) — tarjeta, bloque ámbar de gracia con "Reservar
  turno", carrusel de las 4 categorías (`PageView` 0.82 con escala) y "Cómo funciona" con los
  valores del server.
- `screens/invitar_screen.dart` (`/invitar`) — "Invitá a un amigo": header con lo que gana cada
  uno (`referral.discount_pct / referred_points / referrer_points`, cada parte sólo si tiene
  valor), QR `MNC-REF:<código>` (`referralCodeProvider` → `get_my_referral_code`, `null` = error
  con reintentar, nunca un QR vacío), código grande con copiar/compartir (`share_plus`), tres pasos
  y "Mis invitaciones" (`misReferidosProvider` → `get_client_referrals`, modelo `data/referido.dart`:
  Completada · +150 pts / Pendiente / Cancelada). Con `referral.enabled = false` la pantalla es un
  `LiquidEmptyState`: la promo la prende el dueño.
- `/points` (`features/points/`) — hero con saldo (`loyaltyProvider.points.balance`) y "120 pts
  vencen el 28/12" (`next_expiry_*`, ámbar dentro de `expiring_soon_days`), chips Ganados/Canjeados
  (`points.earned_total` / `redeemed_total` del mismo resumen), "Cómo funciona" con base /
  vencimiento / ventana / gracia del server (`LoyaltyProgram.textoGracia`: con `grace_days = 0` el
  server baja en el acto y "tenés 0 días" se leía como un bug), e historial por
  `get_client_point_history(p_limit: 80)`.
  `PointsHistoryTile` mapea ícono por `type` (`earned` tijera, `welcome_bonus` regalo,
  `referral_*` person_add, `redeemed` redeem, `expired` reloj tachado, `reversal` undo,
  `manual_adjust` tune) y en los lotes vivos dice "Vence en 40 días · quedan 80"; los `is_expired`
  van atenuados y grises, igual que los lotes **revertidos** ("Revertido": la RPC no expone
  `reversed_by`, se detectan por `meta.reversed_at` / `reversal_reason` que deja
  `loyalty_reverse_lot`; antes se leía "Ya usado" al lado de "Reversión: visita anulada").
  **"Por sucursal" se eliminó**: los puntos son globales desde la mig 196 y
  `client_points` ya no se lee desde la app (`branchPointsProvider` murió).
- Perfil → sección **Mi programa**: "Mi categoría" (subtítulo "Oro · 2 visitas para Platinum" /
  "Programa próximamente") → `/categoria` y "Invitá a un amigo" → `/invitar`. Premios muestra bajo
  el título "Cliente Oro · sumás al 110 %" → `/categoria` (sin programa, la línea no existe).
- Push: `loyalty_notify` (mig 197) escribe `type = reward | points` (el CHECK de
  `client_notifications` no admite otra cosa) y manda la familia aparte en `data.loyalty_kind`
  (`tier_up`, `near_tier`, `points_expiring`, `benefit_new`, `referral_completed_*`…). `deep_link`
  gana siempre; sin él, `PushHandler.loyaltyRouteFor(kind)` resuelve por familia (`tier*` →
  `/categoria`, `referral*` → `/invitar`, `points*` → `/points`, `benefit_new` → `/mis-premios`,
  `*reward*` → `/rewards`) antes que el `type`; la bandeja mapea ícono/acento por el mismo `kind`.
  No existe ningún `type = 'loyalty_<kind>'` ni `tier`/`referral`
  (`test/unit/push_handler_routing_test.dart`).
- Banco visual: `integration_test/wallet_preview_test.dart` capturas `loyalty_01…12` (Oro, gracia,
  categoría, Platinum, apagado, celebración).

## Home — billetera

`HomeHeader` (wordmark + campana con badge de `unreadNotificationsCountProvider`) → saludo →
**`MonacoCard`** + `LoyaltyStatusStrip` (ver *Fidelización*; `WalletPointsCard` quedó sin uso) → `TurnoTiles` → *Espera ahora* → *Canjeá tus puntos* → Cartelera.

- La tarjeta de puntos es **vidrio gris**, como el resto de la app. Se probó blanca sólida (era lo
  que mostraba el mockup) y **el dueño la rechazó**: la lámina clara rompe el lenguaje Liquid Glass
  y el Home parecía de otra app. La jerarquía la sostienen el tamaño del número y el único elemento
  claro de la tarjeta —el botón circular de regalo, que va a Premios—, no el fondo. El test
  `wallet_widgets_test.dart` fija que el número y el pie sean claros, para que el blanco no vuelva
  por accidente.
- Donde sí hay superficie blanca sólida es en `PastillaSolida` (chip de categoría seleccionado y
  pastilla de saldo de Premios): ahí "seleccionado" tiene que leerse de un vistazo, y un
  `LiquidPill` con tint blanco no alcanza — su degradado termina en 55 % del tint y el texto oscuro
  pierde contraste en la esquina inferior derecha.
- El pie de la tarjeta sale del catálogo REAL (`proximoPremioProvider` /
  `premiosCanjeablesProvider`): "A 60 pts de Corte gratis" → "Ya podés canjear 2 premios" → "Sumás
  puntos en cada visita" si no hay catálogo. Nunca se inventa un umbral: `rewards_config` está
  vacía en prod.
- `TurnoTiles`: **con** turno, dos tiles (reservar + próximo con hora grande); **sin** turno, un CTA
  ancho. Un tile "Próximo turno · —" ocupa media pantalla para decir que no hay nada.
  El countdown sólo se dibuja si falta menos de 24 h: más lejos, `Fechas.cuentaRegresiva` devuelve
  "Jue 27 ago · 18:30", que repite la línea de arriba y la hora que ya está en 29 px.
- *Espera ahora* mantiene `OccupancyMiniCard` tal cual (decisión del dueño: ese diseño ya estaba
  bien). Los accesos rápidos se eliminaron: el dock y las secciones cubren todo, y `/visits` y
  `/mis-canjes` siguen en Perfil.

**Vista previa visual sin login ni red** — el banco de pruebas del diseño:

```bash
QA_SHOTS_DIR=build/wallet-shots flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/wallet_preview_test.dart -d <udid-simulador>
```

Pinta Home (con turno / sin turno / saldo 0) y Premios (con chips) con datos fijos. **Los tres
overflows del rediseño salieron de acá y no de `flutter test`**: una tarjeta sin constraint de alto
crece lo que necesita y nunca desborda en un widget test.

Para el alta propia y el modo invitado hay un banco aparte,
`integration_test/alta_preview_test.dart` (`alta_01…10`):

```bash
QA_SHOTS_DIR=build/alta-shots flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/alta_preview_test.dart -d <udid-simulador> \
  --dart-define=GOOGLE_IOS_CLIENT_ID=x.apps.googleusercontent.com
```

El `--dart-define` **no es opcional ahí**: sin client id el botón de Google no se dibuja y la
bienvenida sale con dos botones en vez de tres. `flutter test` tampoco los ve: los dos botones
sociales se gatean con `Platform.isIOS`/`isAndroid` y el host es macOS.

### Los bancos visuales, y cuál de ellos va a la tienda

`integration_test/` tiene cinco además del recorrido de QA: `wallet_preview_test.dart` (Home y
Premios), `alta_preview_test.dart` (alta e invitado), `sena_preview_test.dart` (seña),
`dock_shot_test.dart` (sólo el dock) y **`store_shots_test.dart`, que es el único que monta el
shell REAL** (`MainShell` + `LiquidDock`) y cuyas capturas son **las que se suben a las fichas**.

```bash
xcrun simctl boot <udid-iPhone-17-Pro-Max>
QA_SHOTS_DIR=store/capturas/ios-6.9 flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/store_shots_test.dart -d <udid>
```

Por qué no alcanza con los otros y no hay que "unificarlos":

- Los preview montan **la pantalla suelta** y salen sin dock, que es lo que un comprador espera
  ver. `store_shots` pinta el dock en las tres pantallas que en la app viven dentro del
  `ShellRoute` (Inicio, Sucursales, Premios) y **no** en Bienvenida, el wizard y Mi categoría,
  porque en la app tampoco lo tienen: una captura con un dock que la pantalla real no tiene es una
  captura que miente.
- La persona es **ficticia** ("Martín", 351 555-0123). Los preview usan el nombre y el teléfono
  reales del desarrollador, y una ficha de tienda es pública.
- El simulador **tiene que ser un iPhone 17 Pro Max**: 440×956 pt @3x = 1320×2868 px, que es
  exactamente el tamaño 6.9" que pide App Store Connect. Con otro modelo la ficha las rechaza por
  medida. Las de Play (1080×2160) se derivan de esos PNG con ImageMagick — el porqué del reencuadre
  y los comandos están en `store/README.md`.
- **Verificar el contenido, no el tamaño del archivo**: un `flutter drive` incremental puede servir
  una build vieja sin decir nada (pasó el 10/9/2026 con la tira "Listos para usar"). Si salen todas
  iguales, el simulador quedó con una instancia vieja: `xcrun simctl shutdown` y bootear de nuevo.

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

**Sin Firebase, la sección de notificaciones del sistema se OCULTA, no se deshabilita.** Perfil y
Preferencias no dibujan el bloque en vez de mostrarlo apagado con un "no disponible". Es
deliberado y no hay que "mejorarlo" agregando el cartel: un interruptor que no hace nada se lee
como una app a medias (Apple lo trata así), y decir "no disponible" sería además falso — la
bandeja in-app y los toggles por tipo **sí** funcionan sin Firebase, lo único que falta es el
permiso del sistema. `firebase_crashlytics` sigue la misma regla: `main.dart` engancha los
handlers **sólo** si Firebase arrancó de verdad, así que hoy la dependencia es peso muerto y no
cambia el arranque.

## Modo prueba

`SecureStorageService.isTestModeEnabled()`: se activa con 7 toques sobre "Versión x.y.z" en Perfil
**y el código `AppConstants.testModeCode`** (`--dart-define=TEST_MODE_CODE`; vacío = el gesto no
existe). Con él, `mobileBranchesProvider` y `branchSignalsProvider` dejan de esconder la sucursal
`is_test` (slug `test`).

Tres cosas que no hay que aflojar:

- **El código no es paranoia**: `test` es una sucursal REAL de producción y toma turnos. Con sólo el
  gesto, cualquiera que lo descubriera —un reviewer probando la pantalla— podía destaparla y
  reservar ahí (Apple 2.3.1 además prohíbe features ocultas).
- **Apagarlo no pide nada** y **en modo invitado no se puede prender**: es el estado con el que un
  reviewer abre la app la primera vez.
- Prender o apagar **invalida `testModeProvider`** (y las dos listas que lo miran). Ese provider es
  un `FutureProvider` cacheado sobre el storage, así que sin invalidarlo el toast decía "modo prueba
  activado" y la sucursal recién aparecía al reiniciar la app.

## Arranque, errores y sesión zombi (10/sep/2026)

- **`main.dart` nunca deja pantalla negra.** `Supabase.initialize` lee la sesión del storage seguro
  **sin try/catch propio** (`supabase_auth.dart` llama a `hasAccessToken()` a pelo): un blob que no
  se puede descifrar —Keystore invalidado tras un update de OS o un cambio de bloqueo de pantalla en
  Samsung/Xiaomi— hacía que `initialize` reventara antes de `runApp`, y como el dato corrupto
  persiste, la app se abría en negro en CADA intento hasta desinstalarla. Ahora: lectura de prueba
  (`SecureLocalStorage.comprobarLectura`) → si falla, se limpia el storage y se reintenta UNA vez →
  si vuelve a fallar, `runApp(ArranqueFallidoApp)` con un "Reintentar" que vuelve a correr el
  arranque entero. Y ninguna lectura/escritura de `SecureLocalStorage` tira: un fallo de lectura se
  trata como "no hay sesión".
- **`detectSessionInUri: false`.** La app no usa OAuth de Supabase por deep link (el login social va
  por `client-auth` con el `id_token`), así que ese observer sólo aportaba un segundo `AppLinks`
  sobre el mismo canal que `monaco://pago` y la chance de que un `?code=`/`?error_description=` se
  tratara como callback de auth. Apagarlo elimina la clase entera de conflicto.
- **`GoRouter.errorBuilder` → `RutaNoEncontradaScreen`.** Sin él, una ubicación desconocida cae en
  el `MaterialErrorScreen` de go_router: "Page Not Found" en inglés y el `toString()` de la
  excepción sobre fondo blanco. Llega solo: los `link_value` de la cartelera y de las campañas los
  tipea el dueño a mano en `/dashboard/app-movil`, y `/catalog` y `/elegir-sucursal` existieron.
- **Sesión zombi: una sola puerta.** `MobileApi.onSesionInvalida` dispara con `UNAUTHENTICATED`/401
  y con `NO_CLIENT` (el JWT es válido pero la ficha de `clients` se borró o se fusionó desde el
  dashboard, así que Supabase **no** emite `signedOut` y la app falla en todas las pantallas).
  Cierra la sesión (`AuthNotifier.sesionInvalidada`, con guard anti-loop: sólo actúa con sesión
  abierta) y deja el aviso en `mensajeDeSesionProvider`, que la bienvenida muestra una vez. Un error
  de red **no** cierra nada.
- **Ningún `e.message` de red llega a la UI.** `MobileApiException.message` es siempre español fijo
  y el motivo técnico va en `detail` (sólo log): media app imprime `e.message` tal cual, y en modo
  avión salía «Sin conexión: Failed host lookup: '…'».
- **Toda llamada de auth tiene timeout** (`AppConstants.apiTimeout`; 6 s el `signOut` remoto, cuyo
  fallo se ignora porque lo local pasa igual). Sin eso, en un 4G que se cuelga el CTA quedaba
  girando más de un minuto, sin mensaje ni forma de reintentar.

## Nativo — lo que está configurado y por qué (no deshacer)

**iOS** (`ios/Runner/Info.plist`, `project.pbxproj`):
- `CFBundleDisplayName`/`CFBundleName` = **Monaco**; `CFBundleDevelopmentRegion = es` +
  `CFBundleLocalizations [es]` (la ficha dice español; `developmentRegion = es` en el pbxproj).
- `TARGETED_DEVICE_FAMILY = 1` (sólo iPhone). Con `"1,2"` y sólo portrait el upload muere con
  **ITMS-90474**; la UI (dock flotante) es phone-only.
- `LSApplicationQueriesSchemes [https, mailto, whatsapp, tel]`: sin eso `canLaunchUrl` devuelve
  false y los links de política/soporte del perfil no hacen nada.
- `NSLocationDefaultAccuracyReduced = true` (alcanza para ordenar sucursales). Sin usage strings
  de cámara/galería: no se usan. **La ubicación ya NO se declara en `PrivacyInfo.xcprivacy`**: sólo
  cuenta como "recolectada" la que sale del teléfono, y acá se usa en el dispositivo
  (`Geolocator.distanceBetween` en el paso de sucursal) sin que ningún endpoint reciba lat/lng. El
  usage string sí se conserva, porque el permiso se pide igual. Si algún día la posición viaja al
  server, hay que volver a declararla acá **y** en las dos fichas.
- `UIBackgroundModes [remote-notification]` + `RunnerRelease.entitlements` con `aps-environment
  production` **y `com.apple.developer.applesignin [Default]`**. Debug usa `Runner.entitlements`
  vacío a propósito (Personal Team no firma push **ni** Sign in with Apple: con `flutter run` de
  desarrollo, "Continuar con Apple" falla al abrir la hoja — se prueba en Release con el Team pago).
- `CFBundleURLTypes` lleva DOS entradas: `monaco` (vuelta del checkout de MP) y el
  **REVERSED_CLIENT_ID** de Google, hoy con un placeholder marcado. `google_sign_in` **no** lo lee
  del `GoogleService-Info.plist` (lo dice su README): sin esa entrada la hoja de Google abre y nunca
  vuelve a la app.
- **`PrivacyInfo.xcprivacy` y el formulario App Privacy tienen que decir lo mismo**: Apple cruza
  los dos, así que cada dato del archivo lleva un comentario con su propósito y de dónde sale la
  evidencia, y `store/privacy-labels.md` es la traducción a las respuestas del formulario. Declara
  **Email Address** desde el alta social (Google y Apple lo devuelven; el relay de Apple sigue
  siendo un email) con **sólo** App Functionality, y teléfono, nombre, ID de usuario e ID de
  dispositivo con App Functionality **más `DeveloperAdvertising`**: el dashboard manda campañas
  push a los tokens registrados y difusiones de WhatsApp personalizadas con `{{nombre}}`, que es
  literalmente la definición de Apple de ese propósito. Si el dueño decide que la app nunca se use
  para marketing, hay que sacar el propósito de acá **y** dejar de dirigirle campañas a esos
  tokens/teléfonos — no alcanza con cambiar la etiqueta.
- `AppDelegate.swift` setea `UNUserNotificationCenter.current().delegate = self`
  (flutter_local_notifications + firebase_messaging conviven así).
- Splash: `LaunchScreen.storyboard` generado por flutter_native_splash (fondo #0A0A0A + logo);
  el `backgroundColor` de la vista también es #0A0A0A para que no haya frame blanco.
- `ITSAppUsesNonExemptEncryption = false`.
- **Mínimo iOS 15.0** (10/sep/2026), y tiene que estar en los DOS lados: `platform :ios, '15.0'` en
  el `Podfile` y `IPHONEOS_DEPLOYMENT_TARGET = 15.0` en las **tres** configuraciones del
  `project.pbxproj`. Se subió de 14 porque Xcode 26 sólo soporta "iOS 15 or later" y Flutter está
  subiendo su mínimo (flutter/flutter#187741); no se pierde ningún equipo, porque todo iPhone que
  corre iOS 14 corre iOS 15. `scripts/preflight-tiendas.sh` avisa si los dos números se separan.
- El **`post_install` del Podfile sube a 15.0 todo pod que declare menos**. Muchos podspecs siguen
  en 9.0/10.0/11.0 (PromisesObjC, GTMSessionFetcher, flutter_secure_storage, los bundles
  `*_privacy`…) y Xcode 26 tira un warning de **Target Integrity** por cada uno, doce en total, que
  tapan los warnings que sí importan. Compilar un pod para 15.0 dentro de una app que ya exige 15.0
  no cambia nada en runtime: no es un parche riesgoso, es sacar ruido.
- **`integration_test.framework` viaja dentro del Release y no se puede sacar.** En iOS, Flutter
  3.38 instala en el target Runner los pods de todos los plugins, incluidos los de
  `dev_dependencies` — `podhelper.rb` ni mira el flag `dev_dependency` que sí trae
  `.flutter-plugins-dependencies`, mientras que Android sí los excluye. Es una limitación de esta
  versión del tool, no algo mal configurado acá: **no borrar `integration_test` del pubspec para
  "limpiar el binario"** (te quedás sin los bancos visuales y sin las capturas de la ficha). Se va
  solo cuando se suba Flutter.

**Android** (`android/app/`):
- `MainActivity : FlutterFragmentActivity` — **obligatorio** para `local_auth`
  (con `FlutterActivity` la huella falla en silencio con `no_fragment_activity`).
- `android:label="@string/app_name"` = Monaco; `enableOnBackInvokedCallback=true`.
- **Nada de backup ni de transferencia, y son TRES atributos** porque cubren cosas distintas:
  `allowBackup=false` (API < 31), `dataExtractionRules="@xml/data_extraction_rules"` (API 31+) y
  `fullBackupContent="@xml/backup_rules"` (red por si alguien vuelve a prender el backup). El del
  medio no es redundante: desde Android 12, en varios fabricantes, `allowBackup=false` apaga el
  backup en la nube pero **no** la transferencia directa entre equipos, y el teléfono nuevo recibía
  la sesión cifrada con la clave del Keystore del viejo — indescifrable— y la app quedaba clavada
  en el splash. Los dos XML excluyen **todo**, no sólo `sharedpref`: el resto es cache y nada de
  eso vale más que arrancar limpio.
- **`PROPERTY_COMPAT_ALLOW_RESTRICTED_RESIZABILITY` es un puente con fecha de vencimiento.**
  Android 16 (targetSdk 36) ignora el bloqueo a vertical en pantallas de 600 dp o más, así que en
  tablets y plegables abiertos la app saldría apaisada y estirada, y no hay layout para eso (la UI
  es phone-only, igual que `TARGETED_DEVICE_FAMILY = 1` en iOS). Esta property lo evita **hasta
  API 37**, donde Google la elimina: antes de subir el targetSdk a 37 hay que **decidir** qué se
  hace con tablets y plegables —un shell con ancho máximo, o excluirlas desde Play Console, porque
  el manifest ya no las filtra—, no simplemente subir el número.
- Permisos: son **seis** y la lista es corta a propósito — `INTERNET`, `ACCESS_NETWORK_STATE`,
  `ACCESS_COARSE_LOCATION`, `POST_NOTIFICATIONS`, `VIBRATE`, `USE_BIOMETRIC`. Lo que se fue:
  - **`ACCESS_FINE_LOCATION`**: `LocationAccuracy.medium` es `PRIORITY_BALANCED_POWER_ACCURACY` y
    anda con COARSE. Declarando FINE, geolocator lo pedía en runtime (el diálogo
    "Precisa/Aproximada" de Android 12+), había que declarar "ubicación precisa" en Data safety y
    desde 2027 justificarle a Play por qué un buscador de sucursales necesita precisión.
  - **`RECEIVE_BOOT_COMPLETED` y los dos receivers de `flutter_local_notifications`**: la app no
    programa notificaciones. No usa `zonedSchedule` ni `periodicallyShow`; el único uso del plugin
    es `show()` para pintar el push que llega en primer plano, y los recordatorios de turno los
    manda el servidor por FCM. Si algún día se agenda algo en el teléfono hay que volver a poner
    los receivers **y** sumar `SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM`.
  - La regla de ProGuard de GSON, en cambio, **se queda**: la necesita ese `show()`, no las
    notificaciones programadas (el comentario que decía lo contrario está corregido).
- `<uses-feature android:name="android.hardware.location" android:required="false"/>`: pedir
  COARSE le **implica** a Play que la app requiere hardware de ubicación y filtra del catálogo los
  equipos que no lo tienen. Acá es opcional (sin ella las sucursales se listan sin ordenar por
  cercanía), así que se declara no requerida para no achicar el alcance.
- `<queries>`: VIEW `https/mailto/tel/whatsapp` (+ PROCESS_TEXT del engine) y VIEW/https **con
  BROWSABLE** + `CustomTabsService` (sin eso, en API 30+ el checkout de MP no encuentra navegador).
- `targetSdk` queda **heredado de `flutter.targetSdkVersion`**, que en Flutter 3.38.4 ya es **36**
  (lo que Play exige para toda subida desde el 31/8/2026). Fijarlo a mano sería congelarlo.
- `google_sign_in` en Android **no** necesita el plugin google-services ni el `google-services.json`:
  le alcanza el `serverClientId` (client OAuth de tipo Web) que la app pasa por `--dart-define`.
- Meta-data FCM: `default_notification_channel_id = monaco_default`,
  `default_notification_icon = @drawable/ic_notification` (silueta blanca generada desde
  `assets/brand/app_icon_foreground.png`), `default_notification_color = @color/notification_accent`.
- `LaunchTheme`/`NormalTheme` **oscuros** (`Theme.Black.NoTitleBar`, `windowBackground =
  @color/monaco_background`) en `values`, `values-night`, `values-v31`, `values-night-v31`: sin flash
  blanco. Si se corre `flutter_native_splash:create` de nuevo, revisar que `NormalTheme` siga así.
- `build.gradle.kts`: desugaring (`desugar_jdk_libs 2.1.4`, lo pide flutter_local_notifications),
  `proguard-rules.pro` (GSON de flutter_local_notifications), y los plugins
  `com.google.gms.google-services` **y `com.google.firebase.crashlytics`** declarados en
  `settings.gradle.kts` y aplicados **sólo si existe `app/google-services.json`** (sin proyecto de
  Firebase no hay a dónde subir el mapping de R8 y el plugin de Crashlytics aborta la
  configuración; el SDK de Dart reporta igual, lo que se pierde sin el plugin es que el stack se
  lea deofuscado).
- **La firma tiene dos comportamientos distintos y es a propósito.** `android/key.properties`
  (gitignored, lo escribe `scripts/crear-keystore.sh` con la ruta **absoluta** del `.jks`) decide:
  - sin él, `flutter build apk --release` **firma con la clave de debug y compila igual** — sirve
    para probar en un equipo, no para Play;
  - sin él, `flutter build appbundle --release` **falla antes de compilar**. Play rechaza un AAB
    firmado en debug y no existe ningún uso legítimo de ese archivo, así que cortar temprano es
    mejor que cinco minutos de R8 para nada. Para saltearlo en una prueba:
    `flutter build appbundle --release -PpermitirFirmaDebug=true`.
  - El aviso va por **`logger.quiet`**: `flutter build` corre Gradle con `-q` y es el único nivel
    que sobrevive a ese flag (`warn` y `lifecycle` no se ven). No "arreglarlo" cambiándolo por
    `logger.warn`.
  - Un `key.properties` que apunta a un `.jks` que no está (máquina nueva sin el backup) cuenta
    como "sin keystore", para no romper también `flutter run`; el mensaje distingue los dos casos.
- `kotlin { compilerOptions { jvmTarget } }` a nivel proyecto, **no** `android.kotlinOptions`, que
  está deprecado desde Kotlin 2.x y KGP va a volver error. Tiene que coincidir con `compileOptions`
  (Java 17).
- **`android/gradle.properties` pide 8 GB de heap** (`-Xmx8G`, es el default del template de
  Flutter). En esta Mac está bien; en un runner de CI con 7 GB de RAM el daemon de Gradle muere sin
  un error claro. No hay que bajarlo en el repo —el build local se vuelve más lento y nadie lo
  pidió—: se pisa en el CI con `GRADLE_OPTS=-Xmx4g` (o el valor que entre en esa máquina).
- `res/raw/keep.xml` evita que `shrinkResources` tire los drawables que se referencian desde Dart.

## Tests (`test/`)

- `unit/mobile_api_test.dart` — MobileApi con `MockClient`: headers, URL, 2xx, mapeo de errores
  (`SLOT_TAKEN`, 401, `HTTP_5xx`, `BAD_RESPONSE`), red (`NETWORK`), timeout con `fakeAsync`.
- `unit/auth_state_test.dart` — los **5** `AuthStatus` en orden y que `isGuest`/`tieneCuenta` no
  son `!isAuthenticated`; `unit/constants_test.dart`, `unit/formatters_test.dart`,
  `unit/fechas_test.dart`, `unit/phone_format_test.dart`, `unit/appointment_model_test.dart`.
- `unit/sena_models_test.dart` — el ciclo de vida de la seña (un status desconocido no confirma
  nada), `SenaIntencion` (un 200 sin `init_point` no es éxito) y los párrafos de la política.
- `unit/senas_api_test.dart` — con `MockClient`: el body que se manda, y que **sólo**
  `SENA_NO_APLICA` (con 200 `ok:false` o con 409) habilita a reservar sin pagar.
- `unit/deep_link_test.dart` — `monaco://pago?deposit=` y nada más; la marca local y su vencimiento.
- `unit/premio_item_test.dart` — la derivación de categoría (por `kind` y por heurística), el
  override de `category`, el candado (`lockedByTier` / `puedeCanjear`), el shape de convenios
  (nombre = comercio, subtítulo = beneficio) y `alcanza/faltan/progreso`.
- `unit/beneficio_canjeado_test.dart` — estados y etiquetas por `kind` de un beneficio canjeado, la
  cuenta regresiva del QR y `Referido.fromJson`.
- `unit/booking_rules_test.dart` — además de la ventana de fechas y la grilla, los **tres pasos**
  del wizard y que `copyWith(bootstrap: null)` sí borra el bootstrap.
- `widget/occupancy_mini_card_test.dart` (carga Poppins real: con Ahem la pastilla desborda),
  `widget/points_history_tile_test.dart` (ícono por `type`, "Vence en N días · quedan N" con reloj
  inyectado, lote vencido atenuado).
- `widget/wallet_widgets_test.dart` — la tarjeta de puntos, `PremioCard` (incluido el bloqueado
  por categoría: "Solo Oro" visible y sin desbordar en `altoPara`) y `PremioListoCard`. Los
  casos "entra en la celda de la grilla" / "entra en el carrusel" usan `PremioCard.altoPara()`:
  son la red contra los overflows, y **hay que darles el alto real** — sin constraint la tarjeta
  crece lo que necesita y el test pasa siempre.
- `unit/install_guard_test.dart` — el guard de reinstalación con una marca en memoria: no toca nada
  si la marca está, borra sólo si hay rastro sin marca, y **falla abierto** (si algo tira, no borra
  la sesión; y si el borrado falla, la marca NO queda escrita, o los restos vivirían para siempre).
- `unit/mobile_api_test.dart` — además de la forma de las requests: que `message` no lleve el texto
  técnico (va en `detail`) y que el aviso de sesión zombi dispare con 401/`NO_CLIENT` y **no** con
  un `SLOT_TAKEN` ni con una caída de red.
- `unit/social_auth_errores_test.dart` — "Probá de nuevo" sólo donde reintentar puede funcionar:
  Android sin cuenta de Google y iPhone sin Apple ID tienen mensaje propio.
- `unit/gates_locales_test.dart` — `debeOfrecerBiometria` (la preferencia del cliente manda, no el
  hardware) y que el copy de cerrar sesión no prometa un código que el login silencioso no pide.
- `widget/pantallas_de_error_test.dart` — el `errorBuilder` del router atrapa una ruta muerta y no
  imprime la excepción.
- `widget/onboarding_flow_test.dart` — bienvenida con las opciones en la primera pantalla, el campo
  Nombre dentro de la pantalla del código (y que el sexto dígito **no** auto-envía cuando está), el
  nombre de Google precargado, y que `clearSession()` borra PIN/biometría/invitado pero **no** el
  `device_secret`.
- Las pantallas con animaciones en loop (LED que pulsa) no admiten `pumpAndSettle`: bombear frames.
- `DateFormat('es')` tira `LocaleDataException` dentro del `build`: los tests que rendericen fechas
  necesitan `initializeDateFormatting('es')` en el `setUpAll` (en la app lo hace `main.dart`).

## Convenciones

- UI y comentarios en español rioplatense; sin emojis en UI (íconos Material `_rounded`); sin `TODO` sin dueño.
- Código nuevo: `withValues(alpha:)` (no `withOpacity`), `debugPrint('[modulo] …')` (no `print`).
- Toda lista: skeleton / `LiquidEmptyState` / `LiquidErrorState` con reintentar / `RefreshIndicator`;
  padding inferior 120 dentro del shell (el dock tapa).
- Fechas: `Fechas.*` para turnos; `Formatters.*` para el resto; locale `es_AR`.

## Riesgos conocidos

1. **Firebase a medias es peor que sin Firebase**: correr `flutterfire configure` sin subir la APNs
   key y sin Developer Program deja el prompt de permiso prendido y el token nunca llega.
2. **`flutter_secure_storage` se sube en DOS releases: 9 → 10 → 11, nunca directo.** Ahí viven el
   `device_secret` y la sesión de Supabase de **todos** los clientes. La 10.x migra el dato
   existente a `AES_GCM_NoPadding` en la primera lectura, y el changelog de la 11.x dice, textual,
   que los datos de la 9 quedan *"unusable after this upgrade"* si no se pasó por la 10. O sea que
   un `flutter pub upgrade --major-versions` distraído **desloguea a toda la base instalada**, y
   con `allowBackup=false` no hay vuelta atrás: cada cliente vuelve a pasar por el OTP de WhatsApp.
   El camino es subir a `^10.3.1` con
   `AndroidOptions(encryptedSharedPreferences: true, migrateOnAlgorithmChange: true, resetOnError: true)`,
   **publicar esa versión y esperar adopción**, probar en un equipo real que traía sesión de la
   9.2.4, y recién entonces la 11.
3. Reinstalar la app regenera `device_secret`: el cliente vuelve a pasar por OTP (esperado). Con
   Google/Apple vinculado, en cambio, vuelve a entrar de un toque — que es la mitad del punto de
   haberlos agregado. **En iOS eso es cierto sólo desde el 10/sep/2026**: el Keychain
   (`kSecClassGenericPassword`) NO se borra al desinstalar la app, así que la sesión, el
   `device_secret`, el PIN y la biometría sobrevivían y un teléfono que se vendía o se prestaba
   volvía a abrir **logueado en la cuenta anterior** al reinstalar. Lo cierra `InstallGuard`
   (`core/auth/install_guard.dart`), que corre **antes** de `Supabase.initialize`: una marca
   `instalacion_ok` en `SharedPreferences` —que sí se borra al desinstalar— y, si no está pero la
   caja fuerte tiene rastro, se limpia todo. Falla abierto (un error de lectura no borra nada) y
   la primera apertura después de actualizar desde una versión sin marca hace pasar por OTP una
   vez, a propósito.
4. `FlutterFragmentActivity` + biometría hay que probarlos en un Android real (no hay emulador con huella).
5. Los `defaultValue` de `AppConstants` apuntan a producción: un `flutter run` pelado pega a prod.
6. El Personal Team `A3WAXVR55Z` no puede archivar para App Store ni firmar push **ni Sign in with
   Apple**: hace falta el Apple Developer Program pago (ver `ENTREGA.md`).
7. **Los client IDs de Google son placeholders**: `AppConstants.googleIosClientId` /
   `googleServerClientId` vacíos y `com.googleusercontent.apps.PLACEHOLDER-REEMPLAZAR` en el
   `Info.plist`. Mientras estén así, el botón de Google no aparece (a propósito) y el alta social
   sólo funciona con Apple. Los mismos ids tienen que estar en el secret `GOOGLE_CLIENT_IDS` de
   `client-auth`, o el server devuelve `SOCIAL_TOKEN_INVALID`. Detalle en `ENTREGA.md` §4-bis.
8. **La vidriera de Premios de un invitado no muestra el catálogo real** porque no hay ninguna RPC
   con grant a `anon` que lo devuelva. Si el dueño quiere que se vean los premios y sus puntos sin
   cuenta, hay que agregar del lado del dashboard un `get_public_loyalty_catalog(p_org_id)` (o una
   policy de lectura pública sobre `reward_catalog`) y engancharlo en `_VidrieraInvitado`.
