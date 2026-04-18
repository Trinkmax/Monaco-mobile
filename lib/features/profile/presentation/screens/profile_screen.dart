import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/core/auth/auth_provider.dart';
import 'package:monaco_mobile/core/auth/secure_storage.dart';
import 'package:monaco_mobile/core/supabase/supabase_provider.dart';
import 'package:monaco_mobile/core/push/push_service.dart';
import 'package:monaco_mobile/core/utils/constants.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// ---------------------------------------------------------------------------
// Client profile provider
// ---------------------------------------------------------------------------
final clientProfileProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return {};
  final res = await supabase
      .from('clients')
      .select()
      .eq('auth_user_id', userId)
      .maybeSingle();
  if (res != null) return Map<String, dynamic>.from(res);
  return {};
});

// ---------------------------------------------------------------------------
// Biometric toggle provider
// ---------------------------------------------------------------------------
final biometricEnabledProvider =
    StateNotifierProvider<_BiometricNotifier, bool>(
  (ref) => _BiometricNotifier(),
);

class _BiometricNotifier extends StateNotifier<bool> {
  _BiometricNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    state = await SecureStorageService.isBiometricEnabled();
  }

  Future<void> toggle(bool value) async {
    await SecureStorageService.setBiometricEnabled(value);
    state = value;
  }
}

// ---------------------------------------------------------------------------
// Push notifications — estado real del sistema iOS
// ---------------------------------------------------------------------------
final pushPermissionProvider =
    FutureProvider.autoDispose<AuthorizationStatus?>((ref) async {
  return PushService.currentAuthorizationStatus();
});

// ---------------------------------------------------------------------------
// App version provider
// ---------------------------------------------------------------------------
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncProfile = ref.watch(clientProfileProvider);
    final biometricEnabled = ref.watch(biometricEnabledProvider);
    final pushStatus = ref.watch(pushPermissionProvider);
    final asyncVersion = ref.watch(appVersionProvider);

    final pushEnabled = pushStatus.valueOrNull == AuthorizationStatus.authorized
        || pushStatus.valueOrNull == AuthorizationStatus.provisional;

    return LiquidAppBarScaffold(
      title: 'Mi Perfil',
      body: asyncProfile.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        error: (e, _) => _ErrorState(
          error: e,
          onRetry: () => ref.invalidate(clientProfileProvider),
        ),
        data: (profile) => _ProfileBody(
          profile: profile,
          biometricEnabled: biometricEnabled,
          pushEnabled: pushEnabled,
          version: asyncVersion.valueOrNull ?? '...',
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body
// ---------------------------------------------------------------------------
class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({
    required this.profile,
    required this.biometricEnabled,
    required this.pushEnabled,
    required this.version,
  });

  final Map<String, dynamic> profile;
  final bool biometricEnabled;
  final bool pushEnabled;
  final String version;

  String _initial() {
    final name = profile['name'] as String? ?? '';
    if (name.isEmpty) return '?';
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fullName = profile['name'] as String? ?? 'Sin nombre';
    final phone = profile['phone'] as String? ?? '';

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 140),
      children: [
        // ---- Avatar card ----
        LiquidGlass(
          padding: const EdgeInsets.all(18),
          borderRadius: 24,
          tintOpacity: 0.09,
          pressable: false,
          child: Row(
            children: [
              _AvatarCircle(initial: _initial()),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: const TextStyle(
                        color: MonacoColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        phone,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.55),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ).liquidEnter(index: 0),

        const SizedBox(height: 26),

        // ---- Seguridad ----
        _SectionTitle('Seguridad').liquidEnter(index: 1),
        const SizedBox(height: 10),
        LiquidSectionCard(
          children: [
            LiquidSwitchTile(
              icon: Icons.fingerprint_rounded,
              title: 'Biometría',
              subtitle: 'Desbloquear con huella o Face ID',
              value: biometricEnabled,
              onChanged: (val) =>
                  ref.read(biometricEnabledProvider.notifier).toggle(val),
            ),
            LiquidListTile(
              icon: Icons.pin_outlined,
              title: 'Configurar PIN',
              onTap: () => context.push('/pin-setup'),
            ),
          ],
        ).liquidEnter(index: 2),

        const SizedBox(height: 26),

        // ---- Preferencias ----
        _SectionTitle('Preferencias').liquidEnter(index: 3),
        const SizedBox(height: 10),
        LiquidSectionCard(
          children: [
            LiquidSwitchTile(
              icon: Icons.notifications_outlined,
              title: 'Notificaciones push',
              subtitle: pushEnabled
                  ? 'Activadas. Podés desactivarlas desde Ajustes de iOS.'
                  : 'Te avisamos cuando llamamos tu turno o sumás puntos.',
              value: pushEnabled,
              onChanged: (val) => _onPushToggle(context, ref, val),
            ),
          ],
        ).liquidEnter(index: 4),

        const SizedBox(height: 26),

        // ---- Historial ----
        _SectionTitle('Historial').liquidEnter(index: 5),
        const SizedBox(height: 10),
        LiquidSectionCard(
          children: [
            LiquidListTile(
              icon: Icons.calendar_month_outlined,
              title: 'Mis visitas',
              onTap: () => context.push('/visits'),
            ),
            LiquidListTile(
              icon: Icons.stars_rounded,
              title: 'Transacciones de puntos',
              onTap: () => context.push('/points'),
            ),
            LiquidListTile(
              icon: Icons.local_offer_outlined,
              title: 'Mis canjes',
              subtitle: 'Códigos activados y canjeados',
              onTap: () => context.push('/mis-canjes'),
            ),
          ],
        ).liquidEnter(index: 6),

        const SizedBox(height: 26),

        // ---- Legal y soporte ----
        _SectionTitle('Legal y soporte').liquidEnter(index: 7),
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
              icon: Icons.support_agent_outlined,
              title: 'Soporte',
              subtitle: AppConstants.supportEmail,
              onTap: () => _openUrl('mailto:${AppConstants.supportEmail}'),
            ),
          ],
        ).liquidEnter(index: 8),

        const SizedBox(height: 32),

        // ---- Cerrar sesión ----
        LiquidPill(
          onTap: () => _confirmLogout(context, ref),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          tint: Colors.redAccent,
          tintOpacity: 0.12,
          borderRadius: 18,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.logout_rounded, size: 20, color: Colors.redAccent),
              SizedBox(width: 10),
              Text(
                'Cerrar sesión',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ).liquidEnter(index: 9),

        const SizedBox(height: 14),

        // ---- Eliminar cuenta (Apple Guideline 5.1.1(v)) ----
        GestureDetector(
          onTap: () => _confirmDeleteAccount(context, ref),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: Text(
                'Eliminar mi cuenta',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white.withOpacity(0.25),
                ),
              ),
            ),
          ),
        ).liquidEnter(index: 10),

        const SizedBox(height: 18),

        Center(
          child: Text(
            'Versión $version',
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _onPushToggle(
      BuildContext context, WidgetRef ref, bool wantEnabled) async {
    if (wantEnabled) {
      // Pre-prompt contextual antes del dialog nativo de iOS.
      final accepted = await showDialog<bool>(
        context: context,
        barrierColor: Colors.black.withOpacity(0.6),
        builder: (ctx) => const _PushPrePromptDialog(),
      );
      if (accepted != true) return;

      final status = await PushService.requestPermissionExplicitly();
      ref.invalidate(pushPermissionProvider);

      if (context.mounted &&
          status != null &&
          status != AuthorizationStatus.authorized &&
          status != AuthorizationStatus.provisional) {
        _showOpenSettingsSnack(context,
            'No pudimos activar las notificaciones. Podés habilitarlas desde Ajustes.');
      }
    } else {
      // iOS no permite revocar permiso desde la app: mandamos al usuario a Ajustes.
      _showOpenSettingsSnack(context,
          'Para desactivarlas, abrí Ajustes de iOS > Notificaciones > Monaco Mobile.');
    }
  }

  void _showOpenSettingsSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.black.withOpacity(0.92),
        content: Text(message),
        action: SnackBarAction(
          label: 'Ajustes',
          textColor: Colors.white,
          onPressed: () => launchUrl(Uri.parse('app-settings:')),
        ),
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.72),
      builder: (ctx) => _DeleteAccountDialog(
        onConfirm: () async {
          Navigator.of(ctx).pop();
          await _executeDeleteAccount(context, ref);
        },
      ),
    );
  }

  Future<void> _executeDeleteAccount(
      BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();

    // Loading dialog bloqueante
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.72),
      builder: (_) => const Dialog(
        backgroundColor: Colors.transparent,
        child: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
    );

    final error = await ref.read(authProvider.notifier).deleteAccount();

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // cerrar loading

    if (error == null) {
      if (context.mounted) context.go('/welcome');
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent.withOpacity(0.95),
            content: Text('No se pudo eliminar la cuenta: $error'),
          ),
        );
      }
    }
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: LiquidGlass(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          borderRadius: 24,
          pressable: false,
          tintOpacity: 0.10,
          blur: LiquidTokens.blurHeavy,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cerrar sesión',
                style: TextStyle(
                  color: MonacoColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '¿Estás seguro de que querés cerrar sesión?',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: LiquidPill(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      onTap: () => Navigator.of(ctx).pop(),
                      child: const Center(
                        child: Text(
                          'Cancelar',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LiquidButton(
                      primary: false,
                      tint: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        await ref.read(authProvider.notifier).logout();
                        if (context.mounted) context.go('/welcome');
                      },
                      child: const Text(
                        'Cerrar sesión',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  final String initial;
  const _AvatarCircle({required this.initial});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.22),
            Colors.white.withOpacity(0.08),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.28),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.32),
            blurRadius: 14,
            spreadRadius: -2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Push notifications pre-prompt (Apple Guideline 4.5.4)
// ---------------------------------------------------------------------------
class _PushPrePromptDialog extends StatelessWidget {
  const _PushPrePromptDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: LiquidGlass(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        borderRadius: 24,
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
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.12),
                  ),
                  child: const Icon(Icons.notifications_active_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Activar notificaciones',
                    style: TextStyle(
                      color: MonacoColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Con tu permiso te avisamos cuando:',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _bullet('Se acerca tu turno en la cola'),
            _bullet('Sumás puntos o desbloqueás un premio'),
            _bullet('Hay promociones nuevas para vos'),
            const SizedBox(height: 12),
            Text(
              'En el siguiente paso, iOS te pedirá confirmación.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: LiquidPill(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    onTap: () => Navigator.of(context).pop(false),
                    child: const Center(
                      child: Text(
                        'Ahora no',
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
                  child: LiquidButton(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text(
                      'Continuar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.82),
                fontSize: 13.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Delete account dialog (2-step confirmation)
// ---------------------------------------------------------------------------
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.onConfirm});

  final VoidCallback onConfirm;

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
        borderRadius: 24,
        pressable: false,
        tintOpacity: 0.10,
        blur: LiquidTokens.blurHeavy,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.redAccent.shade200, size: 22),
                const SizedBox(width: 8),
                const Text(
                  'Eliminar cuenta',
                  style: TextStyle(
                    color: MonacoColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Vamos a eliminar de forma permanente:',
              style: TextStyle(
                color: Colors.white.withOpacity(0.75),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            ..._items([
              'Tus datos personales (nombre, teléfono)',
              'Tus puntos y premios acumulados',
              'Tu historial de reviews y canjes',
              'El acceso a tu cuenta en todos los dispositivos',
            ]),
            const SizedBox(height: 12),
            Text(
              'Los registros de visitas se anonimizan para mantener las estadísticas del negocio, pero no quedarán asociados a tu identidad.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _acknowledged = !_acknowledged),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _acknowledged
                              ? Colors.redAccent
                              : Colors.white.withOpacity(0.35),
                          width: 1.5,
                        ),
                        color: _acknowledged
                            ? Colors.redAccent.withOpacity(0.85)
                            : Colors.transparent,
                      ),
                      child: _acknowledged
                          ? const Icon(Icons.check,
                              size: 16, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Entiendo que esta acción no se puede deshacer.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
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
                    onTap: () => Navigator.of(context).pop(),
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
                  child: Opacity(
                    opacity: _acknowledged ? 1 : 0.4,
                    child: LiquidButton(
                      primary: false,
                      tint: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      onPressed: _acknowledged ? widget.onConfirm : null,
                      child: const Text(
                        'Eliminar',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
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
    );
  }

  List<Widget> _items(List<String> texts) {
    return texts
        .map((t) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•',
                      style: TextStyle(
                          color: Colors.redAccent.shade200,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.78),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ))
        .toList();
  }
}

// ---------------------------------------------------------------------------
// Error state
// ---------------------------------------------------------------------------
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  bool get _isNetworkError {
    final s = error.toString().toLowerCase();
    return s.contains('socketexception') ||
        s.contains('failed host lookup') ||
        s.contains('no address associated') ||
        s.contains('authretryablefetchexception') ||
        s.contains('clientexception') ||
        s.contains('connection') ||
        s.contains('network is unreachable') ||
        s.contains('timeout');
  }

  @override
  Widget build(BuildContext context) {
    final offline = _isNetworkError;
    final icon = offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded;
    final title = offline ? 'Sin conexión' : 'Algo salió mal';
    final message = offline
        ? 'No pudimos conectarnos con el servidor. Revisá tu conexión a internet e intentá nuevamente.'
        : 'No pudimos cargar tu perfil. Intentá nuevamente en unos segundos.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.18),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
                border: Border.all(color: Colors.white.withOpacity(0.22)),
              ),
              child: Icon(icon, color: Colors.white, size: 34),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                color: MonacoColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 22),
            LiquidButton(
              onPressed: onRetry,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Reintentar',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}
