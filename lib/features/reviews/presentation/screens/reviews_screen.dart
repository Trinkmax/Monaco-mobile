import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/core/utils/formatters.dart';
import 'package:monaco_mobile/features/reviews/providers/reviews_provider.dart';

/// Lista de visitas que todavía no tienen reseña. Cada tarjeta lleva al flujo
/// de calificación (`/review/:token`).
class ReviewsScreen extends ConsumerWidget {
  const ReviewsScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(pendingReviewsProvider);
    await ref.read(pendingReviewsProvider.future).then((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingReviews = ref.watch(pendingReviewsProvider);

    return LiquidAppBarScaffold(
      title: 'Reseñas pendientes',
      showBackButton: true,
      body: RefreshIndicator(
        color: Colors.white,
        backgroundColor: MonacoColors.surface,
        onRefresh: () => _refresh(ref),
        child: pendingReviews.when(
          loading: () => const LiquidSkeletonList(
            count: 4,
            itemHeight: 118,
            padding: EdgeInsets.fromLTRB(20, 12, 20, 48),
          ),
          error: (error, _) => LiquidErrorState(
            error: error,
            onRetry: () => _refresh(ref),
          ),
          data: (reviews) {
            if (reviews.isEmpty) {
              return LiquidEmptyState(
                icon: Icons.mark_chat_read_rounded,
                title: 'Estás al día',
                message:
                    'No tenés reseñas pendientes. Después de tu próxima visita te vamos a pedir tu opinión.',
                ctaLabel: 'Volver',
                onCta: () => context.pop(),
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
              itemCount: reviews.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _Intro(count: reviews.length).liquidEnter(index: 0);
                }
                final item = reviews[index - 1];
                return _ReviewCard(
                  item: item,
                  onTap: () => context.push('/review/${item['token']}'),
                ).liquidEnter(index: index);
              },
            );
          },
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  final int count;
  const _Intro({required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 2, right: 2),
      child: Text(
        count == 1
            ? 'Tenés 1 visita sin calificar. Nos lleva menos de un minuto.'
            : 'Tenés $count visitas sin calificar. Nos lleva menos de un minuto.',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.55),
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
          height: 1.4,
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const _ReviewCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const amber = MonacoColors.warning;
    final branchName = item['branch_name'] as String? ?? 'Sucursal';
    final barberName = item['barber_name'] as String? ?? '';
    final visitDateRaw = item['visit_date'] as String? ?? '';
    final visitDate = DateTime.tryParse(visitDateRaw);

    return LiquidGlass(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      borderRadius: 20,
      tint: amber,
      tintOpacity: 0.05,
      showVignette: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      amber.withValues(alpha: 0.28),
                      amber.withValues(alpha: 0.10),
                    ],
                  ),
                  border: Border.all(
                    color: amber.withValues(alpha: 0.4),
                    width: 0.8,
                  ),
                ),
                child: const Icon(Icons.rate_review_rounded,
                    color: amber, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      branchName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MonacoColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (barberName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'con $barberName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const LiquidStatusPill(
                label: 'Pendiente',
                color: amber,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 13,
                color: Colors.white.withValues(alpha: 0.45),
              ),
              const SizedBox(width: 6),
              Text(
                visitDate != null ? Formatters.date(visitDate) : 'Visita reciente',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                'Calificar',
                style: TextStyle(
                  color: amber.withValues(alpha: 0.98),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 3),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 11,
                color: amber.withValues(alpha: 0.98),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
