# Monaco — App de clientes · Entrega v2.0 (rediseño 2026-08)

## Resumen

App Flutter para los clientes de **Monaco Barber Studio** (identidad **Monaco**, antes
"barberOS / Monaco Mobile"). Mono-organización y **sin sucursal**: es la app de Monaco entera y la
sucursal se elige en el paso 1 de la reserva. Liquid Glass en todas las pantallas; login por
**código de WhatsApp (OTP)**; **turnos nativos** reservados a través de la API mobile del dashboard
(un solo motor de disponibilidad); **push FCM**; modo prueba para la sucursal Test. Comparte
Supabase con `../MonacoSmartBarber`.

> **El paso a paso para publicar está en [`PUBLICAR.md`](PUBLICAR.md)** (cuentas, credenciales,
> compilar y subir, escrito para alguien que nunca publicó una app). Este documento dice qué hay
> y por qué; ése dice qué hacer y en qué orden.

| Métrica | Valor |
|---|---|
| Versión | `2.0.0+20` (`pubspec.yaml`) |
| Flutter / Dart | 3.38.4 / 3.10.3 |
| Tests | 417 (unit + widget), `flutter test` en verde; `dart analyze` en **0 errores / 0 warnings / 0 infos** |
| Plataformas | **iOS 15+** sólo iPhone vertical · Android minSdk 24 / target 36 |
| Nombre visible | **Monaco** en el teléfono (`CFBundleDisplayName`, `@string/app_name`) · **Monaco Barber Studio** en las fichas de las tiendas (ver abajo) |
| IDs | iOS `com.monacobarber.monacoMobile` · Android `com.monacobarber.monaco_mobile` (no cambiar después del primer upload) |

## Qué incluye

### Flujo del cliente
0. **Alta propia + modo invitado** (sep/2026). La bienvenida ofrece **Continuar con Google**,
   **Continuar con Apple** (sólo iOS), **Usar mi número de teléfono** y **Seguir mirando**.
   Cualquiera puede crearse la cuenta desde la app: ya no hay que pasar por la tablet del local.
   Sin cuenta se navega el Home, las sucursales con la fila en vivo, la cartelera y la vidriera de
   premios; el muro de login aparece **al tocar la acción** (reservar, canjear, mis turnos, mis
   puntos, perfil) y siempre tiene "Ahora no". Es requisito de App Store (5.1.1), no una mejora.
1. **Splash / Welcome / Login** — teléfono → `start` → login silencioso si el dispositivo ya es
   conocido, o código de 6 dígitos por WhatsApp (`/login/codigo`), **con el campo Nombre en la
   misma pantalla** si el teléfono es nuevo (`/login/nombre` se eliminó) → Home. Con Google/Apple
   es lo mismo, con el `signup_token` viajando en `start` y en `verify`. **Ya no hay paso de
   sucursal**: se elige en el paso 1 de la reserva.
2. **Home — billetera** — marca + campana con badge, saludo, **tarjeta de puntos** (vidrio) con el
   progreso hacia el próximo premio del catálogo, tiles de reservar / próximo turno, *Espera ahora*
   (fila en vivo de las tres sucursales) y el carrusel *Canjeá tus puntos*.
3. **Turnos** (`/turnos`, `/turnos/reservar`, `/turnos/:id`) — listado próximos/anteriores,
   wizard de reserva de **tres pasos (sucursal → servicio → día y hora**, barbero opcional),
   detalle con mapa, cancelación con la misma regla de ventana que el server.
4. **Sucursales** (`/occupancy`, `/branch/:id`) — fila en vivo, barberos, ETA.
5. **Premios** (`/rewards`) — una sola pantalla: tira "listos para usar" con el QR + grilla de
   2 columnas con chips **Todo / Cortes / Merch / Marcas**, que unifica el catálogo por puntos y
   los convenios con comercios (estos con pastilla GRATIS). `/mis-premios` es la billetera
   completa. Además: **Puntos / QR de canje / Mis canjes / Convenios / Reseñas / Cartelera / Visitas**.
6. **Notificaciones** (`/notificaciones`, `/notificaciones/preferencias`) — bandeja
   `client_notifications` en tiempo real + preferencias por tipo.
7. **Perfil** — nombre, teléfono, biometría y PIN local, notificaciones, legales,
   soporte (mail / WhatsApp), eliminar cuenta (Apple 5.1.1(v)), versión (7 toques → modo prueba).

### Backend que consume
- **Supabase** (Auth + PostgREST + Realtime + Edge Functions): `client-auth` **v3** (OTP WhatsApp
  + acción `social` para Google/Apple + alta propia),
  `send-push` (FCM v1), `delete-client-account`. RLS "propia" por `auth.uid()` para clientes.
- **API mobile** (`MonacoSmartBarber/src/app/api/mobile/**`, Bearer del cliente, rate-limit por
  usuario): `turnos/branches`, `turnos/[slug]`, `turnos/[slug]/slots`, `turnos/[slug]/book`,
  `turnos/cancel`, `me`, `push/token`. Errores siempre `{ error, message }` JSON.

## Nativo y tiendas — qué quedó resuelto en esta entrega

| Ítem | Estado |
|---|---|
| Nombre "Monaco" iOS/Android | Hecho (`Info.plist`, `strings.xml`) |
| Íconos reales (iOS AppIcon 25 tamaños, Android mipmap + adaptive + monochrome) | Hecho — generados con `flutter_launcher_icons` desde `assets/brand/` |
| Splash nativo negro #0A0A0A con logo (iOS storyboard, Android incl. API 31+) | Hecho — `flutter_native_splash`; `LaunchTheme`/`NormalTheme` oscuros, sin flash blanco |
| Idioma de la ficha | `CFBundleDevelopmentRegion = es`, `CFBundleLocalizations [es]`, `developmentRegion = es` |
| iPad (ITMS-90474) | `TARGETED_DEVICE_FAMILY = 1` (sólo iPhone) |
| Links que "no hacían nada" (mailto/https/tel/whatsapp) | `LSApplicationQueriesSchemes` + `<queries>` Android |
| iOS mínimo | **15.0** en el `Podfile` y en las tres configuraciones del `project.pbxproj`; el `post_install` sube a 15.0 los pods que declaran mínimos viejos (Xcode 26 tira un warning de Target Integrity por cada uno) |
| Ubicación | **Sólo aproximada**: `ACCESS_COARSE_LOCATION` en Android (se sacó `ACCESS_FINE_LOCATION`) y `NSLocationDefaultAccuracyReduced = true` en iOS. **No se declara como dato recolectado** en ninguna de las dos fichas: se usa en el teléfono para ordenar sucursales por cercanía (`Geolocator.distanceBetween`) y no viaja a ningún servidor |
| Telemetría de crashes | `firebase_crashlytics` enganchado en `main.dart` **sólo si Firebase arrancó**; apagado en debug. Obliga a declarar *Crash Data* / *Diagnóstico* en las dos fichas |
| Biometría Android rota | `MainActivity : FlutterFragmentActivity` |
| Permisos Android | Son **seis** y ninguno más: `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_COARSE_LOCATION`, `POST_NOTIFICATIONS`, `VIBRATE`, `USE_BIOMETRIC`. Más `<uses-feature android.hardware.location required="false">`, para que pedir ubicación no filtre del catálogo de Play a los equipos sin ese hardware |
| Push Android | canal `monaco_default`, ícono monocromo `ic_notification`, color de acento, desugaring + ProGuard. **Sin `RECEIVE_BOOT_COMPLETED` ni los receivers de `flutter_local_notifications`**: la app no programa notificaciones (no usa `zonedSchedule`), sólo pinta con `show()` el push que llega en primer plano; los recordatorios los manda el servidor. Si algún día se agenda algo local, hay que volver a agregarlos |
| Firma Android release | `signingConfigs.release` desde `android/key.properties`, que escribe **`scripts/crear-keystore.sh`** (keystore en `~/.monaco-keys/`, fuera de todo repo). `flutter build apk --release` sin ese archivo cae a la clave de **debug** y avisa; `flutter build appbundle --release` **falla a propósito**, porque un AAB firmado con debug no lo acepta Play y no hay ningún uso legítimo de ese archivo |
| Firebase opcional en build | los plugins `google-services` **y `firebase-crashlytics`** se aplican sólo si existe `android/app/google-services.json` (sin proyecto no hay a dónde subir el mapping de R8); iOS usa `firebase_options.dart` |
| Backup Android | Tres atributos, no uno: `allowBackup=false` (API < 31), `dataExtractionRules` (API 31+, que es lo único que frena la **transferencia directa entre equipos**) y `fullBackupContent` como red. La sesión está cifrada con una clave del Keystore de ESE teléfono: restaurarla en otro deja datos indescifrables y la app clavada en el splash |
| Reinstalación en iOS | `InstallGuard` corre antes de `Supabase.initialize`: el Keychain sobrevive a desinstalar la app, así que sin esto un teléfono que se vende o se presta volvía a abrir **logueado en la cuenta anterior** |
| Export compliance | `ITSAppUsesNonExemptEncryption = false` |
| Legales / soporte | `AppConstants` → `https://monacobarber.vercel.app/{privacidad,terminos,soporte,eliminar-cuenta,arrepentimiento}` del dashboard, mail y WhatsApp reales. **Las cinco páginas tienen que estar deployadas antes de enviar a revisión**: Apple pide una Support URL que funcione y Play pide la URL de borrado de cuenta |
| Material de las fichas | En **`store/`** (textos, capturas, ícono 512, feature graphic, etiquetas de privacidad). Ver `store/README.md` |
| Código muerto | WebView de reserva, selección de org, PIN remoto, `barberos_logo`/`bos_icon`, tests viejos |

## Verificación

```bash
dart analyze lib/ test/ integration_test/   # 0 errores, 0 warnings y 0 infos (medido el 10/9/2026)
flutter test                                # 417 tests, todos en verde
flutter build apk --debug                   # compila lo nativo Android (FlutterFragmentActivity, gradle nuevo)
flutter build ios --debug --no-codesign     # compila lo nativo iOS (AppDelegate, pods, assets)
./scripts/preflight-tiendas.sh              # placeholders, firma, Team de Apple, client IDs y secrets de client-auth
```

El baseline de `dart analyze` es **0/0/0**, no "sin errores": si aparece un info, es nuevo y hay
que mirarlo. `analysis_options.yaml` explica qué lints quedaron afuera a propósito y cuántos
hallazgos tendría cada uno hoy — un lint que nace con 40 infos no protege nada, enseña a ignorar
la salida.

## Lo que falta y es del dueño (no es código)

1. **Apple Developer Program** (USD 99/año). Hoy el Team `A3WAXVR55Z` es un Apple ID gratuito:
   no hay TestFlight ni App Store ni firma de push. Con el programa: cambiar `DEVELOPMENT_TEAM`,
   crear el App ID `com.monacobarber.monacoMobile` con Push, subir la **APNs key** a Firebase.
2. **Firebase**: crear el proyecto, `flutterfire configure` (ver README), subir la **APNs key** y
   cargar `FCM_SERVICE_ACCOUNT_JSON` en la edge function `send-push`. Mientras tanto la app
   funciona sin push, y **la sección de notificaciones del sistema no se dibuja**: Perfil y
   Preferencias esconden el bloque entero en vez de mostrarlo apagado con un "no disponible". Un
   interruptor que no hace nada es una función a medias —Apple lo lee como app incompleta— y
   además la bandeja in-app y los toggles por tipo sí andan sin Firebase, así que anunciar "no
   disponible" sería mentira. Crashlytics viaja en el mismo paquete: sin Firebase configurado, la
   dependencia es peso muerto y no engancha ningún handler.
3. **Keystore Android**: `./scripts/crear-keystore.sh` lo genera **una sola vez** en
   `~/.monaco-keys/monaco-release.jks`, escribe `android/key.properties` con la ruta absoluta e
   imprime el SHA-1/SHA-256 que pide Google Cloud. Backup del `.jks` y de la contraseña fuera de
   la Mac, hoy: sin ese archivo no se puede publicar ninguna actualización. Play App Signing al
   subir el primer AAB (y ojo, ahí aparece un SHA-1 **distinto**, el de la clave de firma de Play,
   que también hay que cargar en Google Cloud o "Continuar con Google" falla sólo en la versión
   de la tienda).
4. **Template de WhatsApp `monaco_codigo_acceso`** aprobado en la WABA (categoría AUTHENTICATION).

4-bis. **Ingreso con Google y con Apple** (alta propia, sep/2026). Es lo único que falta para que
   los dos botones de la bienvenida funcionen; mientras no estén, el de Google **no se dibuja**
   (`SocialAuthService.googleConfigurado`) y el de Apple falla al abrir la hoja si la build no está
   firmada con el Team pago. Hace falta, con estos nombres exactos:
   - **Google Cloud → APIs y servicios → Credenciales**, en el mismo proyecto que Firebase:
     un **client OAuth de tipo iOS** (bundle `com.monacobarber.monacoMobile`), uno **de tipo
     Android** (package `com.monacobarber.monaco_mobile` + SHA-1 del keystore de release **y** del
     de debug) y uno **de tipo Web** (el "serverClientId").
   - En la app: `--dart-define=GOOGLE_IOS_CLIENT_ID=<el de iOS>` y
     `--dart-define=GOOGLE_SERVER_CLIENT_ID=<el Web>` (`AppConstants`). El de Android no se pasa
     por Dart: Google lo resuelve por firma.
   - En `ios/Runner/Info.plist`: reemplazar `com.googleusercontent.apps.PLACEHOLDER-REEMPLAZAR`
     por el **REVERSED_CLIENT_ID** del client de iOS (el client id invertido). Está marcado con un
     comentario "⚠️ PLACEHOLDER". Sin esto la hoja de Google abre y nunca vuelve a la app.
   - Los **secrets de la edge function `client-auth`** (Supabase → Edge Functions → Secrets, o
     `supabase secrets set`). Al 10/9/2026 siguen pendientes y son ocho:

     | Secret | Para qué | Si falta |
     |---|---|---|
     | `GOOGLE_CLIENT_IDS` | lista cerrada de `aud` de Google, los ids separados por coma (iOS, Android de subida, Android de debug, Android de Play App Signing, Web) | `social` contesta **503 `SOCIAL_VERIFY_UNAVAILABLE`**: el botón de Google falla siempre |
     | `APPLE_BUNDLE_IDS` | `com.monacobarber.monacoMobile` | ídem para Apple — y con Google visible, eso es rechazo por la 4.8 |
     | `AUTH_TEST_PHONES` | `1100000000=123456`, la cuenta demo del revisor (código fijo, **no** manda WhatsApp) | Apple rechaza por la 2.1: "no pudimos entrar" |
     | `OTP_PEPPER` | sal del hash de los códigos en `client_otp_challenges` | la función usa 32 chars de la service role key: anda, pero rotar esa clave invalida los códigos vivos |
     | `SIGNUP_TOKEN_SECRET` | firma el `signup_token` HMAC de 15 min del alta social | reusa `OTP_PEPPER` (aceptable, pero atar dos secretos distintos al mismo valor es deuda) |
     | `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY` | revocar el token de Apple al borrar la cuenta (`POST https://appleid.apple.com/auth/revoke`), que Apple exige | la cuenta se borra igual, pero Monaco queda entre las apps autorizadas de ese Apple ID |

     **Los tres de Apple hay que cargarlos igual, pero solos no alcanzan**: al 10/9/2026
     `client-auth` no los lee (`index.ts` sólo consume los otros cinco) porque la revocación
     todavía no está implementada — falta que la app mande el `authorization_code` de Apple, que
     dura 5 minutos y sólo llega en el PRIMER login, y una columna donde guardarlo. Está
     registrado como pendiente en el `CLAUDE.md` de la raíz; tenerlos cargados es lo que hace que
     el día que se implemente no haya que volver a pedirle el `.p8` a nadie.

     Un id que esté en la app y no en `GOOGLE_CLIENT_IDS` devuelve `SOCIAL_TOKEN_INVALID`.
     `./scripts/preflight-tiendas.sh` prueba los dos proveedores contra la función con un token
     basura: **401 `SOCIAL_TOKEN_INVALID` es el resultado BUENO** (los secrets están y rechazó lo
     que tenía que rechazar); 503 es el que corta.
   - En **developer.apple.com**: habilitar la capability *Sign in with Apple* en el App ID
     `com.monacobarber.monacoMobile` y regenerar el perfil. El entitlement ya está en
     `RunnerRelease.entitlements`; con la capability apagada del otro lado, la firma falla.
   - En la base: `organizations.allow_client_signup = true` (ya está, sólo para Monaco). Con
     `false`, la app vuelve a rechazar a los que no son clientes.
5. **Fichas de tienda**: ya **no es un pendiente de armado**, es de copiar y pegar. Todo el
   material está en **`store/`** — índice y comandos para regenerarlo en
   [`store/README.md`](store/README.md):

   | Qué | Archivo |
   |---|---|
   | Textos de App Store, cuestionario de edad, notas para el revisor | `store/app-store.md` |
   | Textos de Play, IARC, "Acceso a la app" | `store/play-store.md` |
   | App Privacy de Apple, respuesta por respuesta | `store/privacy-labels.md` |
   | Seguridad de los datos de Play, respuesta por respuesta | `store/data-safety.md` |
   | Capturas 6.9" (1320×2868) y de Play (1080×2160) | `store/capturas/{ios-6.9,play}/` |
   | Ícono 512 y gráfico de la función | `store/play/` · ícono 1024 en `store/app-store/` |

   Tres cosas de ahí que hay que decidir o saber, no sólo pegar:
   - **El nombre de las dos fichas es "Monaco Barber Studio"**, no "Monaco": `Monaco` a secas ya
     está tomado en el App Store (`com.getmeback.monaco`) y Apple exige nombre único a nivel
     mundial — al registrarlo devuelve *"The App Name you entered is already being used"*. **El
     nombre en el teléfono sigue siendo "Monaco"** (`CFBundleDisplayName` / `@string/app_name`):
     son campos distintos y pueden diferir. No hay que tocar el binario por esto.
   - **La ubicación NO se declara como dato recolectado**, ni en Apple ni en Play. Sólo cuenta como
     "recolectado" lo que sale del teléfono, y la posición se usa en el dispositivo para ordenar
     sucursales por cercanía: ningún endpoint manda lat/lng. Parece un olvido y no lo es; declararla
     obliga a justificarla y no describe lo que la app hace. Si algún día viaja al server, hay que
     declararla en los dos formularios **y** en `PrivacyInfo.xcprivacy`.
   - **Teléfono, nombre, ID de usuario e ID de dispositivo llevan también el propósito de marketing
     del desarrollador**, además de "funciones de la app": el dashboard manda campañas push a los
     dispositivos registrados y difusiones de WhatsApp a `clients.phone` personalizadas con
     `{{nombre}}`. Apple define ese propósito como *"sending marketing communications directly to
     your users"*, que es exactamente esto. Declarar sólo App Functionality sería falso. Y hay que
     declarar **Crash Data / registros de fallos** (Apple: Diagnostics → Crash Data, *not linked*;
     Play: Diagnóstico), porque la app ahora trae Crashlytics — aunque hoy no mande nada, porque
     Firebase todavía no está configurado: la etiqueta describe lo que el binario puede hacer, no
     lo que hizo esta semana.
6. **Seña por Mercado Pago** (feature nueva, sep/2026). Sin esto la app se comporta como siempre
   —`SENA_NO_APLICA` y reserva directa—, así que no bloquea publicar; pero para cobrar hace falta:
   - Conectar **una cuenta de Mercado Pago por sucursal** desde el dashboard y prender
     `branch_deposit_settings.is_enabled` (hoy las 4 sucursales están en `false`).
   - Que existan en producción los dos route handlers que la app consume:
     `POST /api/mobile/turnos/[slug]/sena` y `GET /api/mobile/senas/[id]`, más la página
     `https://monacobarber.vercel.app/pago/<id>` que rebota al deep link `monaco://pago?deposit=<id>`
     (MP sólo acepta `back_urls` https y no admite esquemas propios).
   - **Probar el retorno en un equipo real** con credenciales de PRUEBA de MP: el simulador de iOS
     no abre Safari externo y el emulador de Android no siempre tiene Custom Tabs.
   - Nada de esto agrega permisos nuevos a las fichas de tienda: no hay compras in-app (es un
     servicio presencial que se paga por un proveedor externo, no contenido digital), así que
     **no aplica Apple 3.1.1**. En privacidad va **Purchase History** (ya declarado en
     `PrivacyInfo.xcprivacy` y en `store/privacy-labels.md`) y **NO Payment Info**: el checkout se
     abre en el navegador del sistema y la app nunca ve la tarjeta. Declarar datos de pago que no
     tocamos no es "ir a lo seguro", es describir mal lo que la app hace.

7. **Datos**: desactivar/ocultar la org `test` y la sucursal Test para usuarios comunes (la app ya
   la esconde; el turnero web no), cargar `staff_schedules`/agenda de turnos de las sucursales
   que se activen.

## Notas de revisión de tienda

- La reserva de turnos es nativa (no hay WebView): no aplica Apple 4.2.
- Eliminar cuenta: botón en Perfil → edge function `delete-client-account` (debe estar deployada
  en prod antes de enviar a revisión). **Hay un caso en que la baja se rechaza y es correcto**: un
  cliente con una **seña pagada sin resolver** (migración 215 → la RPC corta con `deposit_pending`,
  la función contesta **409 `DEPOSIT_PENDING`**). Es plata del cliente en la cuenta de la sucursal
  y resolverla —devolución, pérdida o arrepentimiento— la hace el camino TypeScript al cancelar el
  turno, que es el único que habla con Mercado Pago; borrar la ficha con la seña en el aire es
  justo lo que los términos §9 prometen que no pasa. Dos cosas que hay que cuidar: **probar la baja
  con la cuenta demo antes de enviar** (una cuenta demo con una seña viva le mostraría al revisor
  una app que no deja borrar la cuenta, que es rechazo por la 5.1.1(v)), y que el texto del campo
  `error` de esa respuesta esté en **español y explique qué hacer** — la app lo muestra tal cual
  (`auth_service.dart → deleteAccount`), así que un código pelado como "DEPOSIT_PENDING" es lo que
  leería el cliente.
- Ubicación: opcional y **aproximada**, sólo para ordenar sucursales; la app funciona igual si se
  niega. No se declara como dato recolectado (ver el punto 5 de arriba).
- Notificaciones: el permiso se pide después de explicar para qué (no en el primer arranque), y
  **nunca antes de que haya cuenta**: el perfil de invitado no dibuja ese interruptor (5.1.2(i)).
- **5.1.1 — "Seguir mirando"**: la app abre y se usa sin cuenta. El login aparece sólo al tocar una
  acción que necesita identidad, con el motivo escrito y con "Ahora no".
- **4.8 — Sign in with Apple**: se ofrece junto a Google, en iOS, con el flujo nativo. En Android no
  se muestra a propósito (ahí `sign_in_with_apple` abre un Custom Tab contra un servidor propio y
  deja de ser nativo; la 4.8 es de la App Store). Ojo: `SignInWithApple.isAvailable()` devuelve
  `true` en Android, así que **no sirve como gate** — el gate es `Platform.isIOS`.
- Cuestionario de privacidad: **Email Address** va vinculado y **sólo** con App Functionality
  (Google y Apple lo devuelven al crear la cuenta y se guarda en `clients.email`; el relay de Apple
  `@privaterelay.appleid.com` sigue siendo un email). No lleva el propósito de marketing porque
  ningún código del dashboard le manda mail a un cliente — verificado el 10/9/2026: el helper de
  Resend es para facturarle a los dueños de barberías, no a clientes. Si eso cambia, hay que sumar
  el propósito acá **y** en `PrivacyInfo.xcprivacy`, que es el archivo que Apple cruza contra las
  respuestas del formulario.
- El manifiesto `PrivacyInfo.xcprivacy` y el formulario de App Store Connect **tienen que decir lo
  mismo**: Apple compara los dos. Cada dato del archivo lleva un comentario con el propósito y la
  evidencia, y `store/privacy-labels.md` traduce eso a las respuestas exactas del formulario.
- `integration_test.framework` viaja dentro del Release de iOS y **no hay que "sacarlo"**: en iOS,
  Flutter 3.38 mete en el target Runner los pods de todos los plugins, incluidos los de
  `dev_dependencies` (por eso `integration_test` aparece en `ios/Podfile.lock`), cosa que en
  Android sí se excluye. Es una limitación de esta versión del tool, no algo mal configurado en el
  proyecto; se va cuando se suba Flutter.
