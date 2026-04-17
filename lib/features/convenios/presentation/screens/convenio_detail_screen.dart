import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/features/convenios/presentation/widgets/redemption_card.dart';
import 'package:monaco_mobile/features/convenios/providers/convenios_provider.dart';
import 'package:monaco_mobile/features/convenios/providers/my_redemptions_provider.dart';
import 'package:monaco_mobile/features/convenios/providers/redemption_provider.dart';

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

  @override
  Widget build(BuildContext context) {
    final asyncBenefit = ref.watch(conveniosDetailProvider(widget.id));

    return Scaffold(
      backgroundColor: MonacoColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 18),
            onPressed: () => context.pop(),
          ),
        ),
      ),
      body: asyncBenefit.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: MonacoColors.gold),
        ),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: Colors.white70)),
        ),
        data: (benefit) {
          if (benefit == null) return _notFound(context);
          return _DetailContent(benefit: benefit);
        },
      ),
    );
  }

  Widget _notFound(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded,
                size: 72, color: MonacoColors.foregroundSubtle),
            const SizedBox(height: 12),
            const Text(
              'Este convenio ya no está disponible',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: MonacoColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Volver',
                  style: TextStyle(color: MonacoColors.gold)),
            ),
          ],
        ),
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

  @override
  Widget build(BuildContext context) {
    final title = benefit['title'] as String? ?? '';
    final description = benefit['description'] as String?;
    final discount = benefit['discount_text'] as String?;
    final imageUrl = benefit['image_url'] as String?;
    final terms = benefit['terms'] as String?;
    final address = benefit['location_address'] as String?;
    final mapUrl = benefit['location_map_url'] as String?;
    final validFrom = benefit['valid_from'] as String?;
    final validUntil = benefit['valid_until'] as String?;
    final partner = benefit['partner'] as Map<String, dynamic>?;
    final partnerName = partner?['business_name'] as String? ?? '';
    final partnerLogo = partner?['logo_url'] as String?;
    final benefitId = benefit['id'] as String;

    String fmtDate(String iso) => DateFormat("d 'de' MMM y", 'es')
        .format(DateTime.parse(iso).toLocal());

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------- Hero image ----------
          SizedBox(
            height: 280,
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
                    errorWidget: (_, __, ___) =>
                        Container(color: MonacoColors.surfaceVariant),
                  )
                else
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [MonacoColors.surface, MonacoColors.background],
                      ),
                    ),
                    child: const Icon(Icons.local_offer_outlined,
                        size: 72, color: MonacoColors.foregroundSubtle),
                  ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.3),
                        Colors.transparent,
                        Colors.black.withOpacity(0.2),
                        MonacoColors.background,
                      ],
                      stops: const [0.0, 0.3, 0.7, 1.0],
                    ),
                  ),
                ),
                if (discount != null && discount.isNotEmpty)
                  Positioned(
                    left: 20,
                    bottom: 28,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: MonacoColors.primary,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        discount,
                        style: const TextStyle(
                          color: MonacoColors.primaryForeground,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
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

          // ---------- Body ----------
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: MonacoColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.03),
                if (partnerName.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: MonacoColors.surfaceVariant,
                        backgroundImage:
                            (partnerLogo != null && partnerLogo.isNotEmpty)
                                ? CachedNetworkImageProvider(partnerLogo)
                                : null,
                        child: (partnerLogo == null || partnerLogo.isEmpty)
                            ? Text(
                                partnerName.substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                  color: MonacoColors.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          partnerName,
                          style: const TextStyle(
                            color: MonacoColors.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 24),

                // ---------- Tarjeta de canje (multi-estado) ----------
                RedemptionCard(
                  benefitId: benefitId,
                  benefitTitle: title,
                  partnerName: partnerName.isNotEmpty ? partnerName : null,
                  isOutOfWindow: _isOutOfWindow,
                )
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 400.ms)
                    .slideY(begin: 0.05, end: 0),

                const SizedBox(height: 24),

                if (description != null && description.isNotEmpty) ...[
                  _SectionTitle('Descripción'),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(
                      color: MonacoColors.textSecondary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                if (terms != null && terms.isNotEmpty) ...[
                  _SectionTitle('Términos y condiciones'),
                  const SizedBox(height: 8),
                  Text(
                    terms,
                    style: const TextStyle(
                      color: MonacoColors.textSecondary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // ---------- Validez ----------
                if (validFrom != null || validUntil != null)
                  _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    text: [
                      if (validFrom != null) 'Desde ${fmtDate(validFrom)}',
                      if (validUntil != null) 'Hasta ${fmtDate(validUntil)}',
                    ].join(' · '),
                  ),

                // ---------- Dirección ----------
                if (address != null && address.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: InkWell(
                      onTap: () async {
                        final url = mapUrl ??
                            'https://maps.google.com/?q=${Uri.encodeComponent(address)}';
                        final uri = Uri.parse(url);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                      child: _InfoRow(
                        icon: Icons.place_outlined,
                        text: address,
                        trailing: const Icon(Icons.open_in_new,
                            color: MonacoColors.gold, size: 14),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: MonacoColors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? trailing;
  const _InfoRow({required this.icon, required this.text, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: MonacoColors.foregroundSubtle),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: MonacoColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
  }
}
