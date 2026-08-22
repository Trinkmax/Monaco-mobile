import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/features/visits/providers/visits_provider.dart';

/// Historial de visitas del cliente, agrupado por mes. Vive fuera del shell.
class VisitsScreen extends ConsumerWidget {
  const VisitsScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(visitsHistoryProvider);
    ref.invalidate(visitsSummaryProvider);
    await ref.read(visitsHistoryProvider.future).then((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(visitsHistoryProvider);
    final asyncSummary = ref.watch(visitsSummaryProvider);

    return LiquidAppBarScaffold(
      title: 'Mis visitas',
      showBackButton: true,
      body: RefreshIndicator(
        color: Colors.white,
        backgroundColor: MonacoColors.surface,
        onRefresh: () => _refresh(ref),
        child: async.when(
          loading: () => const _LoadingState(),
          error: (e, _) => LiquidErrorState(
            error: e,
            message: 'No pudimos cargar tus visitas. Probá en unos segundos.',
            onRetry: () => _refresh(ref),
          ),
          data: (visits) {
            if (visits.isEmpty) {
              return const LiquidEmptyState(
                icon: Icons.content_cut_rounded,
                title: 'Todavía no tenés visitas',
                message:
                    'Cuando pases por la barbería, tu historial aparecerá acá.',
              );
            }
            return _VisitsList(
              visits: visits,
              summary: asyncSummary.valueOrNull,
            );
          },
        ),
      ),
    );
  }
}

// ───────────────────────── List ─────────────────────────

class _VisitsList extends StatelessWidget {
  const _VisitsList({required this.visits, required this.summary});

  final List<Map<String, dynamic>> visits;
  final Map<String, num>? summary;

  /// Agrupa visitas por mes ("MMMM yyyy" localizado) conservando el orden.
  List<_Section> _groupByMonth() {
    final fmt = DateFormat('MMMM yyyy', 'es');
    final sections = <_Section>[];
    String? currentKey;
    List<Map<String, dynamic>>? currentItems;

    for (final v in visits) {
      final raw = v['completed_at'] as String? ?? v['created_at'] as String?;
      final dt = raw != null ? DateTime.tryParse(raw)?.toLocal() : null;
      if (dt == null) continue;
      final key = fmt.format(dt);
      if (key != currentKey) {
        currentItems = [];
        sections.add(_Section(label: _capitalize(key), items: currentItems));
        currentKey = key;
      }
      currentItems!.add(v);
    }

    return sections;
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  @override
  Widget build(BuildContext context) {
    final sections = _groupByMonth();
    final count = summary?['count']?.toInt() ?? visits.length;
    final totalSpent = summary?['total_spent'] ?? 0;

    final currency = NumberFormat.currency(
      locale: 'es_AR',
      symbol: r'$',
      decimalDigits: 0,
    );

    // Aplanamos secciones → lista con índice para el stagger de liquidEnter.
    final children = <Widget>[];
    children.add(
      _SummaryCard(
        count: count,
        totalSpent: currency.format(totalSpent),
      ).liquidEnter(index: 0),
    );
    children.add(const SizedBox(height: 26));

    var idx = 1;
    for (final s in sections) {
      children.add(_SectionTitle(s.label).liquidEnter(index: idx++));
      children.add(const SizedBox(height: 10));
      children.add(
        LiquidSectionCard(
          children: [
            for (final v in s.items) _VisitTile(visit: v, currency: currency),
          ],
        ).liquidEnter(index: idx++),
      );
      children.add(const SizedBox(height: 22));
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
      children: children,
    );
  }
}

class _Section {
  final String label;
  final List<Map<String, dynamic>> items;
  _Section({required this.label, required this.items});
}

// ───────────────────────── Summary ─────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.count, required this.totalSpent});

  final int count;
  final String totalSpent;

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      borderRadius: 24,
      tintOpacity: 0.09,
      pressable: false,
      child: Row(
        children: [
          Expanded(
            child: _Stat(
              icon: Icons.content_cut_rounded,
              label: 'Visitas',
              value: '$count',
            ),
          ),
          Container(
            width: 1,
            height: 44,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: Colors.white.withValues(alpha: 0.12),
          ),
          Expanded(
            child: _Stat(
              icon: Icons.payments_outlined,
              label: 'Total invertido',
              value: totalSpent,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.7)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: MonacoColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── Tile ─────────────────────────

class _VisitTile extends StatelessWidget {
  const _VisitTile({required this.visit, required this.currency});

  final Map<String, dynamic> visit;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final branch = visit['branches'] as Map<String, dynamic>?;
    final staff = visit['staff'] as Map<String, dynamic>?;
    final service = visit['services'] as Map<String, dynamic>?;

    final serviceName = service?['name'] as String? ?? 'Corte';
    final barberName = staff?['full_name'] as String? ?? 'Barbero';
    final barberAvatar = staff?['avatar_url'] as String?;
    final branchName = branch?['name'] as String? ?? 'Sucursal';

    final rawDate = visit['completed_at'] as String? ??
        visit['created_at'] as String?;
    final dt = rawDate != null ? DateTime.tryParse(rawDate)?.toLocal() : null;
    final dateLabel = dt != null
        ? DateFormat("d 'de' MMMM", 'es').format(dt)
        : '';
    final timeLabel =
        dt != null ? DateFormat('HH:mm').format(dt) : '';

    final amount = visit['amount'];
    num amountNum = 0;
    if (amount is num) amountNum = amount;
    if (amount is String) amountNum = num.tryParse(amount) ?? 0;
    final amountLabel = currency.format(amountNum);

    final tags = (visit['tags'] as List?)?.cast<String>() ?? const [];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LiquidAvatar(imageUrl: barberAvatar, name: barberName, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        serviceName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: MonacoColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      amountLabel,
                      style: const TextStyle(
                        color: MonacoColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'con $barberName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _MetaChip(
                      icon: Icons.place_outlined,
                      label: branchName,
                    ),
                    if (dateLabel.isNotEmpty)
                      _MetaChip(
                        icon: Icons.calendar_today_rounded,
                        label: timeLabel.isNotEmpty
                            ? '$dateLabel · $timeLabel'
                            : dateLabel,
                      ),
                    for (final t in tags.take(2))
                      _MetaChip(icon: Icons.label_outline_rounded, label: t),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white.withValues(alpha: 0.55)),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Section title ─────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

// ───────────────────────── Loading ─────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
      children: const [
        LiquidSkeleton(height: 92, radius: 24),
        SizedBox(height: 26),
        LiquidSkeleton.line(width: 120, height: 14),
        SizedBox(height: 12),
        LiquidSkeleton(height: 270, radius: 24),
        SizedBox(height: 22),
        LiquidSkeleton.line(width: 100, height: 14),
        SizedBox(height: 12),
        LiquidSkeleton(height: 180, radius: 24),
      ],
    );
  }
}
