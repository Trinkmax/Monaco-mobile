import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/features/rewards/providers/rewards_provider.dart';

/// **Mis premios** — la billetera completa: lo que está listo para usar y lo
/// que ya se usó o venció.
///
/// Es la pantalla que antes ocupaba el tab `/rewards`. Ahora el tab lo ocupa la
/// tienda (`PremiosScreen`), que muestra arriba una tira con los premios listos;
/// esta es el "ver todos" de esa tira y el lugar donde queda el historial.
class MisPremiosScreen extends ConsumerStatefulWidget {
  const MisPremiosScreen({super.key});

  @override
  ConsumerState<MisPremiosScreen> createState() => _MisPremiosScreenState();
}

class _MisPremiosScreenState extends ConsumerState<MisPremiosScreen> {
  int _tab = 0;

  Future<void> _refresh() async {
    ref.invalidate(clientWalletProvider);
    await ref.read(clientWalletProvider.future).then((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(clientWalletProvider);

    return LiquidAppBarScaffold(
      title: 'Mis premios',
      showBackButton: true,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: LiquidSegmentedTabs(
              labels: const ['Para usar', 'Usados'],
              selectedIndex: _tab,
              onChange: (i) => setState(() => _tab = i),
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
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 48),
                ),
                error: (e, _) => LiquidErrorState(error: e, onRetry: _refresh),
                data: (rewards) {
                  final disponibles =
                      rewards.where((r) => r['status'] == 'available').toList();
                  final usados = rewards
                      .where((r) =>
                          r['status'] == 'redeemed' || r['status'] == 'expired')
                      .toList();

                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _tab == 0
                        ? _Lista(
                            key: const ValueKey('disponibles'),
                            rewards: disponibles,
                            emptyIcon: Icons.card_giftcard_rounded,
                            emptyTitle: 'Todavía no tenés premios',
                            emptyMessage:
                                'Sumá puntos con cada visita y canjealos por premios del catálogo.',
                            emptyCtaLabel: 'Ver premios',
                            onEmptyCta: () => context.go('/rewards'),
                          )
                        : _Lista(
                            key: const ValueKey('usados'),
                            rewards: usados,
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

class _Lista extends StatelessWidget {
  final List<Map<String, dynamic>> rewards;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;
  final String? emptyCtaLabel;
  final VoidCallback? onEmptyCta;

  const _Lista({
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
        padding: const EdgeInsets.fromLTRB(32, 56, 32, 48),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 48),
      itemCount: rewards.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) =>
          _RewardCard(reward: rewards[i]).liquidEnter(index: i),
    );
  }
}

class _RewardCard extends StatelessWidget {
  final Map<String, dynamic> reward;

  const _RewardCard({required this.reward});

  /// Qué ES el premio, en criollo.
  ///
  /// Antes se traducía `reward_type` con cuatro casos —`free_service`,
  /// `discount`, `points_redemption`, `product`— de los cuales **tres no existen
  /// en el enum** de la base (`spin_prize | return_discount | milestone_free |
  /// manual | points_redemption`), así que la pantalla imprimía "spin prize" y
  /// "milestone free" tal cual. Ahora manda lo que el premio hace, y el tipo
  /// sólo desempata.
  static String _etiqueta(Map<String, dynamic> r) {
    if (r['is_free_service'] == true) return 'Servicio gratis';
    final pct = (r['discount_pct'] as num?)?.toInt() ?? 0;
    if (pct > 0) return '$pct% de descuento';
    switch (r['reward_type']?.toString() ?? '') {
      case 'points_redemption':
        return 'Canje por puntos';
      case 'return_discount':
        return 'Descuento de bienvenida';
      case 'milestone_free':
        return 'Premio por fidelidad';
      case 'spin_prize':
        return 'Premio de la ruleta';
      case 'manual':
        return 'Premio especial';
      default:
        return 'Premio';
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = reward['reward_name'] as String? ?? 'Premio';
    final description = (reward['reward_description'] as String?)?.trim();
    final status = reward['status'] as String? ?? 'available';
    final clientRewardId = reward['client_reward_id']?.toString() ?? '';
    final expiresRaw = reward['expires_at'] as String?;
    final expiresAt =
        expiresRaw != null ? DateTime.tryParse(expiresRaw)?.toLocal() : null;

    final disponible = status == 'available';
    final vencido = status == 'expired';

    final Color accent;
    final String badge;
    if (disponible) {
      accent = MonacoColors.monacoGreen;
      badge = 'Listo para usar';
    } else if (vencido) {
      accent = MonacoColors.destructive;
      badge = 'Vencido';
    } else {
      accent = Colors.white.withValues(alpha: 0.5);
      badge = 'Usado';
    }

    String? vence;
    if (expiresAt != null && disponible) {
      final dias = expiresAt.difference(DateTime.now()).inDays;
      vence = dias <= 0
          ? 'Vence hoy'
          : 'Vence el ${DateFormat("d 'de' MMM", 'es').format(expiresAt)}';
    }

    return LiquidGlass(
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      tint: disponible ? MonacoColors.monacoGreen : null,
      tintOpacity: disponible ? 0.07 : 0.04,
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
                child: Icon(
                  reward['is_free_service'] == true
                      ? Icons.content_cut_rounded
                      : Icons.card_giftcard_rounded,
                  size: 18,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MonacoColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
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
                label: badge,
                color: accent,
                pulse: disponible,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _MetaChip(icon: Icons.sell_outlined, label: _etiqueta(reward)),
              if (vence != null)
                _MetaChip(icon: Icons.schedule_rounded, label: vence),
            ],
          ),
          if (disponible) ...[
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
                    'Mostrar código',
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 0.6),
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
