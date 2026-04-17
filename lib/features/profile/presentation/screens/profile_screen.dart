import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/core/auth/auth_provider.dart';
import 'package:monaco_mobile/core/auth/secure_storage.dart';
import 'package:monaco_mobile/core/supabase/supabase_provider.dart';

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
// Push notifications toggle (local)
// ---------------------------------------------------------------------------
final pushNotificationsProvider = StateProvider<bool>((ref) => true);

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
    final pushEnabled = ref.watch(pushNotificationsProvider);
    final asyncVersion = ref.watch(appVersionProvider);

    return LiquidAppBarScaffold(
      title: 'Mi Perfil',
      background: const LiquidBackdrop(child: SizedBox.expand()),
      body: asyncProfile.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: LiquidTokens.monacoGreen),
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
          tint: LiquidTokens.monacoGreen,
          tintOpacity: 0.08,
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
              iconColor: LiquidTokens.monacoGreen,
              title: 'Biometría',
              subtitle: 'Desbloquear con huella o Face ID',
              value: biometricEnabled,
              onChanged: (val) =>
                  ref.read(biometricEnabledProvider.notifier).toggle(val),
            ),
            LiquidListTile(
              icon: Icons.pin_outlined,
              iconColor: LiquidTokens.monacoGreen,
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
              iconColor: LiquidTokens.monacoGreen,
              title: 'Notificaciones push',
              value: pushEnabled,
              onChanged: (val) =>
                  ref.read(pushNotificationsProvider.notifier).state = val,
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
              iconColor: LiquidTokens.monacoGreen,
              title: 'Mis visitas',
              onTap: () {},
            ),
            LiquidListTile(
              icon: Icons.stars_rounded,
              iconColor: LiquidTokens.monacoGreen,
              title: 'Transacciones de puntos',
              onTap: () => context.push('/points'),
            ),
            LiquidListTile(
              icon: Icons.local_offer_outlined,
              iconColor: LiquidTokens.monacoGreen,
              title: 'Mis canjes',
              subtitle: 'Códigos activados y canjeados',
              onTap: () => context.push('/mis-canjes'),
            ),
          ],
        ).liquidEnter(index: 6),

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
        ).liquidEnter(index: 7),

        const SizedBox(height: 22),

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
            LiquidTokens.monacoGreen.withOpacity(0.28),
            LiquidTokens.monacoGreen.withOpacity(0.12),
          ],
        ),
        border: Border.all(
          color: LiquidTokens.monacoGreen.withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: LiquidTokens.monacoGreen.withOpacity(0.38),
            blurRadius: 20,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: LiquidTokens.monacoGreen,
            fontSize: 30,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
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
                    LiquidTokens.monacoGreen.withOpacity(0.2),
                    LiquidTokens.monacoGreen.withOpacity(0.06),
                  ],
                ),
                border: Border.all(
                  color: LiquidTokens.monacoGreen.withOpacity(0.32),
                ),
              ),
              child: Icon(icon, color: LiquidTokens.monacoGreen, size: 34),
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
