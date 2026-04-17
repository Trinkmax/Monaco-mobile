import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/features/convenios/presentation/widgets/redemption_status_chip.dart';
import 'package:monaco_mobile/features/convenios/providers/my_redemptions_provider.dart';

class MyRedemptionsScreen extends ConsumerWidget {
  const MyRedemptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myRedemptionsProvider);

    return Scaffold(
      backgroundColor: MonacoColors.background,
      appBar: AppBar(
        backgroundColor: MonacoColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: MonacoColors.foreground, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Mis canjes',
          style: TextStyle(
            color: MonacoColors.foreground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: MonacoColors.gold,
        backgroundColor: MonacoColors.surface,
        onRefresh: () async => ref.invalidate(myRedemptionsProvider),
        child: async.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: MonacoColors.gold),
          ),
          error: (e, _) => _ErrorState(
            onRetry: () => ref.invalidate(myRedemptionsProvider),
          ),
          data: (items) {
            if (items.isEmpty) return const _EmptyState();
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final r = items[i];
                return _RedemptionTile(item: r)
                    .animate()
                    .fadeIn(
                      delay: Duration(milliseconds: 50 * i),
                      duration: 300.ms,
                    )
                    .slideY(begin: 0.06, end: 0);
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

  const _RedemptionTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final benefitId = item['benefit_id']?.toString() ?? '';
    final title = item['benefit_title'] as String? ?? '';
    final imageUrl = item['benefit_image_url'] as String?;
    final discountText = item['benefit_discount_text'] as String?;
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
        ? DateFormat("d MMM y", 'es').format(created.toLocal())
        : '';

    return Semantics(
      button: true,
      label: 'Canje $title, estado $status',
      child: InkWell(
        onTap: () => context.push('/convenio/$benefitId'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: MonacoColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MonacoColors.border),
          ),
          child: Row(
            children: [
              // Thumbnail
              SizedBox(
                width: 92,
                height: 92,
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
                            color: MonacoColors.foregroundSubtle, size: 26),
                      ),
                  ],
                ),
              ),
              // Body
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
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
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (partnerLogo != null && partnerLogo.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: partnerLogo,
                                    width: 14,
                                    height: 14,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => const Icon(
                                      Icons.storefront_outlined,
                                      size: 12,
                                      color: MonacoColors.foregroundSubtle,
                                    ),
                                  ),
                                ),
                              )
                            else
                              const Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Icon(Icons.storefront_outlined,
                                    size: 12,
                                    color: MonacoColors.foregroundSubtle),
                              ),
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
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (discountText != null && discountText.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: MonacoColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(4),
                                border:
                                    Border.all(color: MonacoColors.border),
                              ),
                              child: Text(
                                discountText,
                                style: const TextStyle(
                                  color: MonacoColors.textPrimary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          if (discountText != null &&
                              discountText.isNotEmpty &&
                              code.isNotEmpty)
                            const SizedBox(width: 6),
                          if (code.isNotEmpty)
                            Text(
                              'Código $code',
                              style: const TextStyle(
                                color: MonacoColors.foregroundSubtle,
                                fontSize: 11,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                              ),
                            ),
                          const Spacer(),
                          if (createdFmt.isNotEmpty)
                            Text(
                              createdFmt,
                              style: const TextStyle(
                                color: MonacoColors.foregroundSubtle,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.chevron_right,
                    color: MonacoColors.foregroundSubtle, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 100),
      children: [
        Icon(Icons.confirmation_number_outlined,
            size: 72, color: MonacoColors.gold.withOpacity(0.4)),
        const SizedBox(height: 16),
        const Text(
          'Todavía no canjeaste ningún convenio',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: MonacoColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Explorá los beneficios disponibles para tu barbería y activá tu código.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: MonacoColors.textSecondary,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: TextButton.icon(
            onPressed: () => context.push('/convenios'),
            icon: const Icon(Icons.local_offer_outlined,
                color: MonacoColors.gold),
            label: const Text('Ver convenios',
                style: TextStyle(
                  color: MonacoColors.gold,
                  fontWeight: FontWeight.w700,
                )),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline,
              size: 56, color: MonacoColors.destructive),
          const SizedBox(height: 12),
          const Text(
            'No pudimos cargar tus canjes',
            style: TextStyle(color: MonacoColors.textPrimary, fontSize: 15),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            child: const Text('Reintentar',
                style: TextStyle(color: MonacoColors.gold)),
          ),
        ],
      ),
    );
  }
}
