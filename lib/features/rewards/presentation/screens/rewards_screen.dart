import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/features/rewards/providers/rewards_provider.dart';

class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(clientWalletProvider);

    return Scaffold(
      backgroundColor: MonacoColors.background,
      appBar: AppBar(
        backgroundColor: MonacoColors.background,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: const Text(
          'Mis Premios',
          style: TextStyle(
            color: MonacoColors.foreground,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: MonacoColors.foreground, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: MonacoColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: MonacoColors.border),
              ),
              child: TabBar(
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: MonacoColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                labelColor: MonacoColors.background,
                unselectedLabelColor: MonacoColors.foregroundSubtle,
                labelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                dividerHeight: 0,
                tabs: const [
                  Tab(text: 'Disponibles'),
                  Tab(text: 'Usados'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: walletAsync.when(
                loading: () => _buildShimmerList(),
                error: (e, _) => Center(
                  child: Text(
                    'Error al cargar premios',
                    style: TextStyle(
                      color: MonacoColors.foregroundSubtle,
                      fontSize: 14,
                    ),
                  ),
                ),
                data: (rewards) {
                  final available = rewards
                      .where((r) => r['status'] == 'available')
                      .toList();
                  final used = rewards
                      .where((r) =>
                          r['status'] == 'redeemed' ||
                          r['status'] == 'expired')
                      .toList();

                  return TabBarView(
                    children: [
                      _RewardsList(rewards: available, emptyLabel: 'disponibles'),
                      _RewardsList(rewards: used, emptyLabel: 'usados'),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, index) {
        return Container(
          height: 110,
          decoration: BoxDecoration(
            color: MonacoColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: MonacoColors.border),
          ),
        )
            .animate(onPlay: (c) => c.repeat())
            .shimmer(
              duration: 1200.ms,
              color: MonacoColors.foregroundSubtle.withOpacity(0.08),
            );
      },
    );
  }
}

class _RewardsList extends StatelessWidget {
  final List<Map<String, dynamic>> rewards;
  final String emptyLabel;

  const _RewardsList({required this.rewards, required this.emptyLabel});

  @override
  Widget build(BuildContext context) {
    if (rewards.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.card_giftcard_rounded,
              color: MonacoColors.foregroundSubtle.withOpacity(0.4),
              size: 56,
            ),
            const SizedBox(height: 14),
            Text(
              'No tenés premios $emptyLabel',
              style: const TextStyle(
                color: MonacoColors.foregroundSubtle,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: rewards.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final reward = rewards[index];
        return _RewardCard(reward: reward)
            .animate()
            .fadeIn(duration: 350.ms, delay: (index * 60).ms)
            .slideY(begin: 0.06, end: 0, duration: 350.ms);
      },
    );
  }
}

class _RewardCard extends StatelessWidget {
  final Map<String, dynamic> reward;

  const _RewardCard({required this.reward});

  @override
  Widget build(BuildContext context) {
    final name = reward['reward_name'] as String? ?? 'Premio';
    final type = reward['reward_type'] as String? ?? '';
    final status = reward['status'] as String? ?? 'available';
    final clientRewardId = reward['client_reward_id']?.toString() ?? '';

    final isAvailable = status == 'available';
    final isExpired = status == 'expired';

    Color borderColor;
    Color badgeBg;
    Color badgeText;
    String badgeLabel;

    if (isAvailable) {
      borderColor = const Color(0xFFD4A843);
      badgeBg = const Color(0xFFD4A843).withOpacity(0.15);
      badgeText = const Color(0xFFD4A843);
      badgeLabel = 'Disponible';
    } else if (isExpired) {
      borderColor = MonacoColors.destructive.withOpacity(0.5);
      badgeBg = MonacoColors.destructive.withOpacity(0.1);
      badgeText = MonacoColors.destructive;
      badgeLabel = 'Expirado';
    } else {
      borderColor = MonacoColors.border;
      badgeBg = MonacoColors.foregroundSubtle.withOpacity(0.1);
      badgeText = MonacoColors.foregroundSubtle;
      badgeLabel = 'Canjeado';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MonacoColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: isAvailable ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: MonacoColors.foreground,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    color: badgeText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (type.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: MonacoColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                type,
                style: const TextStyle(
                  color: MonacoColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (isAvailable) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton(
                onPressed: () =>
                    context.push('/reward-qr/$clientRewardId'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MonacoColors.primary,
                  foregroundColor: MonacoColors.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Ver QR'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
