import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
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

/// Pastilla verde con el descuento ("20% OFF", "2x1"…).
class _DiscountPill extends StatelessWidget {
  final String text;
  final double fontSize;
  const _DiscountPill({required this.text, this.fontSize = 12});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: fontSize * 0.85, vertical: 5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MonacoColors.monacoGreen, MonacoColors.monacoGreenDeep],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: MonacoColors.monacoGreen.withValues(alpha: 0.45),
            blurRadius: 12,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: fontSize,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

/// Imagen del beneficio con placeholder/fallback en vidrio.
class _BenefitImage extends StatelessWidget {
  final String? imageUrl;
  final double iconSize;
  const _BenefitImage({required this.imageUrl, this.iconSize = 28});

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
          size: iconSize,
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

/// Card horizontal para carrusel del home — lámina glass con imagen arriba.
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

    return LiquidGlass(
      onTap: onTap,
      width: 260,
      padding: EdgeInsets.zero,
      borderRadius: 22,
      tintOpacity: 0.06,
      showVignette: false,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 120,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _BenefitImage(imageUrl: imageUrl, iconSize: 32),
                  // Sombra superior para que el descuento se lea sobre la foto
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 46,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.35),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (discount != null && discount.isNotEmpty)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: _DiscountPill(text: discount),
                    ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: RedemptionStatusChip(
                      redemptionStatus: redemptionStatus,
                      validUntil: validUntil,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
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
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
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

/// Card horizontal para la lista de convenios (pantalla completa).
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

    return LiquidGlass(
      onTap: onTap,
      padding: const EdgeInsets.all(10),
      borderRadius: 20,
      tintOpacity: 0.07,
      showVignette: false,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 92,
              height: 92,
              child: _BenefitImage(imageUrl: imageUrl),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    if (discount != null && discount.isNotEmpty)
                      Flexible(child: _DiscountPill(text: discount, fontSize: 11)),
                    const Spacer(),
                    RedemptionStatusChip(
                      redemptionStatus: redemptionStatus,
                      validUntil: validUntil,
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MonacoColors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    height: 1.25,
                  ),
                ),
                if (partnerName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.storefront_rounded,
                          size: 12, color: Colors.white.withValues(alpha: 0.5)),
                      const SizedBox(width: 4),
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
    );
  }
}
