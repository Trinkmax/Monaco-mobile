import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/features/convenios/presentation/widgets/redemption_card.dart';
import 'package:monaco_mobile/features/convenios/providers/convenios_provider.dart';
import 'package:monaco_mobile/features/convenios/providers/my_redemptions_provider.dart';
import 'package:monaco_mobile/features/convenios/providers/redemption_provider.dart';

/// Detalle de un convenio: imagen hero detrás del app bar, tarjeta de canje
/// (activar / QR / usado) y la letra chica en láminas de vidrio.
class ConvenioDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const ConvenioDetailScreen({super.key, required this.id});

  @override
  ConsumerState<ConvenioDetailScreen> createState() =>
      _ConvenioDetailScreenState();
}

class _ConvenioDetailScreenState extends ConsumerState<ConvenioDetailScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Si el usuario vuelve a la app tras mostrar el código al comercio,
    // refrescamos el estado por si la validación ya ocurrió (status='used').
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(existingRedemptionProvider(widget.id));
      ref.invalidate(redemptionProvider(widget.id));
      ref.invalidate(myRedemptionsProvider);
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(conveniosDetailProvider(widget.id));
    ref.invalidate(existingRedemptionProvider(widget.id));
    ref.invalidate(myRedemptionsProvider);
    await ref
        .read(conveniosDetailProvider(widget.id).future)
        .then((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final asyncBenefit = ref.watch(conveniosDetailProvider(widget.id));
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;

    final title = asyncBenefit.maybeWhen(
      data: (b) {
        final partner = b?['partner'] as Map<String, dynamic>?;
        final name = partner?['business_name'] as String?;
        return (name != null && name.trim().isNotEmpty) ? name : 'Convenio';
      },
      orElse: () => 'Convenio',
    );

    return LiquidAppBarScaffold(
      title: title,
      showBackButton: true,
      extendBodyBehindAppBar: true,
      body: asyncBenefit.when(
        loading: () => _DetailSkeleton(topInset: topInset),
        error: (e, _) => Padding(
          padding: EdgeInsets.only(top: topInset),
          child: LiquidErrorState(error: e, onRetry: _refresh),
        ),
        data: (benefit) {
          if (benefit == null) {
            return Padding(
              padding: EdgeInsets.only(top: topInset),
              child: LiquidEmptyState(
                icon: Icons.search_off_rounded,
                title: 'Este convenio ya no está disponible',
                message:
                    'Puede que haya vencido o que el comercio lo haya pausado.',
                ctaLabel: 'Volver',
                onCta: () => context.pop(),
              ),
            );
          }
          return RefreshIndicator(
            color: Colors.white,
            backgroundColor: MonacoColors.surface,
            edgeOffset: topInset,
            onRefresh: _refresh,
            child: _DetailContent(benefit: benefit),
          );
        },
      ),
    );
  }
}

class _DetailContent extends StatelessWidget {
  final Map<String, dynamic> benefit;
  const _DetailContent({required this.benefit});

  bool get _isOutOfWindow {
    final now = DateTime.now();
    final from = benefit['valid_from'] as String?;
    final until = benefit['valid_until'] as String?;
    if (from != null) {
      final d = DateTime.tryParse(from);
      if (d != null && d.isAfter(now)) return true;
    }
    if (until != null) {
      final d = DateTime.tryParse(until);
      if (d != null && d.isBefore(now)) return true;
    }
    return false;
  }

  Future<void> _openMaps(BuildContext context, String address, String? mapUrl) async {
    final url = (mapUrl != null && mapUrl.trim().isNotEmpty)
        ? mapUrl.trim()
        : 'https://maps.google.com/?q=${Uri.encodeComponent(address)}';
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!context.mounted) return;
      showLiquidToast(
        context,
        'No pudimos abrir el mapa.',
        tone: LiquidToastTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = benefit['title'] as String? ?? '';
    final description = (benefit['description'] as String?)?.trim();
    final discount = (benefit['discount_text'] as String?)?.trim();
    final imageUrl = (benefit['image_url'] as String?)?.trim();
    final terms = (benefit['terms'] as String?)?.trim();
    final address = (benefit['location_address'] as String?)?.trim();
    final mapUrl = benefit['location_map_url'] as String?;
    final validFrom = benefit['valid_from'] as String?;
    final validUntil = benefit['valid_until'] as String?;
    final partner = benefit['partner'] as Map<String, dynamic>?;
    final partnerName = partner?['business_name'] as String? ?? '';
    final partnerLogo = partner?['logo_url'] as String?;
    final benefitId = benefit['id'] as String;

    String fmtDate(String iso) {
      final d = DateTime.tryParse(iso);
      if (d == null) return '';
      return DateFormat("d 'de' MMM y", 'es').format(d.toLocal());
    }

    final validity = [
      if (validFrom != null && fmtDate(validFrom).isNotEmpty)
        'Desde ${fmtDate(validFrom)}',
      if (validUntil != null && fmtDate(validUntil).isNotEmpty)
        'Hasta ${fmtDate(validUntil)}',
    ].join(' · ');

    var enterIndex = 0;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hero ──
          SizedBox(
            height: 320,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imageUrl != null && imageUrl.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => const ColoredBox(
                      color: MonacoColors.surfaceVariant,
                    ),
                    errorWidget: (_, _, _) => const _HeroFallback(),
                  )
                else
                  const _HeroFallback(),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.45),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.25),
                        MonacoColors.background,
                      ],
                      stops: const [0.0, 0.35, 0.72, 1.0],
                    ),
                  ),
                ),
                if (discount != null && discount.isNotEmpty)
                  Positioned(
                    left: 20,
                    bottom: 26,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            MonacoColors.monacoGreen,
                            MonacoColors.monacoGreenDeep,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: MonacoColors.monacoGreen.withValues(alpha: 0.45),
                            blurRadius: 18,
                            spreadRadius: -2,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Text(
                        discount,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          letterSpacing: -0.2,
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.2, end: 0),
                  ),
              ],
            ),
          ),

          // ── Cuerpo ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: MonacoColors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                    height: 1.15,
                  ),
                ).liquidEnter(index: enterIndex++),
                if (partnerName.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      LiquidAvatar(
                        imageUrl: partnerLogo,
                        name: partnerName,
                        size: 32,
                        fallbackIcon: Icons.storefront_rounded,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          partnerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ).liquidEnter(index: enterIndex++),
                ],
                const SizedBox(height: 22),

                // ── Tarjeta de canje (multi-estado) ──
                RedemptionCard(
                  benefitId: benefitId,
                  benefitTitle: title,
                  partnerName: partnerName.isNotEmpty ? partnerName : null,
                  isOutOfWindow: _isOutOfWindow,
                ).liquidEnter(index: enterIndex++),
                const SizedBox(height: 22),

                if (description != null && description.isNotEmpty) ...[
                  _GlassSection(
                    icon: Icons.notes_rounded,
                    title: 'Descripción',
                    body: description,
                  ).liquidEnter(index: enterIndex++),
                  const SizedBox(height: 12),
                ],
                if (terms != null && terms.isNotEmpty) ...[
                  _GlassSection(
                    icon: Icons.gavel_rounded,
                    title: 'Términos y condiciones',
                    body: terms,
                    small: true,
                  ).liquidEnter(index: enterIndex++),
                  const SizedBox(height: 12),
                ],
                if (validity.isNotEmpty) ...[
                  _InfoTile(
                    icon: Icons.calendar_today_rounded,
                    label: 'Vigencia',
                    text: validity,
                  ).liquidEnter(index: enterIndex++),
                  const SizedBox(height: 10),
                ],
                if (address != null && address.isNotEmpty)
                  _InfoTile(
                    icon: Icons.place_rounded,
                    label: 'Dónde',
                    text: address,
                    onTap: () => _openMaps(context, address, mapUrl),
                  ).liquidEnter(index: enterIndex++),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroFallback extends StatelessWidget {
  const _HeroFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MonacoColors.monacoGreen.withValues(alpha: 0.22),
            MonacoColors.background,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.local_offer_rounded,
          size: 80,
          color: Colors.white.withValues(alpha: 0.18),
        ),
      ),
    );
  }
}

class _GlassSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final bool small;

  const _GlassSection({
    required this.icon,
    required this.title,
    required this.body,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      borderRadius: 20,
      tintOpacity: 0.06,
      pressable: false,
      showVignette: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.7)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: MonacoColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              color: Colors.white.withValues(alpha: small ? 0.55 : 0.68),
              fontSize: small ? 12.5 : 14,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String text;
  final VoidCallback? onTap;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.text,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderRadius: 16,
      tintOpacity: 0.05,
      pressable: onTap != null,
      showVignette: false,
      blur: LiquidTokens.blurSubtle,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.18),
                  Colors.white.withValues(alpha: 0.06),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 0.8,
              ),
            ),
            child: Icon(icon, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.open_in_new_rounded,
              size: 16,
              color: MonacoColors.monacoGreen.withValues(alpha: 0.95),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  final double topInset;
  const _DetailSkeleton({required this.topInset});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 48),
      children: const [
        LiquidSkeleton(height: 220, radius: 28),
        SizedBox(height: 22),
        LiquidSkeleton.line(width: 240, height: 24),
        SizedBox(height: 12),
        LiquidSkeleton.line(width: 140, height: 16),
        SizedBox(height: 22),
        LiquidSkeleton(height: 210, radius: 24),
        SizedBox(height: 14),
        LiquidSkeleton(height: 110, radius: 20),
      ],
    );
  }
}
