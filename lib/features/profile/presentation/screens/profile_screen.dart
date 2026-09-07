import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/core/api/mobile_api.dart';
import 'package:monaco_mobile/core/auth/auth_provider.dart';
import 'package:monaco_mobile/core/auth/biometric_service.dart';
import 'package:monaco_mobile/core/auth/secure_storage.dart';
import 'package:monaco_mobile/core/push/push_service.dart';
import 'package:monaco_mobile/core/utils/constants.dart';
import 'package:monaco_mobile/features/loyalty/data/loyalty_models.dart';
import 'package:monaco_mobile/features/loyalty/providers/loyalty_provider.dart';
import 'package:monaco_mobile/features/notifications/presentation/widgets/push_pre_prompt.dart';
import 'package:monaco_mobile/features/notifications/providers/notifications_provider.dart';
import 'package:monaco_mobile/features/onboarding/presentation/widgets/muro_login.dart';
import 'package:monaco_mobile/features/onboarding/presentation/widgets/onboarding_scaffold.dart';
import 'package:monaco_mobile/features/onboarding/utils/phone_format.dart';

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

  Future<bool> toggle() async {
    final next = !state;
    await SecureStorageService.setTestModeEnabled(next);
    state = next;
    return next;
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
      ref.invalidate(pushPermissionProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    if (auth.isGuest) return _perfilInvitado();

    final pushStatus = ref.watch(pushPermissionProvider);
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

    final pushAvailable = PushService.isAvailable;
    final pushGranted = PushService.isGranted(pushStatus.valueOrNull);

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
          ref.invalidate(pushPermissionProvider);
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
                LiquidSwitchTile(
                  icon: pushGranted
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                  iconColor: pushGranted ? MonacoColors.monacoGreen : null,
                  title: 'Notificaciones del sistema',
                  subtitle: !pushAvailable
                      ? 'No disponibles en esta versión de la app'
                      : pushGranted
                      ? 'Activadas. Se desactivan desde Ajustes.'
                      : pushStatus.valueOrNull == AuthorizationStatus.denied
                      ? 'Bloqueadas en el sistema. Se activan desde Ajustes.'
                      : 'Te avisamos de turnos, premios y novedades',
                  value: pushGranted,
                  onChanged: (v) => _onPushToggle(v, pushStatus.valueOrNull),
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

            // ── Legal y soporte ────────────────────────────────────────
            const _SectionLabel('Legal y soporte').liquidEnter(index: 10),
            const SizedBox(height: 10),
            LiquidSectionCard(
              children: [
                LiquidListTile(
                  icon: Icons.shield_outlined,
                  title: 'Política de privacidad',
                  onTap: () => _openUrl(AppConstants.privacyPolicyUrl),
                ),
                LiquidListTile(
                  icon: Icons.description_outlined,
                  title: 'Términos y condiciones',
                  onTap: () => _openUrl(AppConstants.termsOfServiceUrl),
                ),
                LiquidListTile(
                  icon: Icons.chat_rounded,
                  iconColor: MonacoColors.monacoGreen,
                  title: 'Soporte por WhatsApp',
                  subtitle:
                      '${AppConstants.supportPhoneDisplay} · en horario de atención',
                  onTap: () => _openUrl(AppConstants.supportWhatsappUrl),
                ),
                LiquidListTile(
                  icon: Icons.alternate_email_rounded,
                  title: 'Soporte por email',
                  subtitle: AppConstants.supportEmail,
                  onTap: () => _openUrl(
                    'mailto:${AppConstants.supportEmail}?subject=${Uri.encodeComponent('Soporte app Monaco')}',
                  ),
                ),
              ],
            ).liquidEnter(index: 11),

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

  Future<void> _onPushToggle(
    bool wantEnabled,
    AuthorizationStatus? status,
  ) async {
    if (!PushService.isAvailable) {
      showLiquidToast(
        context,
        'Las notificaciones push llegan en una próxima versión de la app.',
        tone: LiquidToastTone.info,
      );
      return;
    }
    if (wantEnabled) {
      if (status == AuthorizationStatus.denied) {
        // El prompt nativo no vuelve a aparecer: hay que ir a Ajustes.
        await openPushSettingsOrExplain(context);
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
      onAction: () => openPushSettingsOrExplain(context),
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

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        showLiquidToast(
          context,
          'No pudimos abrir el enlace.',
          tone: LiquidToastTone.error,
        );
      }
    } catch (_) {
      if (mounted) {
        showLiquidToast(
          context,
          'No pudimos abrir el enlace.',
          tone: LiquidToastTone.error,
        );
      }
    }
  }

  /// Perfil de un **invitado**: sin datos personales (no hay ninguno), con lo
  /// legal y el soporte —que son públicos y App Store los quiere accesibles— y
  /// con la puerta para crear la cuenta.
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

          const _SectionLabel('Legal y soporte').liquidEnter(index: 1),
          const SizedBox(height: 10),
          LiquidSectionCard(
            children: [
              LiquidListTile(
                icon: Icons.shield_outlined,
                title: 'Política de privacidad',
                onTap: () => _openUrl(AppConstants.privacyPolicyUrl),
              ),
              LiquidListTile(
                icon: Icons.description_outlined,
                title: 'Términos y condiciones',
                onTap: () => _openUrl(AppConstants.termsOfServiceUrl),
              ),
              LiquidListTile(
                icon: Icons.chat_rounded,
                iconColor: MonacoColors.monacoGreen,
                title: 'Soporte por WhatsApp',
                subtitle:
                    '${AppConstants.supportPhoneDisplay} · en horario de atención',
                onTap: () => _openUrl(AppConstants.supportWhatsappUrl),
              ),
              LiquidListTile(
                icon: Icons.alternate_email_rounded,
                title: 'Soporte por email',
                subtitle: AppConstants.supportEmail,
                onTap: () => _openUrl(
                  'mailto:${AppConstants.supportEmail}?subject=${Uri.encodeComponent('Soporte app Monaco')}',
                ),
              ),
            ],
          ).liquidEnter(index: 2),

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
      message:
          'Vas a tener que volver a ingresar con tu número de teléfono la próxima vez.',
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

    // Overlay bloqueante mientras borra.
    unawaited(
      showDialog<void>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.72),
        builder: (_) => const PopScope(
          canPop: false,
          child: Center(
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

    String? error;
    try {
      await PushService.unregister();
      error = await ref.read(authProvider.notifier).deleteAccount();
    } catch (e) {
      error = e.toString();
    }

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // cierra el overlay
    setState(() => _busy = false);

    if (error == null) {
      showLiquidToast(
        context,
        'Tu cuenta fue eliminada.',
        tone: LiquidToastTone.success,
      );
      context.go('/welcome');
    } else {
      showLiquidToast(
        context,
        'No pudimos eliminar la cuenta: $error',
        tone: LiquidToastTone.error,
        duration: const Duration(seconds: 5),
      );
    }
  }

  void _onVersionTap() {
    _versionTapTimer?.cancel();
    _versionTaps++;
    if (_versionTaps >= 7) {
      _versionTaps = 0;
      HapticFeedback.heavyImpact();
      ref.read(testModeEnabledProvider.notifier).toggle().then((enabled) {
        if (!mounted) return;
        showLiquidToast(
          context,
          enabled ? 'Modo prueba activado.' : 'Modo prueba desactivado.',
          tone: enabled ? LiquidToastTone.success : LiquidToastTone.neutral,
          icon: Icons.science_rounded,
        );
      });
      return;
    }
    if (_versionTaps >= 4) HapticFeedback.selectionClick();
    _versionTapTimer = Timer(const Duration(seconds: 2), () {
      _versionTaps = 0;
    });
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
              'Tus datos personales (nombre, teléfono)',
              'Tus puntos y premios acumulados',
              'Tus turnos, reseñas y canjes',
              'El acceso a tu cuenta en todos los dispositivos',
            ]),
            const SizedBox(height: 12),
            Text(
              'Los registros de visitas se anonimizan para mantener las estadísticas del negocio, pero no quedan asociados a tu identidad.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12,
                height: 1.35,
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
