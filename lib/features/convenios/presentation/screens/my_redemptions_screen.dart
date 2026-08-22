import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/features/convenios/presentation/widgets/redemption_status_chip.dart';
import 'package:monaco_mobile/features/convenios/providers/my_redemptions_provider.dart';

/// Historial de códigos de convenio activados por el cliente.
class MyRedemptionsScreen extends ConsumerWidget {
  const MyRedemptionsScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(myRedemptionsProvider);
    await ref.read(myRedemptionsProvider.future).then((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myRedemptionsProvider);

    return LiquidAppBarScaffold(
      title: 'Mis canjes',
      showBackButton: true,
      body: RefreshIndicator(
        color: Colors.white,
        backgroundColor: MonacoColors.surface,
        onRefresh: () => _refresh(ref),
        child: async.when(
          loading: () => const LiquidSkeletonList(
            count: 5,
            itemHeight: 104,
            padding: EdgeInsets.fromLTRB(20, 12, 20, 48),
          ),
          error: (e, _) => LiquidErrorState(
            error: e,
            onRetry: () => _refresh(ref),
          ),
          data: (items) {
            if (items.isEmpty) {
              return LiquidEmptyState(
                icon: Icons.confirmation_number_outlined,
                title: 'Todavía no canjeaste ningún convenio',
                message:
                    'Explorá los beneficios disponibles y activá tu código para mostrarlo en el comercio.',
                ctaLabel: 'Ver convenios',
                onCta: () => context.push('/convenios'),
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final r = items[i];
                return _RedemptionTile(
                  item: r,
                  onTap: () => context.push('/convenio/${r['benefit_id']}'),
                ).liquidEnter(index: i);
              },
            );
          },
        ),
      ),
    );
  }
}

class _RedemptionTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const _RedemptionTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = item['benefit_title'] as String? ?? '';
    final imageUrl = (item['benefit_image_url'] as String?)?.trim();
    final discountText = (item['benefit_discount_text'] as String?)?.trim();
    final validUntilStr = item['benefit_valid_until'] as String?;
    final partnerName = item['partner_name'] as String? ?? '';
    final partnerLogo = item['partner_logo_url'] as String?;
    final status = item['status'] as String? ?? 'issued';
    final code = item['code'] as String? ?? '';
    final createdStr = item['created_at'] as String?;

    final validUntil =
        validUntilStr != null ? DateTime.tryParse(validUntilStr) : null;
    final created = createdStr != null ? DateTime.tryParse(createdStr) : null;
    final createdFmt = created != null
        ? DateFormat('d MMM y', 'es').format(created.toLocal())
        : '';

    final isUsed = status == 'used';

    return Semantics(
      button: true,
      label: 'Canje $title, estado $status',
      child: LiquidGlass(
        onTap: onTap,
        padding: const EdgeInsets.all(10),
        borderRadius: 20,
        tintOpacity: isUsed ? 0.045 : 0.07,
        showVignette: false,
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 84,
                height: 84,
                child: _Thumb(imageUrl: imageUrl),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: MonacoColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            height: 1.25,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      RedemptionStatusChip(
                        redemptionStatus: status,
                        validUntil: validUntil,
                        showActive: true,
                      ),
                    ],
                  ),
                  if (partnerName.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        LiquidAvatar(
                          imageUrl: partnerLogo,
                          name: partnerName,
                          size: 16,
                          ring: false,
                          fallbackIcon: Icons.storefront_rounded,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            partnerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      if (discountText != null && discountText.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            gradient: LinearGradient(
                              colors: [
                                MonacoColors.monacoGreen.withValues(alpha: 0.28),
                                MonacoColors.monacoGreen.withValues(alpha: 0.12),
                              ],
                            ),
                            border: Border.all(
                              color: MonacoColors.monacoGreen.withValues(alpha: 0.4),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            discountText,
                            style: const TextStyle(
                              color: MonacoColors.monacoGreen,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (code.isNotEmpty)
                        Flexible(
                          child: Text(
                            code,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 11.5,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      const Spacer(),
                      if (createdFmt.isNotEmpty)
                        Text(
                          createdFmt,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.35),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String? imageUrl;
  const _Thumb({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.12),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.local_offer_outlined,
          color: Colors.white.withValues(alpha: 0.45),
          size: 26,
        ),
      ),
    );
    if (imageUrl == null || imageUrl!.isEmpty) return fallback;
    return CachedNetworkImage(
      imageUrl: imageUrl!,
      fit: BoxFit.cover,
      placeholder: (_, _) => fallback,
      errorWidget: (_, _, _) => fallback,
    );
  }
}
