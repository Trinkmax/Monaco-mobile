import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/core/supabase/supabase_provider.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------
final billboardItemsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final res = await supabase
      .from('billboard_items')
      .select()
      .eq('is_active', true)
      .order('sort_order');
  return (res as List).map((e) => Map<String, dynamic>.from(e)).toList();
});

// ---------------------------------------------------------------------------
// Pantalla: carrusel a pantalla completa con leyenda en vidrio
// ---------------------------------------------------------------------------
class BillboardScreen extends ConsumerStatefulWidget {
  const BillboardScreen({super.key});

  @override
  ConsumerState<BillboardScreen> createState() => _BillboardScreenState();
}

class _BillboardScreenState extends ConsumerState<BillboardScreen> {
  static const _autoScrollEvery = Duration(seconds: 6);

  late final PageController _pageController;
  Timer? _autoScrollTimer;
  int _currentPage = 0;
  int _itemCount = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  void _scheduleAutoScroll(int itemCount) {
    _itemCount = itemCount;
    _autoScrollTimer?.cancel();
    if (itemCount <= 1) return;
    _autoScrollTimer = Timer.periodic(_autoScrollEvery, (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_currentPage + 1) % _itemCount;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(billboardItemsProvider);
    await ref.read(billboardItemsProvider.future).then((_) {}, onError: (_) {});
  }

  Future<void> _openLink(Map<String, dynamic> item) async {
    final linkType = item['link_type'] as String?;
    final linkValue = (item['link_value'] as String?)?.trim();
    if (linkType == null || linkValue == null || linkValue.isEmpty) return;

    switch (linkType) {
      case 'route':
        if (linkValue.startsWith('/')) context.push(linkValue);
        return;
      case 'branch':
        context.push('/branch/$linkValue');
        return;
      case 'url':
        final uri = Uri.tryParse(linkValue);
        if (uri == null) return;
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {
          if (!mounted) return;
          showLiquidToast(
            context,
            'No pudimos abrir el enlace.',
            tone: LiquidToastTone.error,
          );
        }
        return;
    }
  }

  static bool _hasLink(Map<String, dynamic> item) {
    final type = item['link_type'] as String?;
    final value = (item['link_value'] as String?)?.trim();
    return type != null && value != null && value.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final asyncItems = ref.watch(billboardItemsProvider);
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;

    return LiquidAppBarScaffold(
      title: 'Cartelera',
      showBackButton: true,
      extendBodyBehindAppBar: true,
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: _refresh,
          icon: Icon(
            Icons.refresh_rounded,
            color: Colors.white.withValues(alpha: 0.9),
            size: 22,
          ),
        ),
        const SizedBox(width: 4),
      ],
      body: asyncItems.when(
        loading: () => Padding(
          padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 40),
          child: const LiquidSkeleton(height: double.infinity, radius: 28),
        ),
        error: (e, _) => Padding(
          padding: EdgeInsets.only(top: topInset),
          child: RefreshIndicator(
            color: Colors.white,
            backgroundColor: MonacoColors.surface,
            onRefresh: _refresh,
            child: LiquidErrorState(error: e, onRetry: _refresh),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Padding(
              padding: EdgeInsets.only(top: topInset),
              child: RefreshIndicator(
                color: Colors.white,
                backgroundColor: MonacoColors.surface,
                onRefresh: _refresh,
                child: const LiquidEmptyState(
                  icon: Icons.campaign_outlined,
                  title: 'Sin novedades por ahora',
                  message:
                      'Cuando la barbería publique promos o avisos los vas a ver acá.',
                ),
              ),
            );
          }
          if (_itemCount != items.length) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _scheduleAutoScroll(items.length);
            });
          }
          return _buildCarousel(items);
        },
      ),
    );
  }

  Widget _buildCarousel(List<Map<String, dynamic>> items) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final current = items[_currentPage.clamp(0, items.length - 1)];

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: items.length,
          onPageChanged: (i) {
            setState(() => _currentPage = i);
            // Un swipe manual reinicia el temporizador para no pisar al usuario.
            _scheduleAutoScroll(items.length);
          },
          itemBuilder: (context, index) => _BillboardPage(item: items[index]),
        ),

        // Leyenda en vidrio + indicador
        Positioned(
          left: 20,
          right: 20,
          bottom: safeBottom + 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (items.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SmoothPageIndicator(
                        controller: _pageController,
                        count: items.length,
                        effect: ExpandingDotsEffect(
                          dotHeight: 6,
                          dotWidth: 6,
                          expansionFactor: 3.2,
                          spacing: 6,
                          activeDotColor: MonacoColors.monacoGreen,
                          dotColor: Colors.white.withValues(alpha: 0.28),
                        ),
                      ),
                    ],
                  ),
                ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.06),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: _CaptionCard(
                  key: ValueKey(current['id'] ?? _currentPage),
                  item: current,
                  index: _currentPage,
                  total: items.length,
                  onLink: _hasLink(current) ? () => _openLink(current) : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Página del carrusel (imagen a sangre + degradés)
// ---------------------------------------------------------------------------
class _BillboardPage extends StatelessWidget {
  const _BillboardPage({required this.item});

  final Map<String, dynamic> item;

  static Color? _parseHex(String? raw) {
    if (raw == null) return null;
    var hex = raw.trim().replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return null;
    final value = int.tryParse(hex, radix: 16);
    return value == null ? null : Color(value);
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = (item['image_url'] as String?)?.trim();
    final tint = _parseHex(item['bg_color'] as String?) ?? MonacoColors.deepBlue;

    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tint.withValues(alpha: 0.55),
            MonacoColors.background,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.campaign_rounded,
          size: 96,
          color: Colors.white.withValues(alpha: 0.18),
        ),
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        if (imageUrl != null && imageUrl.isNotEmpty)
          CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            placeholder: (_, _) => const LiquidSkeleton(
              height: double.infinity,
              radius: 0,
            ),
            errorWidget: (_, _, _) => fallback,
          )
        else
          fallback,

        // Degradé para legibilidad del app bar y la leyenda
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.3, 0.6, 1.0],
              colors: [
                Colors.black.withValues(alpha: 0.45),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.35),
                Colors.black.withValues(alpha: 0.88),
              ],
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ---------------------------------------------------------------------------
// Leyenda en vidrio
// ---------------------------------------------------------------------------
class _CaptionCard extends StatelessWidget {
  const _CaptionCard({
    super.key,
    required this.item,
    required this.index,
    required this.total,
    required this.onLink,
  });

  final Map<String, dynamic> item;
  final int index;
  final int total;
  final VoidCallback? onLink;

  @override
  Widget build(BuildContext context) {
    final title = (item['title'] as String?)?.trim() ?? '';
    final subtitle = (item['subtitle'] as String?)?.trim() ?? '';

    if (title.isEmpty && subtitle.isEmpty && onLink == null) {
      return const SizedBox.shrink();
    }

    return LiquidGlass(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      borderRadius: 24,
      tintOpacity: 0.10,
      blur: LiquidTokens.blurHeavy,
      pressable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const LiquidStatusPill(
                label: 'NOVEDAD',
                color: MonacoColors.monacoGreen,
                compact: true,
                pulse: false,
              ),
              const Spacer(),
              if (total > 1)
                Text(
                  '${index + 1} / $total',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
          if (title.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: MonacoColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
                height: 1.1,
              ),
            ),
          ],
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ],
          if (onLink != null) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: LiquidButton(
                onPressed: onLink,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Ver más',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward_rounded,
                        size: 17, color: Colors.white),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
