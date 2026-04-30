# CLAUDE.md — Monaco Mobile (App de Clientes)

This file provides guidance to Claude Code (claude.ai/code) when working with the Flutter client app of Monaco Smart Barber.

## Project Overview

**barberOS — App de Clientes**: Flutter mobile app que el cliente final usa para puntos, recompensas, reseñas, ocupación de sucursal, **mis turnos** y reserva (vía WebView del link público). Comparte el backend Supabase con el dashboard `../MonacoSmartBarber/` y la edge function `client-auth`.

```
package: monaco_mobile
sdk: ^3.10.3
```

## Commands

```bash
flutter pub get                                                              # Install deps
flutter analyze                                                              # Static analysis
flutter test                                                                 # Run tests (none configured v1)
flutter run                                                                  # Run on connected device/sim
flutter build ios --dart-define=SUPABASE_ANON_KEY=...                        # iOS prod build
flutter build apk --dart-define=SUPABASE_ANON_KEY=...                        # Android prod build
```

`SUPABASE_ANON_KEY` se pasa como `--dart-define` en build time (no hay `.env`).

## Architecture — Clean Architecture + Riverpod

```
lib/
├── app/
│   ├── theme/                 # MonacoColors, themes
│   └── widgets/glass/         # Liquid Glass design system (LiquidGlass, LiquidPill, LiquidButton, LiquidSegmentedTabs, LiquidAppBarScaffold, LiquidStatusPill)
├── core/
│   ├── auth/                  # AuthState, secure_storage, biometric
│   ├── branch/                # selected_branch_provider
│   ├── location/              # geolocation
│   ├── push/                  # push_handler, push_service
│   ├── router/                # app_router (go_router)
│   ├── supabase/              # supabase_provider
│   └── utils/
├── features/
│   ├── appointments/          # 🆕 v2.1 — Mis turnos + booking WebView
│   │   ├── data/              # appointment_model, appointments_repository
│   │   ├── providers/         # appointmentsRepositoryProvider, upcomingAppointmentsProvider, pastAppointmentsProvider, appointmentsNotifierProvider
│   │   └── presentation/
│   │       ├── my_appointments_screen.dart
│   │       ├── booking_webview_screen.dart   # WebView del link público
│   │       ├── cancel_dialog.dart            # showCancelAppointmentDialog()
│   │       └── widgets/
│   │           ├── appointment_card.dart
│   │           ├── appointment_status_chip.dart
│   │           └── empty_state.dart
│   ├── billboard/
│   ├── branch_selection/      # selección de sucursal con BranchWithDistance
│   ├── catalog/
│   ├── convenios/             # convenios + redenciones
│   ├── home/
│   ├── occupancy/             # cola en vivo
│   ├── onboarding/
│   ├── org_selection/
│   ├── points/
│   ├── profile/
│   ├── reviews/
│   ├── rewards/
│   └── visits/
└── main.dart
```

State management: **Riverpod** (sin codegen v1). Naming: `*Provider` suffix. Navigation: **go_router** (ShellRoute con LiquidDock para tabs principales).

## Auth model — `{phone}@monaco.internal` + device_secret

Los clientes se autentican vía Edge Function `client-auth` (en MonacoSmartBarber): registro/login con `phone + device_secret` (SHA256 de device_id + salt). Biométrica y PIN son **gates locales** sólo. OTP via Twilio queda diferido a v2.

`AuthState` (`core/auth/auth_provider.dart`) expone:
- `clientId`, `selectedBranchId`, `selectedBranchName`
- `selectedBranchOperationMode` (`walk_in | appointments | hybrid`)
- `selectedBranchSlug` — necesario para WebView de booking público
- Getters helper: `acceptsAppointments`, `acceptsWalkIn`

Persistencia en `SecureStorageService` (Keychain iOS / EncryptedPrefs Android).

## Sistema de turnos (v2.1, post-migración Supabase 119+)

**Modelo de datos** (Supabase, ver `../MonacoSmartBarber/CLAUDE.md`):
- `branches.operation_mode` enum (`walk_in | appointments | hybrid`).
- `appointments.cancellation_token` — token UUID URL-safe que el cliente usa para cancelar **sin auth**.
- RLS: cliente sólo ve `appointments` cuyo `client_id ∈ (SELECT id FROM clients WHERE auth_user_id = auth.uid())`.

**Cancelación**: la app usa `cancel_appointment_by_token(token)` directamente, NO requiere auth en el RPC. Si la ventana de 2h ya pasó, el RPC devuelve `TOO_LATE` y la app muestra "Comunicate con la barbería". El helper `Appointment.canCancel` aplica el mismo gate de 2h del lado cliente para ocultar el botón cuando no aplica.

**Reserva**: la app NO bookea nativamente en v1; abre `BookingWebViewScreen` que carga `https://app.monacosmartbarber.com/turnos/{branch.slug}?phone=...&from=app`. La WebView detecta callback de confirmación leyendo URL (`/confirmation`, `?status=success`, `?booking=success`), invalida los providers de listado y cierra. `clearLocalStorage` + `clearCache` en dispose para no leakear sesiones entre orgs.

**Recordatorios push**: la edge function `appointment-reminders` (cada 1min vía pg_cron) consume `client_device_tokens` filtrado por `is_active=true` y envía via Expo Push API. Tokens `DeviceNotRegistered` se desactivan automáticamente.

**Modos por superficie en home**:
| Modo | Sucursales en home | Tab "Mis turnos" | Cola visible |
|---|---|---|---|
| `walk_in` | ✅ | ❌ | ✅ |
| `appointments` | ❌ | ✅ | ❌ |
| `hybrid` | ✅ | ✅ | ✅ |

`home_screen.dart` chequea `auth.acceptsAppointments`/`auth.acceptsWalkIn` y renderiza condicional. La ruta `/appointments` muestra info-state si no aplica (defensa en profundidad).

## Branch model

`BranchWithDistance` (`features/branch_selection/models/`) extiende los datos del RPC `get_org_branch_signals` con:
- `operation_mode` (default `'walk_in'` si el RPC no lo devuelve)
- `slug` (nullable)
- Getters `acceptsAppointments`, `acceptsWalkIn`

El provider `branch_selection_provider` hace una **query parallel** a `branches` (con `inFilter('id', ids)`) para hidratar `operation_mode` + `slug` post-RPC, ya que `get_org_branch_signals` aún no los expone (TODO: extender el RPC en una migración futura).

## Routing

`core/router/app_router.dart` usa `ShellRoute` para `/home`, `/occupancy`, `/rewards`, `/profile` con `LiquidDock`. Rutas planas para detail screens. Rutas nuevas:

```dart
GoRoute(path: '/appointments',      builder: (_, __) => const MyAppointmentsScreen()),
GoRoute(path: '/appointments/book', builder: (_, __) => const BookingWebViewScreen()),
```

## Conventions

- **Idioma**: UI text + comentarios en **español rioplatense** (CLAUDE.md root convention).
- **Locale**: `es`, `intl: ^0.19.0`. Fechas: `DateFormat("EEEE d 'de' MMMM", 'es')`. Currency: `NumberFormat.currency(locale: 'es_AR', symbol: r'$', decimalDigits: 0)`.
- **Theme**: dark by default con `MonacoColors`. Accent verde `#22C55E`. Liquid Glass tokens consistentes.
- **No codegen Riverpod** en v1.
- **Sin tests obligatorios** en v1 (matchea convención del dashboard).
- **withOpacity deprecated**: el código existente sigue usándolo; tests futuros pueden migrar a `withValues(alpha: …)` en su momento.

## Environment & Build

- `--dart-define=SUPABASE_ANON_KEY=...` en build time.
- iOS: configurar Universal Links si se quiere capturar `https://app.monacosmartbarber.com/booking-success` desde el WebView (v1.1).
- Android: WebView usa `webview_flutter: ^4.10.0`.

## Known Risks

1. **Device secret loss on reinstall**: cliente pierde auth, debe re-registrarse. Recovery v2.
2. **Single-device only**: dos teléfonos del mismo cliente generan dos device_secrets distintos (cada uno es una "cuenta"). Multi-device v2.
3. **WebView cookies**: limpiamos cache/localStorage en dispose para no leakear, pero si dos orgs usan el mismo dominio, sesiones quedan aisladas por dispose. v2: agregar `Storage Access API` o pasar token como query param.
4. **`get_org_branch_signals` no expone `operation_mode`/`slug`**: hidratamos vía query separada. Si la app crece a 1000s de branches, considerar extender el RPC para evitar el round-trip.
5. **Push tokens stale**: si el usuario revoca permisos sin desinstalar, la edge function detecta `DeviceNotRegistered` y desactiva el token. Pero si el desinstall es completo + reinstall, se genera token nuevo y el viejo queda hasta que Expo lo rechace.
6. **Cancelación sin auth via token**: el `cancellation_token` es UUID hex 48 chars, suficiente para ser no-guesseable. Si una org necesita más control, pueden rotar el token vía RPC custom.
