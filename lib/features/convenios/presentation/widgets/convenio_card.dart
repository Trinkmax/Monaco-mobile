import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/features/convenios/presentation/widgets/redemption_status_chip.dart';
import 'package:monaco_mobile/features/convenios/providers/my_redemptions_provider.dart';

DateTime? _parseValidUntil(Map<String, dynamic> benefit) {
  final raw = benefit['valid_until'] as String?;
  if (raw == null) return null;
  return DateTime.tryParse(raw);
}

String? _redemptionStatusFor(
  Map<String, dynamic> benefit,
  WidgetRef ref,
) {
  final id = benefit['id']?.toString();
  if (id == null) return null;
  final map = ref.watch(myBenefitRedemptionsMapProvider).valueOrNull;
  if (map == null) return null;
  final row = map[id];
  return row?['status']?.toString();
}

/// Card horizontal para carrusel del home.
class ConvenioHomeCard extends ConsumerWidget {
  final Map<String, dynamic> benefit;
  final VoidCallback onTap;

  const ConvenioHomeCard({
    super.key,
    required this.benefit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = benefit['title'] as String? ?? '';
    final imageUrl = benefit['image_url'] as String?;
    final discount = benefit['discount_text'] as String?;
    final partner = benefit['partner'] as Map<String, dynamic>?;
    final partnerName = partner?['business_name'] as String? ?? '';

    final redemptionStatus = _redemptionStatusFor(benefit, ref);
    final validUntil = _parseValidUntil(benefit);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: MonacoColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MonacoColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            SizedBox(
              height: 120,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageUrl != null && imageUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: MonacoColors.surfaceVariant),
                      errorWidget: (_, __, ___) => Container(
                        color: MonacoColors.surfaceVariant,
                        child: const Icon(Icons.image_not_supported_outlined,
                            color: MonacoColors.foregroundSubtle, size: 28),
                      ),
                    )
                  else
                    Container(
                      color: MonacoColors.surfaceVariant,
                      child: const Icon(Icons.local_offer_outlined,
                          color: MonacoColors.foregroundSubtle, size: 32),
                    ),
                  if (discount != null && discount.isNotEmpty)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: MonacoColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          discount,
                          style: const TextStyle(
                            color: MonacoColors.primaryForeground,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: RedemptionStatusChip(
                      redemptionStatus: redemptionStatus,
                      validUntil: validUntil,
                    ),
                  ),
                ],
              ),
            ),
            // Texto
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: MonacoColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  if (partnerName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      partnerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MonacoColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card vertical para lista de convenios (pantalla completa).
class ConvenioListCard extends ConsumerWidget {
  final Map<String, dynamic> benefit;
  final VoidCallback onTap;

  const ConvenioListCard({
    super.key,
    required this.benefit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = benefit['title'] as String? ?? '';
    final imageUrl = benefit['image_url'] as String?;
    final discount = benefit['discount_text'] as String?;
    final partner = benefit['partner'] as Map<String, dynamic>?;
    final partnerName = partner?['business_name'] as String? ?? '';

    final redemptionStatus = _redemptionStatusFor(benefit, ref);
    final validUntil = _parseValidUntil(benefit);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: MonacoColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MonacoColors.border),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 110,
              height: 110,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageUrl != null && imageUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: MonacoColors.surfaceVariant),
                      errorWidget: (_, __, ___) => Container(
                        color: MonacoColors.surfaceVariant,
                        child: const Icon(Icons.image_not_supported_outlined,
                            color: MonacoColors.foregroundSubtle),
                      ),
                    )
                  else
                    Container(
                      color: MonacoColors.surfaceVariant,
                      child: const Icon(Icons.local_offer_outlined,
                          color: MonacoColors.foregroundSubtle, size: 28),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        if (discount != null && discount.isNotEmpty)
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: MonacoColors.primary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                discount,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: MonacoColors.primaryForeground,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                        const Spacer(),
                        RedemptionStatusChip(
                          redemptionStatus: redemptionStatus,
                          validUntil: validUntil,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MonacoColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    if (partnerName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.storefront_outlined,
                              size: 12, color: MonacoColors.foregroundSubtle),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              partnerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: MonacoColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
