import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/core/push/push_service.dart';
import '../../data/notification_model.dart';
import '../../providers/notifications_provider.dart';
import '../widgets/push_pre_prompt.dart';

/// Preferencias de notificaciones (`/notificaciones/preferencias`): estado del
/// permiso del sistema + qué tipos quiere recibir el cliente
/// (`client_notification_preferences`).
class NotificationPreferencesScreen extends ConsumerStatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  ConsumerState<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends ConsumerState<NotificationPreferencesScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Al volver de Ajustes del sistema, el permiso pudo cambiar.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(pushPermissionProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final permission = ref.watch(pushPermissionProvider);
    final prefs = ref.watch(notificationPreferencesProvider);

    return LiquidAppBarScaffold(
      title: 'Preferencias',
      showBackButton: true,
      body: RefreshIndicator(
        color: Colors.white,
        backgroundColor: MonacoColors.surface,
        onRefresh: () async {
          ref.invalidate(pushPermissionProvider);
          ref.invalidate(notificationPreferencesProvider);
          await Future<void>.delayed(const Duration(milliseconds: 400));
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            _SectionLabel('Permiso del sistema').liquidEnter(index: 0),
            const SizedBox(height: 10),
            _PermissionCard(status: permission).liquidEnter(index: 1),
            const SizedBox(height: 26),
            _SectionLabel('Qué te avisamos').liquidEnter(index: 2),
            const SizedBox(height: 10),
            prefs
                .when(
                  loading: () => const LiquidSkeleton(height: 280, radius: 24),
                  error: (e, _) => LiquidErrorState(
                    error: e,
                    scrollable: false,
                    title: 'No pudimos cargar tus preferencias',
                    message:
                        'Probá de nuevo en unos segundos. Mientras tanto, recibís todas las notificaciones.',
                    onRetry: () =>
                        ref.invalidate(notificationPreferencesProvider),
                  ),
                  data: (p) => _PreferencesCard(prefs: p, onToggle: _toggle),
                )
                .liquidEnter(index: 3),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                'Estas preferencias aplican a las notificaciones push. Los avisos '
                'de seguridad de tu cuenta se envían siempre.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.42),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ).liquidEnter(index: 4),
          ],
        ),
      ),
    );
  }

  Future<void> _toggle(NotificationPreferenceField field, bool value) async {
    HapticFeedback.selectionClick();
    try {
      await ref
          .read(notificationPreferencesProvider.notifier)
          .toggle(field, value);
    } catch (_) {
      if (!mounted) return;
      showLiquidToast(
        context,
        'No pudimos guardar el cambio. Probá de nuevo.',
        tone: LiquidToastTone.error,
      );
    }
  }
}

// ── Permiso del sistema ────────────────────────────────────────────────────

class _PermissionCard extends ConsumerWidget {
  final AsyncValue<AuthorizationStatus?> status;
  const _PermissionCard({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = status.valueOrNull;
    final loading = status.isLoading;
    final available = PushService.isAvailable;
    final granted = PushService.isGranted(s);

    final (String title, String subtitle, Color color, IconData icon) = () {
      if (!available) {
        return (
          'No disponible en esta versión',
          'Las notificaciones push se habilitan en una próxima actualización.',
          Colors.white,
          Icons.notifications_off_rounded,
        );
      }
      if (loading) {
        return (
          'Consultando…',
          'Leyendo el estado del permiso.',
          Colors.white,
          Icons.notifications_rounded,
        );
      }
      if (granted) {
        return (
          s == AuthorizationStatus.provisional
              ? 'Activadas (silenciosas)'
              : 'Activadas',
          'Te llegan al teléfono aunque la app esté cerrada.',
          MonacoColors.monacoGreen,
          Icons.notifications_active_rounded,
        );
      }
      if (s == AuthorizationStatus.denied) {
        return (
          'Desactivadas',
          'El permiso está bloqueado en el sistema. Se activa desde Ajustes.',
          MonacoColors.warning,
          Icons.notifications_off_rounded,
        );
      }
      return (
        'Sin activar',
        'Todavía no nos diste permiso para avisarte.',
        Colors.white,
        Icons.notifications_none_rounded,
      );
    }();

    return LiquidGlass(
      pressable: false,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      borderRadius: LiquidTokens.radiusGroup,
      tint: granted ? MonacoColors.monacoGreen : Colors.white,
      tintOpacity: granted ? 0.10 : 0.08,
      showVignette: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withValues(alpha: 0.28),
                      color.withValues(alpha: 0.10),
                    ],
                  ),
                  border: Border.all(
                    color: color.withValues(alpha: 0.36),
                    width: 0.8,
                  ),
                ),
                child: Icon(icon, size: 21, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: MonacoColors.textPrimary,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (granted) ...[
                const SizedBox(width: 8),
                const LiquidStatusPill(
                  label: 'ACTIVO',
                  color: MonacoColors.monacoGreen,
                  compact: true,
                ),
              ],
            ],
          ),
          if (available && !loading) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (!granted && s != AuthorizationStatus.denied)
                  Expanded(
                    child: LiquidButton(
                      onPressed: () => requestPushWithPrePrompt(context, ref),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: const Text(
                        'Activar notificaciones',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: LiquidPill(
                      onTap: () => openPushSettingsOrExplain(context),
                      borderRadius: 16,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: const Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.settings_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Abrir Ajustes del sistema',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
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
        ],
      ),
    );
  }
}

// ── Toggles ────────────────────────────────────────────────────────────────

class _PreferencesCard extends StatelessWidget {
  final NotificationPreferences prefs;
  final Future<void> Function(NotificationPreferenceField, bool) onToggle;

  const _PreferencesCard({required this.prefs, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return LiquidSectionCard(
      children: [
        LiquidSwitchTile(
          icon: Icons.campaign_rounded,
          iconColor: MonacoColors.info,
          title: 'Campañas y novedades',
          subtitle: 'Promos, cartelera y noticias de Monaco',
          value: prefs.campaigns,
          onChanged: (v) => onToggle(NotificationPreferenceField.campaigns, v),
        ),
        LiquidSwitchTile(
          icon: Icons.alarm_rounded,
          iconColor: MonacoColors.warning,
          title: 'Recordatorios de turno',
          subtitle: 'El día anterior y dos horas antes',
          value: prefs.appointmentReminders,
          onChanged: (v) =>
              onToggle(NotificationPreferenceField.appointmentReminders, v),
        ),
        LiquidSwitchTile(
          icon: Icons.event_note_rounded,
          iconColor: MonacoColors.warning,
          title: 'Cambios en tus turnos',
          subtitle: 'Cancelaciones o cambios hechos por la barbería',
          value: prefs.appointmentUpdates,
          onChanged: (v) =>
              onToggle(NotificationPreferenceField.appointmentUpdates, v),
        ),
        LiquidSwitchTile(
          icon: Icons.card_giftcard_rounded,
          iconColor: MonacoColors.monacoGreen,
          title: 'Premios y puntos',
          subtitle: 'Cuando desbloqueás un premio o sumás puntos',
          value: prefs.rewards,
          onChanged: (v) => onToggle(NotificationPreferenceField.rewards, v),
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
