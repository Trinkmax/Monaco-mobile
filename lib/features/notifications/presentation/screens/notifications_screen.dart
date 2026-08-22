import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/core/push/push_handler.dart';
import '../../data/notification_model.dart';
import '../../providers/notifications_provider.dart';

/// Bandeja de notificaciones (`/notificaciones`): historial de push del
/// cliente, en vivo por Realtime, agrupado en Hoy / Esta semana / Antes.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(inboxProvider);
    final unread = ref.watch(unreadNotificationsCountProvider);

    return LiquidAppBarScaffold(
      title: 'Notificaciones',
      showBackButton: true,
      actions: [
        if (unread > 0)
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Semantics(
              button: true,
              label: 'Marcar todas como leídas',
              child: LiquidPill(
                onTap: () => _markAll(context, ref),
                // 44 px de alto: objetivo táctil mínimo (CONTRACTS §6.8).
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.done_all_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Marcar todas',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
      body: inbox.when(
        loading: () => const LiquidSkeletonList(
          count: 5,
          itemHeight: 84,
          padding: EdgeInsets.fromLTRB(20, 14, 20, 40),
        ),
        error: (e, _) => LiquidErrorState(
          error: e,
          onRetry: () => ref.invalidate(notificationsStreamProvider),
        ),
        data: (list) => RefreshIndicator(
          color: Colors.white,
          backgroundColor: MonacoColors.surface,
          onRefresh: () async {
            ref.invalidate(notificationsStreamProvider);
            await Future<void>.delayed(const Duration(milliseconds: 500));
          },
          child: list.isEmpty
              ? const LiquidEmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: 'Sin notificaciones',
                  message:
                      'Acá vas a ver tus recordatorios de turno, premios y novedades de Monaco.',
                )
              : _InboxList(items: list),
        ),
      ),
    );
  }

  Future<void> _markAll(BuildContext context, WidgetRef ref) async {
    HapticFeedback.lightImpact();
    try {
      await ref.read(notificationsActionsProvider).markAllRead();
      if (context.mounted) {
        showLiquidToast(
          context,
          'Todas marcadas como leídas.',
          tone: LiquidToastTone.success,
        );
      }
    } catch (e) {
      if (context.mounted) {
        showLiquidToast(
          context,
          'No pudimos marcarlas. Probá de nuevo.',
          tone: LiquidToastTone.error,
        );
      }
    }
  }
}

// ── Lista agrupada ─────────────────────────────────────────────────────────

enum _Bucket { today, week, earlier }

extension on _Bucket {
  String get label => switch (this) {
    _Bucket.today => 'Hoy',
    _Bucket.week => 'Esta semana',
    _Bucket.earlier => 'Antes',
  };
}

_Bucket _bucketOf(DateTime dt, DateTime now) {
  final startOfToday = DateTime(now.year, now.month, now.day);
  if (!dt.isBefore(startOfToday)) return _Bucket.today;
  final startOfWeek = startOfToday.subtract(const Duration(days: 6));
  if (!dt.isBefore(startOfWeek)) return _Bucket.week;
  return _Bucket.earlier;
}

class _InboxList extends ConsumerWidget {
  final List<ClientNotification> items;
  const _InboxList({required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final rows = <Widget>[];
    _Bucket? current;
    var index = 0;
    for (final n in items) {
      final b = _bucketOf(n.createdAt, now);
      if (b != current) {
        current = b;
        rows.add(
          Padding(
            padding: EdgeInsets.only(top: rows.isEmpty ? 4 : 22, bottom: 10),
            child: _GroupHeader(label: b.label),
          ).liquidEnter(index: index++),
        );
      }
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _NotificationTile(
            notification: n,
            onTap: () => _open(context, ref, n),
          ),
        ).liquidEnter(index: index++, stagger: 45),
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
      children: rows,
    );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    ClientNotification n,
  ) async {
    HapticFeedback.selectionClick();
    // Marcar leída es fire-and-forget: la navegación no espera al server.
    ref.read(notificationsActionsProvider).markRead(n);
    final route = n.route;
    if (!context.mounted) return;
    final path = Uri.parse(route).path;
    if (const {
      '/home',
      '/turnos',
      '/occupancy',
      '/rewards',
      '/profile',
    }.contains(path)) {
      context.go(route);
    } else if (PushHandler.isInternalPath(route)) {
      context.push(route);
    }
  }
}

class _GroupHeader extends StatelessWidget {
  final String label;
  const _GroupHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Text(
        label.toUpperCase(),
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

class _NotificationTile extends StatelessWidget {
  final ClientNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  static final _timeFmt = DateFormat('HH:mm', 'es');
  static final _dayFmt = DateFormat('EEE d', 'es');
  static final _dateFmt = DateFormat('d MMM', 'es');

  String _when(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    final startOfToday = DateTime(now.year, now.month, now.day);
    if (!dt.isBefore(startOfToday)) return _timeFmt.format(dt);
    if (diff.inDays < 7) {
      return '${_dayFmt.format(dt)} · ${_timeFmt.format(dt)}';
    }
    return _dateFmt.format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final unread = !n.isRead;
    final accent = n.accent;

    return Semantics(
      button: true,
      label: '${unread ? 'No leída. ' : ''}${n.title}',
      child: LiquidGlass(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        borderRadius: LiquidTokens.radiusCard,
        tint: unread ? accent : Colors.white,
        tintOpacity: unread ? 0.11 : 0.06,
        blur: LiquidTokens.blurSubtle,
        showVignette: false,
        scalePressed: 0.98,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TypeBadge(icon: n.icon, color: accent, dim: !unread),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(
                              alpha: unread ? 1 : 0.82,
                            ),
                            fontSize: 14.5,
                            fontWeight: unread
                                ? FontWeight.w800
                                : FontWeight.w600,
                            letterSpacing: -0.2,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _when(n.createdAt),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.42),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  if (n.body != null && n.body!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      n.body!.trim(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(
                          alpha: unread ? 0.7 : 0.5,
                        ),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 10,
              child: unread
                  ? Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: _UnreadDot(),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool dim;
  const _TypeBadge({
    required this.icon,
    required this.color,
    required this.dim,
  });

  @override
  Widget build(BuildContext context) {
    final c = dim ? Colors.white : color;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            c.withValues(alpha: dim ? 0.12 : 0.28),
            c.withValues(alpha: dim ? 0.05 : 0.10),
          ],
        ),
        border: Border.all(
          color: c.withValues(alpha: dim ? 0.16 : 0.38),
          width: 0.8,
        ),
        boxShadow: dim
            ? null
            : [
                BoxShadow(
                  color: c.withValues(alpha: 0.22),
                  blurRadius: 10,
                  spreadRadius: -3,
                ),
              ],
      ),
      child: Icon(icon, size: 19, color: c.withValues(alpha: dim ? 0.7 : 1)),
    );
  }
}

class _UnreadDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: MonacoColors.monacoGreen,
            boxShadow: [
              BoxShadow(
                color: MonacoColors.monacoGreen.withValues(alpha: 0.7),
                blurRadius: 8,
              ),
            ],
          ),
        )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(begin: 1.0, end: 1.25, duration: 1000.ms);
  }
}
