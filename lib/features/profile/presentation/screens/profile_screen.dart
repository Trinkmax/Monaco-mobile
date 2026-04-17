import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
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
// Push notifications toggle (local state)
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

    return Scaffold(
      backgroundColor: MonacoColors.background,
      appBar: AppBar(
        title: const Text('Mi Perfil',
            style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: MonacoColors.surface,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
      ),
      body: asyncProfile.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: MonacoColors.gold),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        // ---- Avatar card ----
        _sectionCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: MonacoColors.gold.withOpacity(0.2),
                child: Text(
                  _initial(),
                  style: TextStyle(
                    color: MonacoColors.gold,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fullName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(phone,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 14)),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.edit_outlined,
                    color: Colors.white.withOpacity(0.25)),
                onPressed: null, // disabled for now
              ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05),

        const SizedBox(height: 24),

        // ---- Seguridad ----
        _sectionTitle('Seguridad'),
        const SizedBox(height: 8),
        _sectionCard(
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: MonacoColors.gold,
                title: const Text('Biometria',
                    style: TextStyle(color: Colors.white, fontSize: 15)),
                subtitle: const Text('Desbloquear con huella o Face ID',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
                secondary:
                    const Icon(Icons.fingerprint, color: MonacoColors.gold),
                value: biometricEnabled,
                onChanged: (val) =>
                    ref.read(biometricEnabledProvider.notifier).toggle(val),
              ),
              Divider(color: Colors.white.withOpacity(0.06), height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading:
                    const Icon(Icons.pin_outlined, color: MonacoColors.gold),
                title: const Text('Configurar PIN',
                    style: TextStyle(color: Colors.white, fontSize: 15)),
                trailing: const Icon(Icons.chevron_right,
                    color: Colors.white24, size: 20),
                onTap: () => context.push('/pin-setup'),
              ),
            ],
          ),
        ).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideY(begin: 0.05),

        const SizedBox(height: 24),

        // ---- Preferencias ----
        _sectionTitle('Preferencias'),
        const SizedBox(height: 8),
        _sectionCard(
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: MonacoColors.gold,
            title: const Text('Notificaciones push',
                style: TextStyle(color: Colors.white, fontSize: 15)),
            secondary: const Icon(Icons.notifications_outlined,
                color: MonacoColors.gold),
            value: pushEnabled,
            onChanged: (val) =>
                ref.read(pushNotificationsProvider.notifier).state = val,
          ),
        ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(begin: 0.05),

        const SizedBox(height: 24),

        // ---- Historial ----
        _sectionTitle('Historial'),
        const SizedBox(height: 8),
        _sectionCard(
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_month_outlined,
                    color: MonacoColors.gold),
                title: const Text('Mis visitas',
                    style: TextStyle(color: Colors.white, fontSize: 15)),
                trailing: const Icon(Icons.chevron_right,
                    color: Colors.white24, size: 20),
                onTap: () {}, // future
              ),
              Divider(color: Colors.white.withOpacity(0.06), height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.stars_rounded,
                    color: MonacoColors.gold),
                title: const Text('Transacciones de puntos',
                    style: TextStyle(color: Colors.white, fontSize: 15)),
                trailing: const Icon(Icons.chevron_right,
                    color: Colors.white24, size: 20),
                onTap: () => context.push('/points'),
              ),
              Divider(color: Colors.white.withOpacity(0.06), height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.local_offer_outlined,
                    color: MonacoColors.gold),
                title: const Text('Mis canjes',
                    style: TextStyle(color: Colors.white, fontSize: 15)),
                subtitle: const Text('Códigos activados y canjeados',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
                trailing: const Icon(Icons.chevron_right,
                    color: Colors.white24, size: 20),
                onTap: () => context.push('/mis-canjes'),
              ),
            ],
          ),
        ).animate().fadeIn(delay: 300.ms, duration: 400.ms).slideY(begin: 0.05),

        const SizedBox(height: 32),

        // ---- Cerrar sesion ----
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent, width: 1.2),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.logout, size: 20),
            label: const Text('Cerrar sesion',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            onPressed: () => _confirmLogout(context, ref),
          ),
        ).animate().fadeIn(delay: 400.ms, duration: 400.ms),

        const SizedBox(height: 24),

        // ---- Version ----
        Center(
          child: Text(
            'Version $version',
            style: const TextStyle(color: Colors.white24, fontSize: 12),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ---- Helpers ----
  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(title,
          style: TextStyle(
              color: MonacoColors.gold,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8)),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: MonacoColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: child,
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MonacoColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cerrar sesion',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text('¿Estas seguro de que queres cerrar sesion?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/welcome');
            },
            child: const Text('Cerrar sesion',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
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
    final title = offline ? 'Sin conexion' : 'Algo salio mal';
    final message = offline
        ? 'No pudimos conectarnos con el servidor. Revisa tu conexion a internet e intenta nuevamente.'
        : 'No pudimos cargar tu perfil. Intenta nuevamente en unos segundos.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: MonacoColors.gold.withOpacity(0.12),
              ),
              child: Icon(icon, color: MonacoColors.gold, size: 34),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: MonacoColors.gold,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text('Reintentar',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
