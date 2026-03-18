# Monaco Smart Barber — App Movil v1.0

## Resumen de entrega

App Flutter para clientes de Monaco Smart Barber. Comparte backend Supabase con el dashboard web existente.

| Metrica | Valor |
|---|---|
| Archivos Dart (lib/) | 41 |
| Lineas de codigo | ~7,400 |
| Tests | 95 (64 unit + 31 widget) |
| Pantallas | 15 |
| Errores de analisis | 0 |
| Warnings | 0 |
| Edge Functions nuevas | 1 (send-push) |
| Funciones SQL usadas | 10 |

---

## Arquitectura

```
lib/
  app/          → App root, theme (colors, typography, material theme)
  core/
    auth/       → AuthService, AuthProvider, BiometricService, PinService, SecureStorage
    push/       → PushService (FCM), PushHandler (notification routing)
    router/     → GoRouter con auth guards + ShellRoute (bottom nav)
    supabase/   → SupabaseClient provider
    utils/      → Constants, Formatters
  features/
    onboarding/ → Splash, Welcome, Login, BiometricGate
    home/       → Dashboard (puntos, sucursales, cartelera, accesos rapidos)
    occupancy/  → Lista de sucursales, detalle con realtime, barber status
    points/     → Billetera global, historial de transacciones
    rewards/    → Mis premios, QR display
    reviews/    → Bandeja de resenas pendientes, flujo de resena
    billboard/  → Cartelera fullscreen con auto-scroll
    catalog/    → Catalogo de canjes por puntos
    profile/    → Perfil, PIN setup, configuracion
```

**State management:** Riverpod (FutureProvider, StreamProvider, StateNotifierProvider)
**Navigation:** GoRouter con redirect guards segun AuthStatus
**Design:** Dark theme coherente con dashboard web, gold accent (#D4A853)

---

## Pantallas implementadas

### Onboarding
1. **SplashScreen** — Logo animado, redirige segun auth state
2. **WelcomeScreen** — 3-slide PageView con smooth indicator
3. **LoginScreen** — Ingreso por telefono (+54), nombre opcional
4. **BiometricGateScreen** — Verificacion biometrica con fallback a PIN

### Main (Bottom Nav)
5. **HomeScreen** — Dashboard: puntos, resenas pendientes, sucursales horizontal, cartelera, accesos rapidos
6. **OccupancyScreen** — Lista de sucursales con ocupacion en tiempo real
7. **RewardsScreen** — Tabs Disponibles/Usados con cards de recompensas
8. **ProfileScreen** — Nombre, telefono, biometria toggle, PIN, logout

### Detail Screens
9. **BranchDetailScreen** — Detalle de sucursal con cola realtime, barberos, ETA
10. **PointsScreen** — Billetera global, por sucursal, historial
11. **CatalogScreen** — Grid de items canjeables con confirmacion
12. **ReviewsScreen** — Bandeja de resenas pendientes
13. **ReviewFlowScreen** — Flujo completo: rating → accion segun estrellas
14. **QrDisplayScreen** — QR fullscreen para canjear premio
15. **BillboardScreen** — Cartelera fullscreen con PageView auto-scroll
16. **PinSetupScreen** — Teclado numerico custom para PIN 4-6 digitos

---

## Backend (Supabase)

### Funciones SQL utilizadas (10)
| Funcion | Uso |
|---|---|
| `get_client_global_points` | Saldo y total de puntos global |
| `get_client_pending_reviews` | Resenas pendientes del cliente |
| `get_client_wallet` | Recompensas del cliente con QR |
| `get_client_branch_signals` | Sucursales con ocupacion |
| `get_branch_open_status` | Estado abierto/cerrado |
| `submit_client_review` | Enviar resena (con logica por rating) |
| `set_client_pin` | Guardar PIN hasheado |
| `verify_client_pin` | Verificar PIN |
| `deduct_client_points` | Descontar puntos (cross-branch) |
| `redeem_points_for_reward` | Canjear puntos por premio |

### Edge Functions (5 total, 1 nueva)
| Function | Status | Descripcion |
|---|---|---|
| `client-auth` | ACTIVE | Login/registro por telefono |
| `send-push` | ACTIVE | **NUEVO** — Push via FCM |
| `meta-webhook` | ACTIVE | Webhook de Meta |
| `send-message` | ACTIVE | Envio de mensajes |
| `process-scheduled-messages` | ACTIVE | Mensajes programados |

### Tablas principales usadas por la app
- `clients`, `client_points`, `point_transactions`
- `reward_catalog`, `client_rewards`
- `review_requests`, `client_reviews`
- `branches`, `branch_signals`, `queue_entries`, `staff`
- `billboard_items`, `client_device_tokens`

---

## Tests

```
test/
  unit/
    formatters_test.dart    → 39 tests (currency, date, time, points, eta, phone)
    pin_service_test.dart   → 13 tests (validacion de formato PIN)
    auth_state_test.dart    → 12 tests (AuthState model + AuthStatus enum)
  widget/
    points_history_tile_test.dart   → 9 tests (earned/redeemed visual)
    occupancy_mini_card_test.dart   → 8 tests (branch, ETA, colores)
    barber_status_tile_test.dart    → 14 tests (nombre, status, avatar)
```

Ejecutar: `flutter test`

---

## Verificacion de calidad

- `dart analyze lib/` → **0 errors, 0 warnings**
- `flutter test` → **95/95 passing**
- `npm run build` (MonacoSmartBarber) → **Build exitoso** (fix: excluir `supabase/` de tsconfig)
- 10/10 funciones SQL verificadas en Supabase

---

## Dependencias clave (pubspec.yaml)

| Paquete | Version | Uso |
|---|---|---|
| flutter_riverpod | ^2.6.1 | State management |
| go_router | ^14.8.1 | Navigation |
| supabase_flutter | ^2.9.0 | Backend |
| flutter_secure_storage | ^9.2.4 | Device secret, prefs |
| local_auth | ^2.3.0 | Biometrics |
| firebase_core | ^3.12.1 | FCM base |
| firebase_messaging | ^15.2.4 | Push notifications |
| flutter_animate | ^4.5.2 | Animaciones |
| qr_flutter | ^4.1.0 | QR codes |
| intl | ^0.19.0 | Formateo i18n |
| url_launcher | ^6.3.1 | Google Maps redirect |

---

## Para correr el proyecto

```bash
cd Monaco-mobile

# Instalar dependencias
flutter pub get

# Correr en simulador (requiere SUPABASE_ANON_KEY)
flutter run --dart-define=SUPABASE_ANON_KEY=<tu_key>

# Analizar codigo
dart analyze lib/

# Correr tests
flutter test

# Build release
flutter build ios --dart-define=SUPABASE_ANON_KEY=<tu_key>
flutter build apk --dart-define=SUPABASE_ANON_KEY=<tu_key>
```

---

## Pendientes v2

- OTP SMS (Twilio) para onboarding
- Multi-device support
- Check-in remoto desde la app
- Historial de cortes con fotos
- Video en billboard
- Notificaciones push admin por resenas negativas
