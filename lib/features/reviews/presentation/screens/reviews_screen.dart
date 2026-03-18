import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/core/utils/formatters.dart';
import 'package:monaco_mobile/features/reviews/providers/reviews_provider.dart';

class ReviewsScreen extends ConsumerWidget {
  const ReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingReviews = ref.watch(pendingReviewsProvider);

    return Scaffold(
      backgroundColor: MonacoColors.background,
      appBar: AppBar(
        title: const Text(
          'Reseñas pendientes',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: MonacoColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: RefreshIndicator(
        color: MonacoColors.primary,
        backgroundColor: MonacoColors.surface,
        onRefresh: () async {
          ref.invalidate(pendingReviewsProvider);
          await ref.read(pendingReviewsProvider.future);
        },
        child: pendingReviews.when(
          loading: () => _buildShimmerList(),
          error: (error, _) => _buildErrorState(context, ref, error),
          data: (reviews) {
            if (reviews.isEmpty) {
              return _buildEmptyState();
            }
            return _buildReviewsList(context, reviews);
          },
        ),
      ),
    );
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 110,
          decoration: BoxDecoration(
            color: MonacoColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
        )
            .animate(onPlay: (c) => c.repeat())
            .shimmer(
              duration: 1200.ms,
              color: Colors.white.withOpacity(0.05),
            );
      },
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Error al cargar reseñas',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () => ref.invalidate(pendingReviewsProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
              style: TextButton.styleFrom(
                foregroundColor: MonacoColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: constraints.maxHeight,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: MonacoColors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.mark_chat_read_rounded,
                      size: 40,
                      color: Colors.white.withOpacity(0.3),
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .scale(
                        begin: const Offset(0.8, 0.8),
                        end: const Offset(1, 1),
                        duration: 400.ms,
                        curve: Curves.easeOutBack,
                      ),
                  const SizedBox(height: 20),
                  Text(
                    'No tenés reseñas pendientes',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReviewsList(
      BuildContext context, List<Map<String, dynamic>> reviews) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: reviews.length,
      itemBuilder: (context, index) {
        final item = reviews[index];
        return _ReviewCard(item: item)
            .animate()
            .fadeIn(
              delay: Duration(milliseconds: index * 80),
              duration: 350.ms,
            )
            .slideY(
              begin: 0.1,
              end: 0,
              delay: Duration(milliseconds: index * 80),
              duration: 350.ms,
              curve: Curves.easeOut,
            );
      },
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _ReviewCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final branchName = item['branch_name'] as String? ?? '';
    final barberName = item['barber_name'] as String? ?? '';
    final visitDate = item['visit_date'] as String? ?? '';
    final token = item['token'] as String? ?? '';

    return GestureDetector(
      onTap: () => context.push('/review/$token'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MonacoColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withOpacity(0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    branchName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Pendiente',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.content_cut_rounded,
                  size: 14,
                  color: Colors.white.withOpacity(0.4),
                ),
                const SizedBox(width: 6),
                Text(
                  barberName,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: Colors.white.withOpacity(0.4),
                ),
                const SizedBox(width: 6),
                Text(
                  visitDate.isNotEmpty
                      ? Formatters.date(DateTime.parse(visitDate))
                      : '',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
