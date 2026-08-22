import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/features/rewards/providers/rewards_provider.dart';

/// Billetera de premios del cliente (tab "Premios" del dock). Vive dentro del
/// shell: sin botón atrás y con padding inferior para el dock.
class RewardsScreen extends ConsumerStatefulWidget {
  const RewardsScreen({super.key});

  @override
  ConsumerState<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends ConsumerState<RewardsScreen> {
  int _selectedTab = 0;

  Future<void> _refresh() async {
    ref.invalidate(clientWalletProvider);
    await ref.read(clientWalletProvider.future).then((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(clientWalletProvider);

    return LiquidAppBarScaffold(
      title: 'Mis premios',
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: LiquidPill(
            onTap: () => context.push('/catalog'),
            tint: MonacoColors.monacoGreen,
            tintOpacity: 0.14,
            padding: const EdgeInsets.fromLTRB(12, 7, 10, 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.redeem_rounded, size: 15, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  'Canjear',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: LiquidSegmentedTabs(
              labels: const ['Disponibles', 'Usados'],
              selectedIndex: _selectedTab,
              onChange: (i) => setState(() => _selectedTab = i),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: RefreshIndicator(
              color: Colors.white,
              backgroundColor: MonacoColors.surface,
              onRefresh: _refresh,
              child: walletAsync.when(
                loading: () => const LiquidSkeletonList(
                  count: 4,
                  itemHeight: 132,
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 120),
                ),
                error: (e, _) => LiquidErrorState(error: e, onRetry: _refresh),
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
                            emptyIcon: Icons.card_giftcard_rounded,
                            emptyTitle: 'Todavía no tenés premios',
                            emptyMessage:
                                'Sumá puntos con cada visita y canjealos por premios del catálogo.',
                            emptyCtaLabel: 'Ver catálogo',
                            onEmptyCta: () => context.push('/catalog'),
                          )
                        : _RewardsList(
                            key: const ValueKey('used'),
                            rewards: used,
                            emptyIcon: Icons.history_rounded,
                            emptyTitle: 'Sin premios usados',
                            emptyMessage:
                                'Acá van a quedar los premios que ya canjeaste o que vencieron.',
                          ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardsList extends StatelessWidget {
  final List<Map<String, dynamic>> rewards;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;
  final String? emptyCtaLabel;
  final VoidCallback? onEmptyCta;

  const _RewardsList({
    super.key,
    required this.rewards,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyMessage,
    this.emptyCtaLabel,
    this.onEmptyCta,
  });

  @override
  Widget build(BuildContext context) {
    if (rewards.isEmpty) {
      return LiquidEmptyState(
        icon: emptyIcon,
        title: emptyTitle,
        message: emptyMessage,
        ctaLabel: emptyCtaLabel,
        onCta: onEmptyCta,
        padding: const EdgeInsets.fromLTRB(32, 56, 32, 120),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
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

  static String _typeLabel(String type) {
    switch (type) {
      case 'free_service':
        return 'Servicio gratis';
      case 'discount':
        return 'Descuento';
      case 'points_redemption':
        return 'Canje por puntos';
      case 'product':
        return 'Producto';
      default:
        return type.replaceAll('_', ' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = reward['reward_name'] as String? ?? 'Premio';
    final description = (reward['reward_description'] as String?)?.trim();
    final type = reward['reward_type']?.toString() ?? '';
    final status = reward['status'] as String? ?? 'available';
    final clientRewardId = reward['client_reward_id']?.toString() ?? '';
    final expiresRaw = reward['expires_at'] as String?;
    final expiresAt =
        expiresRaw != null ? DateTime.tryParse(expiresRaw)?.toLocal() : null;

    final isAvailable = status == 'available';
    final isExpired = status == 'expired';

    final Color accent;
    final String badgeLabel;
    if (isAvailable) {
      accent = MonacoColors.monacoGreen;
      badgeLabel = 'Disponible';
    } else if (isExpired) {
      accent = MonacoColors.destructive;
      badgeLabel = 'Vencido';
    } else {
      accent = Colors.white.withValues(alpha: 0.5);
      badgeLabel = 'Canjeado';
    }

    String? expiresLabel;
    if (expiresAt != null && isAvailable) {
      final days = expiresAt.difference(DateTime.now()).inDays;
      expiresLabel = days <= 0
          ? 'Vence hoy'
          : 'Vence el ${DateFormat("d 'de' MMM", 'es').format(expiresAt)}';
    }

    return LiquidGlass(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      tint: isAvailable ? MonacoColors.monacoGreen : null,
      tintOpacity: isAvailable ? 0.06 : 0.04,
      pressable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withValues(alpha: 0.26),
                      accent.withValues(alpha: 0.08),
                    ],
                  ),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.34),
                    width: 0.8,
                  ),
                ),
                child: Icon(Icons.card_giftcard_rounded, size: 18, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: MonacoColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (description != null && description.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
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
          if (type.isNotEmpty || expiresLabel != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (type.isNotEmpty)
                  _MetaChip(
                    icon: Icons.sell_outlined,
                    label: _typeLabel(type),
                  ),
                if (expiresLabel != null)
                  _MetaChip(
                    icon: Icons.schedule_rounded,
                    label: expiresLabel,
                  ),
              ],
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

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.14),
            Colors.white.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 0.6,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white.withValues(alpha: 0.7)),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
