import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/features/rewards/providers/rewards_provider.dart';

class RewardsScreen extends ConsumerStatefulWidget {
  const RewardsScreen({super.key});

  @override
  ConsumerState<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends ConsumerState<RewardsScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(clientWalletProvider);

    return LiquidAppBarScaffold(
      title: 'Mis Premios',
      centerTitle: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: LiquidSegmentedTabs(
                labels: const ['Disponibles', 'Usados'],
                selectedIndex: _selectedTab,
                onChange: (i) => setState(() => _selectedTab = i),
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: walletAsync.when(
                loading: () => _shimmerList(),
                error: (e, _) => Center(
                  child: Text(
                    'Error al cargar premios',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
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

                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _selectedTab == 0
                        ? _RewardsList(
                            key: const ValueKey('available'),
                            rewards: available,
                            emptyLabel: 'disponibles',
                          )
                        : _RewardsList(
                            key: const ValueKey('used'),
                            rewards: used,
                            emptyLabel: 'usados',
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shimmerList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 140),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) {
        return Container(
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
        )
            .animate(onPlay: (c) => c.repeat())
            .shimmer(duration: 1200.ms, color: Colors.white10);
      },
    );
  }
}

class _RewardsList extends StatelessWidget {
  final List<Map<String, dynamic>> rewards;
  final String emptyLabel;

  const _RewardsList({
    super.key,
    required this.rewards,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (rewards.isEmpty) {
      return Center(
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
                    Colors.white.withOpacity(0.08),
                    Colors.white.withOpacity(0.02),
                  ],
                ),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Icon(
                Icons.card_giftcard_rounded,
                color: Colors.white.withOpacity(0.35),
                size: 36,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No tenés premios $emptyLabel',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 140),
      itemCount: rewards.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _RewardCard(reward: rewards[index]).liquidEnter(index: index);
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

    final Color accent;
    final String badgeLabel;
    if (isAvailable) {
      accent = LiquidTokens.monacoGreen;
      badgeLabel = 'Disponible';
    } else if (isExpired) {
      accent = MonacoColors.destructive;
      badgeLabel = 'Expirado';
    } else {
      accent = Colors.white.withOpacity(0.5);
      badgeLabel = 'Canjeado';
    }

    return LiquidGlass(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      tintOpacity: isAvailable ? 0.09 : 0.04,
      pressable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: MonacoColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              LiquidStatusPill(
                label: badgeLabel,
                color: accent,
                pulse: isAvailable,
                compact: true,
              ),
            ],
          ),
          if (type.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.14),
                    Colors.white.withOpacity(0.06),
                  ],
                ),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.white.withOpacity(0.18),
                  width: 0.6,
                ),
              ),
              child: Text(
                type,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.78),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (isAvailable) ...[
            const SizedBox(height: 14),
            LiquidButton(
              onPressed: () => context.push('/reward-qr/$clientRewardId'),
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.qr_code_rounded, size: 18, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Ver QR',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
