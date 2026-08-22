# Monaco — App de clientes · Entrega v2.0 (rediseño 2026-08)

## Resumen

App Flutter para los clientes de **Monaco Barber Studio** (identidad **Monaco**, antes
"barberOS / Monaco Mobile"). Mono-organización, con elección de sucursal; Liquid Glass en todas
las pantallas; login por **código de WhatsApp (OTP)**; **turnos nativos** reservados a través de
la API mobile del dashboard (un solo motor de disponibilidad); **push FCM**; modo prueba para la
sucursal Test. Comparte Supabase con `../MonacoSmartBarber`.

| Métrica | Valor |
|---|---|
| Versión | `2.0.0+20` (`pubspec.yaml`) |
| Flutter / Dart | 3.38.4 / 3.10.3 |
| Tests | 166 (unit + widget), `flutter test` en verde |
| Plataformas | iOS 14+ sólo iPhone vertical · Android minSdk 24 / target 36 |
| Nombre visible | Monaco (`CFBundleDisplayName`, `@string/app_name`) |
| IDs | iOS `com.monacobarber.monacoMobile` · Android `com.monacobarber.monaco_mobile` (no cambiar después del primer upload) |

## Qué incluye

### Flujo del cliente
1. **Splash / Welcome / Login** — teléfono → `start` → login silencioso si el dispositivo ya es
   conocido, o código de 6 dígitos por WhatsApp (`/login/codigo`), nombre si es cliente nuevo
   (`/login/nombre`) → elegir sucursal (`/elegir-sucursal?onboarding=1`) → Home.
2. **Home** — saludo, puntos, sucursal elegida (pill para cambiar), ocupación en vivo, próximo
   turno, cartelera, convenios, accesos.
3. **Turnos** (`/turnos`, `/turnos/reservar`, `/turnos/:id`) — listado próximos/anteriores,
   wizard de reserva (servicio → día y hora → barbero opcional → confirmar), detalle con mapa,
   cancelación con la misma regla de ventana que el server.
4. **Sucursales** (`/occupancy`, `/branch/:id`) — fila en vivo, barberos, ETA.
5. **Premios / Puntos / Catálogo / QR de canje / Mis canjes / Convenios / Reseñas / Cartelera / Visitas**.
6. **Notificaciones** (`/notificaciones`, `/notificaciones/preferencias`) — bandeja
   `client_notifications` en tiempo real + preferencias por tipo.
7. **Perfil** — nombre, teléfono, sucursal, biometría y PIN local, notificaciones, legales,
   soporte (mail / WhatsApp), eliminar cuenta (Apple 5.1.1(v)), versión (7 toques → modo prueba).

### Backend que consume
- **Supabase** (Auth + PostgREST + Realtime + Edge Functions): `client-auth` v2 (OTP WhatsApp),
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
| Ubicación | `NSLocationDefaultAccuracyReduced = true`; texto de uso revisado; `PrivacyInfo` coherente (Coarse) |
| Biometría Android rota | `MainActivity : FlutterFragmentActivity` |
| Permisos Android explícitos | `INTERNET`, `POST_NOTIFICATIONS`, ubicación, biometría, boot/vibrate para notificaciones |
| Push Android | canal `monaco_default`, ícono monocromo `ic_notification`, color de acento, receivers de notificaciones locales, desugaring + ProGuard |
| Firma Android release | `signingConfigs.release` desde `android/key.properties` (+ `key.properties.example`), fallback a debug si no existe |
| Firebase opcional en build | `google-services` aplicado sólo si existe `google-services.json`; iOS usa `firebase_options.dart` |
| Backup Android | `allowBackup=false` (la sesión cifrada no sobrevive a un restore) |
| Export compliance | `ITSAppUsesNonExemptEncryption = false` |
| Legales / soporte | `AppConstants` → `…/privacidad`, `…/terminos` del dashboard, mail y WhatsApp reales |
| Código muerto | WebView de reserva, selección de org, PIN remoto, `barberos_logo`/`bos_icon`, tests viejos |

## Verificación

```bash
dart analyze lib/ test/            # sin errores ni warnings en lo nativo/tests de esta entrega
flutter test                       # 166 tests, todos en verde
flutter build apk --debug          # compila lo nativo Android (FlutterFragmentActivity, gradle nuevo)
flutter build ios --debug --no-codesign   # compila lo nativo iOS (AppDelegate, pods, assets)
```

## Lo que falta y es del dueño (no es código)

1. **Apple Developer Program** (USD 99/año). Hoy el Team `A3WAXVR55Z` es un Apple ID gratuito:
   no hay TestFlight ni App Store ni firma de push. Con el programa: cambiar `DEVELOPMENT_TEAM`,
   crear el App ID `com.monacobarber.monacoMobile` con Push, subir la **APNs key** a Firebase.
2. **Firebase**: crear el proyecto, `flutterfire configure` (ver README), cargar
   `FCM_SERVICE_ACCOUNT_JSON` en la edge function `send-push`. Mientras tanto la app funciona sin push.
3. **Keystore Android**: generar `monaco-release.jks` (comando en `android/key.properties.example`),
   guardarlo fuera del repo con backup, crear `android/key.properties`. Play App Signing al subir el AAB.
4. **Template de WhatsApp `monaco_codigo_acceso`** aprobado en la WABA (categoría AUTHENTICATION)
   y `AUTH_TEST_PHONES` con un teléfono de prueba para el reviewer de Apple/Google.
5. **Fichas de tienda**: capturas, descripción, URL de privacidad
   (`https://monaco-smart-barber.vercel.app/privacidad`) y términos (`/terminos` — publicar la
   página en el dashboard si todavía no existe), email de soporte, cuestionario de privacidad
   (Phone Number, Name, User ID, Device ID, Coarse Location, Purchase History, Product
   Interaction, Other User Content, Customer Support — todos vinculados, sin tracking) y Data Safety
   de Play con el mismo set.
6. **Datos**: desactivar/ocultar la org `test` y la sucursal Test para usuarios comunes (la app ya
   la esconde; el turnero web no), cargar `staff_schedules`/agenda de turnos de las sucursales
   que se activen.

## Notas de revisión de tienda

- La reserva de turnos es nativa (no hay WebView): no aplica Apple 4.2.
- Eliminar cuenta: botón en Perfil → edge function `delete-client-account` (debe estar deployada
  en prod antes de enviar a revisión).
- Ubicación: opcional, sólo para ordenar sucursales; la app funciona igual si se niega.
- Notificaciones: el permiso se pide después de explicar para qué (no en el primer arranque).
