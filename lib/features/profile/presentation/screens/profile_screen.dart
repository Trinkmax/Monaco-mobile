import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/core/api/mobile_api.dart';
import 'package:monaco_mobile/core/auth/auth_provider.dart';
import 'package:monaco_mobile/core/auth/biometric_service.dart';
import 'package:monaco_mobile/core/auth/secure_storage.dart';
import 'package:monaco_mobile/core/branch/test_mode_provider.dart';
import 'package:monaco_mobile/core/push/push_service.dart';
import 'package:monaco_mobile/core/utils/constants.dart';
import 'package:monaco_mobile/features/appointments/presentation/widgets/turno_links.dart';
import 'package:monaco_mobile/features/appointments/providers/booking_provider.dart';
import 'package:monaco_mobile/features/loyalty/data/loyalty_models.dart';
import 'package:monaco_mobile/features/loyalty/providers/loyalty_provider.dart';
import 'package:monaco_mobile/features/notifications/presentation/widgets/push_pre_prompt.dart';
import 'package:monaco_mobile/features/occupancy/providers/occupancy_provider.dart';
import 'package:monaco_mobile/features/notifications/providers/notifications_provider.dart';
import 'package:monaco_mobile/features/onboarding/presentation/widgets/copy_sesion.dart';
import 'package:monaco_mobile/features/onboarding/presentation/widgets/muro_login.dart';
import 'package:monaco_mobile/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:monaco_mobile/features/onboarding/utils/phone_format.dart';
import 'package:monaco_mobile/features/profile/presentation/widgets/legal_y_soporte.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Providers
// ═══════════════════════════════════════════════════════════════════════════

/// Biometría como gate local (Keychain/EncryptedPrefs).
final biometricEnabledProvider =
    StateNotifierProvider<BiometricEnabledNotifier, bool>(
      (ref) => BiometricEnabledNotifier(),
    );

class BiometricEnabledNotifier extends StateNotifier<bool> {
  BiometricEnabledNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    state = await SecureStorageService.isBiometricEnabled();
  }

  Future<void> set(bool value) async {
    await SecureStorageService.setBiometricEnabled(value);
    state = value;
  }
}

/// Qué biometría ofrece el teléfono (para el texto del toggle).
final biometricKindProvider = FutureProvider<BiometricKind>((ref) {
  return BiometricService.availableKind();
});

/// ¿Hay PIN local configurado? (hash en SecureStorage; se tolera el flag viejo.)
final pinConfiguredProvider = FutureProvider.autoDispose<bool>((ref) async {
  final hash = await SecureStorageService.getLocalPinHash();
  if (hash != null && hash.isNotEmpty) return true;
  return SecureStorageService.isPinEnabled();
});

/// "2.0.0 (20)".
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
});

/// Modo prueba (muestra la sucursal Test). Se activa con 7 toques sobre la
/// versión. Los listados de sucursales pueden `watch`earlo para refrescarse.
final testModeEnabledProvider = StateNotifierProvider<TestModeNotifier, bool>(
  (ref) => TestModeNotifier(),
);

class TestModeNotifier extends StateNotifier<bool> {
  TestModeNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    state = await SecureStorageService.isTestModeEnabled();
  }

  Future<void> set(bool value) async {
    await SecureStorageService.setTestModeEnabled(value);
    state = value;
  }
}

/// `GET /api/mobile/me`: valida la sesión y trae el nombre canónico (por si
/// lo cambiaron desde el dashboard). La pantalla lo usa para re-sincronizar
/// el nombre local; si falla, se muestra lo que hay en el estado de auth.
final meProvider = FutureProvider.autoDispose<Map<String, dynamic>>((
  ref,
) async {
  final json = await ref.read(mobileApiProvider).getJson('/api/mobile/me');
  final client = json['client'];
  return client is Map
      ? Map<String, dynamic>.from(client)
      : <String, dynamic>{};
});

/// Código con el que la edge function `delete-client-account` rechaza la baja
/// (HTTP 409) cuando el cliente tiene una **seña pagada sin resolver**
/// (migración 215): hay plata suya en el sistema y borrar la ficha dejaría el
/// pago sin dueño y sin forma de devolverlo.
const String codigoSenaPendiente = 'DEPOSIT_PENDING';

/// ¿El error de `deleteAccount()` es ese rechazo?
///
/// El borrado **no** pasa por `MobileApi`, así que acá no hay
/// `MobileApiException` con su `code`: va por `functions.invoke` y
/// `AuthService.deleteAccount()` colapsa la respuesta a un `String?`
/// devolviendo el campo `error` del body — o sea el CÓDIGO, no el `message`.
/// Por eso se reconoce el código (estable, parte del contrato con la edge
/// function) y no el texto, que lo escribe el server y puede cambiar.
bool esRechazoPorSenaPendiente(String? error) =>
    error != null && error.toUpperCase().contains(codigoSenaPendiente);

// ═══════════════════════════════════════════════════════════════════════════
// Screen
// ═══════════════════════════════════════════════════════════════════════════

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with WidgetsBindingObserver {
  int _versionTaps = 0;
  Timer? _versionTapTimer;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _versionTapTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Al volver de Ajustes del sistema el permiso de push pudo cambiar.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(pushPermisoProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    if (auth.isGuest) return _perfilInvitado();

    final pushPermiso = ref.watch(pushPermisoProvider);
    final unread = ref.watch(unreadNotificationsCountProvider);
    final biometricEnabled = ref.watch(biometricEnabledProvider);
    final biometricKind = ref.watch(biometricKindProvider).valueOrNull;
    final pinConfigured = ref.watch(pinConfiguredProvider).valueOrNull;
    final version = ref.watch(appVersionProvider).valueOrNull;
    final testMode = ref.watch(testModeEnabledProvider);
    final loyalty = ref.watch(loyaltyProvider);

    // Si el server tiene otro nombre (lo editaron desde el dashboard), se
    // adopta en silencio.
    ref.listen(meProvider, (_, next) {
      final remote = (next.valueOrNull?['name'] as String?)?.trim();
      final local = (ref.read(authProvider).clientName ?? '').trim();
      if (remote != null && remote.isNotEmpty && remote != local) {
        ref.read(authProvider.notifier).updateClientName(remote);
      }
    });

    // Sin Firebase configurado no se dibuja el interruptor: un switch que no
    // se puede prender y dice "en una próxima versión" es contenido de
    // relleno (Apple 2.1). La bandeja y las preferencias por tipo quedan.
    final pushAvailable = PushService.isAvailable;
    final permiso = pushPermiso.valueOrNull ?? PushPermiso.desconocido;
    final pushGranted = permiso == PushPermiso.concedido;

    return LiquidAppBarScaffold(
      title: 'Perfil',
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _BellAction(
            unread: unread,
            onTap: () => context.push('/notificaciones'),
          ),
        ),
      ],
      body: RefreshIndicator(
        color: Colors.white,
        backgroundColor: MonacoColors.surface,
        onRefresh: () async {
          ref.invalidate(meProvider);
          ref.invalidate(pushPermisoProvider);
          ref.invalidate(pinConfiguredProvider);
          ref.invalidate(biometricKindProvider);
          invalidarLoyalty(ref);
          await Future<void>.delayed(const Duration(milliseconds: 400));
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          children: [
            // ── Tarjeta de perfil ──────────────────────────────────────
            _ProfileCard(
              name: auth.clientName ?? '',
              phone: auth.clientPhone ?? '',
              onEditName: _editName,
            ).liquidEnter(index: 0),

            const SizedBox(height: 26),

            // ── Notificaciones ─────────────────────────────────────────
            const _SectionLabel('Notificaciones').liquidEnter(index: 2),
            const SizedBox(height: 10),
            LiquidSectionCard(
              children: [
                LiquidListTile(
                  icon: Icons.inbox_rounded,
                  title: 'Bandeja de notificaciones',
                  subtitle: unread > 0
                      ? '$unread sin leer'
                      : 'Recordatorios, premios y novedades',
                  trailing: unread > 0 ? _CountBadge(count: unread) : null,
                  onTap: () => context.push('/notificaciones'),
                ),
                LiquidListTile(
                  icon: Icons.tune_rounded,
                  title: 'Preferencias',
                  subtitle: 'Elegí qué querés recibir',
                  onTap: () => context.push('/notificaciones/preferencias'),
                ),
                if (pushAvailable)
                  LiquidSwitchTile(
                    icon: pushGranted
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_none_rounded,
                    iconColor: pushGranted ? MonacoColors.monacoGreen : null,
                    title: 'Notificaciones del sistema',
                    subtitle: pushGranted
                        ? 'Activadas. Se desactivan desde Ajustes.'
                        : permiso == PushPermiso.bloqueado
                        ? 'Bloqueadas en el sistema. Se activan desde Ajustes.'
                        : 'Te avisamos de turnos, premios y novedades',
                    value: pushGranted,
                    onChanged: (v) => _onPushToggle(v, permiso),
                  ),
              ],
            ).liquidEnter(index: 3),

            const SizedBox(height: 26),

            // ── Seguridad ──────────────────────────────────────────────
            const _SectionLabel('Seguridad').liquidEnter(index: 4),
            const SizedBox(height: 10),
            LiquidSectionCard(
              children: [
                LiquidSwitchTile(
                  icon: (biometricKind ?? BiometricKind.generic).icon,
                  iconColor: biometricEnabled ? MonacoColors.monacoGreen : null,
                  title:
                      'Desbloqueo con ${(biometricKind ?? BiometricKind.generic).label}',
                  subtitle: biometricKind == BiometricKind.none
                      ? 'No disponible en este dispositivo'
                      : 'Pedimos tu ${(biometricKind ?? BiometricKind.generic).label} al abrir la app',
                  value: biometricEnabled,
                  onChanged: (v) => _onBiometricToggle(v, biometricKind),
                ),
                LiquidListTile(
                  icon: Icons.pin_rounded,
                  iconColor: pinConfigured == true
                      ? MonacoColors.monacoGreen
                      : null,
                  title: pinConfigured == true
                      ? 'Cambiar PIN'
                      : 'Configurar PIN',
                  subtitle: pinConfigured == true
                      ? 'PIN configurado'
                      : 'Un código de 4 dígitos como alternativa',
                  onTap: () async {
                    await context.push('/pin-setup');
                    ref.invalidate(pinConfiguredProvider);
                  },
                ),
              ],
            ).liquidEnter(index: 5),

            const SizedBox(height: 26),

            // ── Mi programa ────────────────────────────────────────────
            const _SectionLabel('Mi programa').liquidEnter(index: 6),
            const SizedBox(height: 10),
            LiquidSectionCard(
              children: [
                LiquidListTile(
                  icon: Icons.workspace_premium_rounded,
                  // El color de la categoría, no un verde de "tiene": misma
                  // regla que la línea "Cliente Oro" de Premios.
                  iconColor: loyalty.valueOrNull?.tier?.acentoSobreOscuro,
                  title: 'Mi categoría',
                  subtitle: _subtituloCategoria(loyalty),
                  onTap: () => context.push('/categoria'),
                ),
                LiquidListTile(
                  icon: Icons.person_add_alt_1_rounded,
                  title: 'Invitá a un amigo',
                  subtitle: 'Tu código y QR personal',
                  onTap: () => context.push('/invitar'),
                ),
              ],
            ).liquidEnter(index: 7),

            const SizedBox(height: 26),

            // ── Historial ──────────────────────────────────────────────
            const _SectionLabel('Historial').liquidEnter(index: 8),
            const SizedBox(height: 10),
            LiquidSectionCard(
              children: [
                LiquidListTile(
                  icon: Icons.content_cut_rounded,
                  title: 'Mis visitas',
                  subtitle: 'Cortes y servicios anteriores',
                  onTap: () => context.push('/visits'),
                ),
                LiquidListTile(
                  icon: Icons.stars_rounded,
                  iconColor: MonacoColors.monacoGreen,
                  title: 'Movimientos de puntos',
                  subtitle: 'Lo que sumaste y lo que canjeaste',
                  onTap: () => context.push('/points'),
                ),
                LiquidListTile(
                  icon: Icons.card_giftcard_rounded,
                  title: 'Mis premios',
                  subtitle: 'Los que tenés para usar y los que ya usaste',
                  onTap: () => context.push('/mis-premios'),
                ),
                LiquidListTile(
                  icon: Icons.local_offer_rounded,
                  title: 'Mis canjes',
                  subtitle: 'Códigos de convenios activados y usados',
                  onTap: () => context.push('/mis-canjes'),
                ),
              ],
            ).liquidEnter(index: 9),

            const SizedBox(height: 26),

            // ── Legal y soporte: una fila; la hoja tiene las seis opciones ──
            const LegalYSoporteFila().liquidEnter(index: 10),

            const SizedBox(height: 32),

            // ── Cerrar sesión ──────────────────────────────────────────
            LiquidPill(
              onTap: _busy ? null : _confirmLogout,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              tint: MonacoColors.destructive,
              tintOpacity: 0.12,
              borderRadius: 18,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.logout_rounded,
                    size: 20,
                    color: MonacoColors.destructive,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Cerrar sesión',
                    style: TextStyle(
                      color: MonacoColors.destructive,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ).liquidEnter(index: 12),

            const SizedBox(height: 14),

            // ── Eliminar cuenta (Apple 5.1.1(v)) ───────────────────────
            Semantics(
              button: true,
              child: GestureDetector(
                onTap: _busy ? null : _confirmDeleteAccount,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      'Eliminar mi cuenta',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                ),
              ),
            ).liquidEnter(index: 13),

            const SizedBox(height: 14),

            // ── Versión (7 toques → modo prueba) ───────────────────────
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _onVersionTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    Text(
                      'Versión ${version ?? '…'}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (testMode) ...[
                      const SizedBox(height: 8),
                      const LiquidStatusPill(
                        label: 'MODO PRUEBA',
                        color: MonacoColors.warning,
                        compact: true,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Acciones
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _editName() async {
    final current = ref.read(authProvider).clientName ?? '';
    final saved = await showLiquidSheet<String>(
      context,
      title: 'Editar nombre',
      subtitle: 'Así te llamamos en la app y en tus turnos.',
      builder: (ctx) => _EditNameSheet(
        initial: current,
        onSave: (name) async {
          final json = await ref.read(mobileApiProvider).postJson(
            '/api/mobile/me',
            {'name': name},
          );
          final confirmed = (json['name'] as String?)?.trim();
          final finalName = (confirmed == null || confirmed.isEmpty)
              ? name
              : confirmed;
          await ref.read(authProvider.notifier).updateClientName(finalName);
          return finalName;
        },
      ),
    );
    if (saved != null && mounted) {
      ref.invalidate(meProvider);
      showLiquidToast(
        context,
        'Nombre actualizado.',
        tone: LiquidToastTone.success,
      );
    }
  }

  Future<void> _onPushToggle(bool wantEnabled, PushPermiso permiso) async {
    if (wantEnabled) {
      if (permiso == PushPermiso.bloqueado) {
        // Ya se pidió y el sistema dijo que no: el prompt nativo no vuelve a
        // aparecer, hay que ir a Ajustes. OJO: esto NO se deduce de un
        // `denied` a secas — en Android ése es el estado de fábrica y por eso
        // el prompt no se disparaba nunca (ver `PushPermiso`).
        await abrirAjustesDePush(context);
        return;
      }
      await requestPushWithPrePrompt(context, ref);
      return;
    }
    // El sistema no permite revocar desde la app.
    showLiquidToast(
      context,
      'Para desactivarlas, hacelo desde los ajustes del sistema.',
      tone: LiquidToastTone.info,
      actionLabel: 'Ajustes',
      onAction: () => abrirAjustesDePush(context),
    );
  }

  Future<void> _onBiometricToggle(bool value, BiometricKind? kind) async {
    HapticFeedback.selectionClick();
    if (value) {
      if (kind == BiometricKind.none) {
        showLiquidToast(
          context,
          'Tu dispositivo no tiene biometría configurada.',
          tone: LiquidToastTone.info,
        );
        return;
      }
      // Confirmamos con la biometría antes de prender el gate: si no
      // funciona acá, tampoco va a funcionar al abrir la app.
      final ok = await BiometricService.authenticate(
        reason: 'Confirmá para activar el desbloqueo',
      );
      if (!ok) {
        if (mounted) {
          showLiquidToast(
            context,
            'No pudimos verificar tu ${(kind ?? BiometricKind.generic).label}.',
            tone: LiquidToastTone.error,
          );
        }
        return;
      }
    }
    await ref.read(biometricEnabledProvider.notifier).set(value);
    if (!mounted) return;
    showLiquidToast(
      context,
      value ? 'Desbloqueo activado.' : 'Desbloqueo desactivado.',
      tone: value ? LiquidToastTone.success : LiquidToastTone.neutral,
    );
  }


  /// Perfil de un **invitado**: sin datos personales (no hay ninguno), con lo
  /// legal y el soporte —que son públicos y App Store los quiere accesibles— y
  /// con la puerta para crear la cuenta.
  ///
  /// La sección legal es la MISMA que la del perfil con cuenta, soporte y
  /// botón de arrepentimiento incluidos: el que todavía no tiene cuenta es
  /// justamente el que más necesita encontrar cómo pedir ayuda, y la Disp.
  /// 954/2025 pide el botón "desde el primer acceso", no detrás de un login.
  ///
  /// No dibuja el interruptor de notificaciones del sistema a propósito: pedir
  /// el permiso de push a alguien que todavía no tiene cuenta es pedirlo sin
  /// nada que notificar, y la 5.1.2(i) prohíbe condicionar funciones a que el
  /// usuario habilite permisos.
  Widget _perfilInvitado() {
    final version = ref.watch(appVersionProvider).valueOrNull;
    final testMode = ref.watch(testModeEnabledProvider);

    return LiquidAppBarScaffold(
      title: 'Perfil',
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          LiquidGlass(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
            borderRadius: 24,
            tintOpacity: 0.09,
            showVignette: false,
            pressable: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Estás mirando sin cuenta',
                  style: TextStyle(
                    color: MonacoColors.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Con tu cuenta reservás turnos, sumás puntos en cada corte y '
                  'canjeás premios en el local.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13.5,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: LiquidTapEffect(
                    onTap: () =>
                        pedirCuenta(context, ref, AccionConCuenta.perfil),
                    borderRadius: BorderRadius.circular(16),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text(
                          'Crear cuenta o ingresar',
                          style: TextStyle(
                            color: MonacoColors.background,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ).liquidEnter(index: 0),

          const SizedBox(height: 26),

          // La misma fila que en el perfil con cuenta: la hoja tiene las seis
          // opciones (soporte, legales y el botón de arrepentimiento).
          const LegalYSoporteFila().liquidEnter(index: 2),

          const SizedBox(height: 26),

          // Salir del modo invitado = volver a la bienvenida. No es "cerrar
          // sesión" (no hay ninguna): es deshacer el "Seguir mirando".
          Center(
            child: OnboardingLink(
              label: 'Volver a la pantalla de inicio',
              icon: Icons.arrow_back_rounded,
              onTap: () =>
                  ref.read(authProvider.notifier).salirDelModoInvitado(),
            ),
          ).liquidEnter(index: 3),

          const SizedBox(height: 14),

          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onVersionTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  Text(
                    'Versión ${version ?? '…'}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (testMode) ...[
                    const SizedBox(height: 8),
                    const LiquidStatusPill(
                      label: 'MODO PRUEBA',
                      color: MonacoColors.warning,
                      compact: true,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final ok = await showLiquidDialog<bool>(
      context,
      title: 'Cerrar sesión',
      message: kCerrarSesionDetalle,
      icon: Icons.logout_rounded,
      actions: const [
        LiquidDialogAction(label: 'Cancelar', value: false),
        LiquidDialogAction(
          label: 'Cerrar sesión',
          value: true,
          destructive: true,
          icon: Icons.logout_rounded,
        ),
      ],
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    try {
      // Primero la baja del token (necesita el JWT), después el signOut.
      await PushService.unregister();
      await ref.read(authProvider.notifier).logout();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted) context.go('/welcome');
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (confirmed != true || !mounted) return;
    await _executeDeleteAccount();
  }

  Future<void> _executeDeleteAccount() async {
    HapticFeedback.mediumImpact();
    setState(() => _busy = true);

    // Velo bloqueante mientras borra. Es un `OverlayEntry` y NO un diálogo
    // (`showDialog` sobre el navigator raíz), y se quita en el `finally` por
    // referencia. La versión anterior era un diálogo que se cerraba con
    // `Navigator.of(context, rootNavigator: true).pop()` al volver del await,
    // y eso le dejaba al revisor una PANTALLA NEGRA (18/9/2026, iPhone real):
    //
    //   1. `AuthService.deleteAccount()` hace `signOut()` local después del
    //      200 del server; el evento `signedOut` llegaba a `AuthNotifier` a
    //      mitad del flujo, ponía `unauthenticated` y el router se iba a
    //      `/welcome` ANTES de que este método volviera del await.
    //   2. El navigator raíz reemplazaba la página del shell por la bienvenida
    //      y, como documenta `Navigator.pages`, se llevaba consigo el diálogo
    //      (ruta sin página) que estaba encima.
    //   3. Pero la página saliente sigue MONTADA mientras dura su animación de
    //      salida (~300 ms): `mounted` seguía en true y el `pop()` "para
    //      cerrar el overlay" ya no encontraba diálogo — le sacaba la ÚNICA
    //      página al navigator raíz, la bienvenida, y el navigator quedaba
    //      vacío. Negro, con la barra de estado visible.
    //
    // Con un OverlayEntry no hay ninguna ruta que popear y `remove()` es
    // seguro aunque la pantalla ya no exista. La otra mitad del arreglo está en
    // `AuthNotifier` (`_borrandoCuenta`): el `signedOut` de ese signOut se
    // ignora y el estado lo fija `deleteAccount()` UNA vez, al final, así el
    // router no se mueve mientras este método está a medias.
    final velo = OverlayEntry(
      builder: (_) => AbsorbPointer(
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.72),
          child: const Center(
            child: SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(velo);
    // El router se toma ANTES de los await: si la pantalla se desmonta en el
    // medio, `context` ya no lo encuentra.
    final router = GoRouter.of(context);

    String? error;
    try {
      await PushService.unregister();
      error = await ref.read(authProvider.notifier).deleteAccount();
    } catch (e, st) {
      // `deleteAccount()` ya devuelve mensajes en español; lo que caiga acá es
      // algo inesperado y su `toString()` es una excepción de Dart en inglés.
      // El reviewer prueba este camino a propósito (5.1.1(v)): que el paso más
      // sensible de la app termine en "ClientException with SocketException:
      // Failed host lookup" es exactamente lo que no puede pasar.
      debugPrint('[perfil] eliminar cuenta falló: $e\n$st');
      error = 'No pudimos eliminar la cuenta. Probá de nuevo o escribinos.';
    } finally {
      velo.remove();
      velo.dispose();
    }

    if (error == null) {
      // El toast vive en el overlay RAÍZ (`showLiquidToast`), así que
      // sobrevive al cambio de página; sólo necesita un context vivo para
      // encontrarlo.
      if (mounted) {
        showLiquidToast(
          context,
          'Tu cuenta fue eliminada.',
          tone: LiquidToastTone.success,
        );
      }
      router.go('/welcome');
      return;
    }

    if (!mounted) return;
    setState(() => _busy = false);

    // Seña pagada sin resolver: NO es "algo salió mal", es un paso que falta y
    // que el cliente puede dar solo. Un toast de cinco segundos con el código
    // crudo del server lo dejaría con la cuenta sin borrar, sin saber por qué
    // y sin saber qué hacer — y con plata suya en el medio.
    if (esRechazoPorSenaPendiente(error)) {
      final irATurnos = await showDialog<bool>(
        context: context,
        useRootNavigator: true,
        barrierColor: Colors.black.withValues(alpha: 0.72),
        builder: (_) => const _SenaPendienteDialog(),
      );
      // La navegación la hace la pantalla y no el diálogo: el `context` del
      // diálogo queda muerto apenas se cierra.
      if (irATurnos == true && mounted) context.go('/turnos');
      return;
    }

    showLiquidToast(
      context,
      error,
      tone: LiquidToastTone.error,
      duration: const Duration(seconds: 5),
    );
  }

  void _onVersionTap() {
    _versionTapTimer?.cancel();
    _versionTaps++;
    if (_versionTaps >= 7) {
      _versionTaps = 0;
      HapticFeedback.heavyImpact();
      unawaited(_alternarModoPrueba());
      return;
    }
    if (_versionTaps >= 4) HapticFeedback.selectionClick();
    _versionTapTimer = Timer(const Duration(seconds: 2), () {
      _versionTaps = 0;
    });
  }

  /// Modo prueba: **7 toques y además un código**.
  ///
  /// La sucursal `test` es una sucursal REAL de producción y toma turnos: con
  /// sólo el gesto, cualquiera que lo descubriera —un reviewer de la tienda
  /// probando la pantalla, un cliente curioso— podía destaparla y reservar
  /// ahí. El código no es un secreto criptográfico, es el candado que
  /// convierte "lo encontré sin querer" en "sabía lo que estaba haciendo".
  ///
  /// Tres reglas:
  /// - **Apagarlo nunca pide nada.** Salir de un modo de prueba no puede
  ///   quedar trabado por un código que el cliente no tiene.
  /// - **En modo invitado no se puede prender.** Es el estado con el que un
  ///   reviewer abre la app por primera vez y no hay ninguna razón para que
  ///   una cuenta que no existe destape una sucursal interna.
  /// - Con `TEST_MODE_CODE` vacío el gesto **no existe** (build de tienda).
  Future<void> _alternarModoPrueba() async {
    if (ref.read(testModeEnabledProvider)) {
      await _aplicarModoPrueba(false);
      return;
    }
    if (ref.read(authProvider).isGuest) return;
    if (AppConstants.testModeCode.isEmpty) return;

    final ok = await showLiquidSheet<bool>(
      context,
      title: 'Modo prueba',
      subtitle:
          'Muestra la sucursal de pruebas en la app. Es para el equipo de '
          'Monaco: si llegaste acá sin querer, cerrá esta hoja.',
      builder: (_) => const _CodigoPruebaSheet(),
    );
    if (ok != true || !mounted) return;
    await _aplicarModoPrueba(true);
  }

  Future<void> _aplicarModoPrueba(bool activar) async {
    await ref.read(testModeEnabledProvider.notifier).set(activar);
    if (!mounted) return;
    // Las listas leen OTRO provider (`testModeProvider`, cacheado sobre el
    // storage): sin invalidarlo, el toast decía "modo prueba activado" y la
    // sucursal Test recién aparecía al reiniciar la app.
    ref.invalidate(testModeProvider);
    ref.invalidate(mobileBranchesProvider);
    ref.invalidate(branchSignalsProvider);
    showLiquidToast(
      context,
      activar ? 'Modo prueba activado.' : 'Modo prueba desactivado.',
      tone: activar ? LiquidToastTone.success : LiquidToastTone.neutral,
      icon: Icons.science_rounded,
    );
  }
}

/// Pide el código del modo prueba. Devuelve `true` por `Navigator.pop` sólo si
/// coincide con [AppConstants.testModeCode].
class _CodigoPruebaSheet extends StatefulWidget {
  const _CodigoPruebaSheet();

  @override
  State<_CodigoPruebaSheet> createState() => _CodigoPruebaSheetState();
}

class _CodigoPruebaSheetState extends State<_CodigoPruebaSheet> {
  final _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_ctrl.text.trim() != AppConstants.testModeCode) {
      HapticFeedback.heavyImpact();
      setState(() => _error = 'Código incorrecto.');
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6),
        LiquidTextField(
          controller: _ctrl,
          label: 'CÓDIGO',
          hint: '••••••',
          autofocus: true,
          errorText: _error,
          obscureText: true,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          prefix: Icon(
            Icons.science_rounded,
            size: 18,
            color: Colors.white.withValues(alpha: 0.5),
          ),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 18),
        LiquidButton(
          onPressed: _submit,
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: const Text(
            'Activar',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Widgets
// ═══════════════════════════════════════════════════════════════════════════

/// "Oro · 2 visitas para Platinum" / "Oro · nivel máximo" / "Programa
/// próximamente" (apagado). Todo sale de `get_client_loyalty`.
String _subtituloCategoria(AsyncValue<LoyaltySummary> loyalty) {
  final s = loyalty.valueOrNull;
  if (s == null) return 'Tu nivel y beneficios';
  if (!s.programEnabled) return 'Programa próximamente';
  final tier = s.tier;
  if (tier == null) return 'Tu nivel y beneficios';
  final next = s.nextTier;
  if (next == null) return '${tier.name} · nivel máximo';
  final faltan = s.nextTierFaltan;
  final visitas = faltan == 1 ? '1 visita' : '$faltan visitas';
  return '${tier.name} · $visitas para ${next.name}';
}

class _BellAction extends StatelessWidget {
  final int unread;
  final VoidCallback onTap;
  const _BellAction({required this.unread, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: unread > 0 ? 'Notificaciones, $unread sin leer' : 'Notificaciones',
      child: LiquidTapEffect(
        onTap: onTap,
        scaleTo: 0.9,
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                unread > 0
                    ? Icons.notifications_rounded
                    : Icons.notifications_none_rounded,
                color: Colors.white.withValues(alpha: 0.9),
                size: 24,
              ),
              if (unread > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    decoration: BoxDecoration(
                      color: MonacoColors.monacoGreen,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: MonacoColors.background,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        unread > 9 ? '9+' : '$unread',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final String name;
  final String phone;
  final VoidCallback onEditName;

  const _ProfileCard({
    required this.name,
    required this.phone,
    required this.onEditName,
  });

  bool get _hasRealName =>
      name.trim().isNotEmpty && !RegExp(r'^\d+$').hasMatch(name.trim());

  @override
  Widget build(BuildContext context) {
    final display = _hasRealName ? name.trim() : 'Completá tu nombre';
    return LiquidGlass(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      borderRadius: LiquidTokens.radiusCardLarge,
      tintOpacity: 0.10,
      pressable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              LiquidAvatar(
                name: _hasRealName ? name : null,
                size: 68,
                tint: MonacoColors.monacoGreen,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      display,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(
                          alpha: _hasRealName ? 1 : 0.6,
                        ),
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.15,
                      ),
                    ),
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_iphone_rounded,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              _formatPhone(phone),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: LiquidPill(
                  onTap: onEditName,
                  borderRadius: 14,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: const Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_rounded, size: 15, color: Colors.white),
                        SizedBox(width: 7),
                        Text(
                          'Editar nombre',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// "+54 9 351 212-5249" a partir de lo que haya guardado (10 dígitos
  /// nacionales, 549…, 54…). Usa la misma regla que el login (`ArPhone`):
  /// área de 2 dígitos para 11 (Buenos Aires), 3 para el resto.
  static String _formatPhone(String raw) {
    final national = ArPhone.normalizeTyped(raw);
    if (national.length != ArPhone.nationalLength) return raw;
    return ArPhone.formatInternational(national);
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              colors: [
                MonacoColors.monacoGreen.withValues(alpha: 0.95),
                MonacoColors.monacoGreenDeep.withValues(alpha: 0.8),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: MonacoColors.monacoGreen.withValues(alpha: 0.35),
                blurRadius: 10,
                spreadRadius: -2,
              ),
            ],
          ),
          child: Text(
            count > 99 ? '99+' : '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(width: 6),
        Icon(
          Icons.chevron_right_rounded,
          color: Colors.white.withValues(alpha: 0.3),
          size: 22,
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

// ── Hoja: editar nombre ────────────────────────────────────────────────────

class _EditNameSheet extends StatefulWidget {
  final String initial;
  final Future<String> Function(String name) onSave;

  const _EditNameSheet({required this.initial, required this.onSave});

  @override
  State<_EditNameSheet> createState() => _EditNameSheetState();
}

class _EditNameSheetState extends State<_EditNameSheet> {
  late final TextEditingController _ctrl;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial.trim();
    _ctrl = TextEditingController(
      text: RegExp(r'^\d+$').hasMatch(initial) ? '' : initial,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _ctrl.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.length < 2) {
      setState(() => _error = 'Ingresá al menos 2 letras.');
      return;
    }
    if (name.length > 80) {
      setState(() => _error = 'Máximo 80 caracteres.');
      return;
    }
    if (RegExp(r'^\d+$').hasMatch(name)) {
      setState(() => _error = 'Ingresá tu nombre, no un número.');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      final saved = await widget.onSave(name);
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } on MobileApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.isNetwork
            ? 'Sin conexión. Revisá tu internet e intentá de nuevo.'
            : e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'No pudimos guardar el nombre. Probá de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6),
        LiquidTextField(
          controller: _ctrl,
          label: 'NOMBRE Y APELLIDO',
          hint: 'Ej.: Juan Pérez',
          autofocus: true,
          enabled: !_saving,
          errorText: _error,
          maxLength: 80,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          keyboardType: TextInputType.name,
          prefix: Icon(
            Icons.person_rounded,
            size: 18,
            color: Colors.white.withValues(alpha: 0.5),
          ),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 18),
        LiquidButton(
          onPressed: _saving ? null : _submit,
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.2,
                  ),
                )
              : const Text(
                  'Guardar',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
      ],
    );
  }
}

// ── Diálogo: la baja se frena por una seña sin resolver ────────────────────

/// Lo que ve el cliente cuando la edge function contesta 409
/// [codigoSenaPendiente]: no un error, sino **el paso que falta**.
///
/// Se cierra con `true` si el cliente eligió ir a "Mis turnos" (navega la
/// pantalla, no el diálogo) y con `false` si no.
///
/// Tiene una seña pagada por un turno que todavía no se cerró. Borrar la ficha
/// ahí dejaría el pago sin dueño: nadie a quien devolverle y nadie a quien
/// atender. Lo que destraba la baja es cancelar ese turno —el camino de
/// cancelación ya decide si la seña se devuelve o se pierde— o, si la fecha ya
/// pasó y el turno quedó a medias, hablar con el local.
class _SenaPendienteDialog extends StatelessWidget {
  const _SenaPendienteDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: LiquidGlass(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        borderRadius: LiquidTokens.radiusGroup,
        pressable: false,
        tintOpacity: 0.10,
        blur: LiquidTokens.blurHeavy,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        MonacoColors.warning.withValues(alpha: 0.26),
                        MonacoColors.warning.withValues(alpha: 0.08),
                      ],
                    ),
                    border: Border.all(
                      color: MonacoColors.warning.withValues(alpha: 0.36),
                      width: 0.8,
                    ),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: MonacoColors.warning,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Tenés una seña sin resolver',
                    style: TextStyle(
                      color: MonacoColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Pagaste la seña de un turno que todavía está en pie. Si '
              'borramos tu cuenta ahora, esa plata queda sin dueño y no te la '
              'podemos devolver.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Cancelá el turno desde "Mis turnos" y volvé a intentarlo. Si la '
              'fecha ya pasó o no lo encontrás, escribinos por WhatsApp y lo '
              'resolvemos con vos.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: LiquidPill(
                padding: const EdgeInsets.symmetric(vertical: 13),
                borderRadius: 16,
                tint: Colors.white,
                tintOpacity: 0.16,
                onTap: () => Navigator.of(context).pop(true),
                child: const Center(
                  child: Text(
                    'Ir a Mis turnos',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: LiquidPill(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    borderRadius: 16,
                    onTap: () => abrirUrlExterna(
                      context,
                      AppConstants.supportWhatsappUrl,
                    ),
                    child: const Center(
                      child: Text(
                        'Escribirnos',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: LiquidPill(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    borderRadius: 16,
                    onTap: () => Navigator.of(context).pop(false),
                    child: Center(
                      child: Text(
                        'Cerrar',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms).scaleXY(begin: 0.96, end: 1);
  }
}

// ── Diálogo: eliminar cuenta (dos pasos) ───────────────────────────────────

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  bool _acknowledged = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: LiquidGlass(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        borderRadius: LiquidTokens.radiusGroup,
        pressable: false,
        tintOpacity: 0.10,
        blur: LiquidTokens.blurHeavy,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        MonacoColors.destructive.withValues(alpha: 0.26),
                        MonacoColors.destructive.withValues(alpha: 0.08),
                      ],
                    ),
                    border: Border.all(
                      color: MonacoColors.destructive.withValues(alpha: 0.36),
                      width: 0.8,
                    ),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: MonacoColors.destructive,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Eliminar cuenta',
                    style: TextStyle(
                      color: MonacoColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Vamos a eliminar de forma permanente:',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            ..._items(const [
              // El email sólo existe si el alta fue con Google o Apple, y en
              // ese caso también se borra: la lista tiene que nombrarlo o el
              // cliente no sabe qué está aceptando.
              'Tus datos personales (nombre, teléfono y el email si entraste '
                  'con Google o Apple)',
              // Si el cliente se dio de alta en la tablet del local, ahí le
              // registraron la cara para reconocerlo al llegar. Es el dato más
              // sensible que tenemos de él y la lista no lo nombraba: nadie
              // acepta borrar algo que no sabe que existe.
              'La foto de tu cara, si te registraste en la tablet del local',
              'Tus puntos y premios acumulados',
              'Tus turnos, reseñas y canjes',
              'El acceso a tu cuenta en todos los dispositivos',
            ]),
            const SizedBox(height: 12),
            Text(
              'Por obligación fiscal quedan tus visitas y sus comprobantes, '
              'pero disociados: sin tu nombre ni tu teléfono, así que no se '
              'pueden volver a asociar con vos.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () =>
                    abrirUrlExterna(context, AppConstants.deleteAccountUrl),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white.withValues(alpha: 0.75),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Leer el detalle de qué se borra',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _acknowledged = !_acknowledged),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      duration: LiquidTokens.swap,
                      curve: LiquidTokens.curveSwap,
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _acknowledged
                              ? MonacoColors.destructive
                              : Colors.white.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                        color: _acknowledged
                            ? MonacoColors.destructive.withValues(alpha: 0.85)
                            : Colors.transparent,
                      ),
                      child: _acknowledged
                          ? const Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Entiendo que esta acción no se puede deshacer.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: LiquidPill(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    borderRadius: 16,
                    onTap: () => Navigator.of(context).pop(false),
                    child: const Center(
                      child: Text(
                        'Cancelar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AnimatedOpacity(
                    duration: LiquidTokens.swap,
                    opacity: _acknowledged ? 1 : 0.4,
                    child: LiquidPill(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      borderRadius: 16,
                      tint: MonacoColors.destructive,
                      tintOpacity: 0.18,
                      onTap: _acknowledged
                          ? () => Navigator.of(context).pop(true)
                          : null,
                      child: const Center(
                        child: Text(
                          'Eliminar',
                          style: TextStyle(
                            color: MonacoColors.destructive,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms).scaleXY(begin: 0.96, end: 1);
  }

  List<Widget> _items(List<String> texts) {
    return texts
        .map(
          (t) => Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: MonacoColors.destructive,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    t,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();
  }
}
