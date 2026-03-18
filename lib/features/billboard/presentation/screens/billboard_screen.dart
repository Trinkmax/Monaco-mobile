import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
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
// Screen
// ---------------------------------------------------------------------------
class BillboardScreen extends ConsumerStatefulWidget {
  const BillboardScreen({super.key});

  @override
  ConsumerState<BillboardScreen> createState() => _BillboardScreenState();
}

class _BillboardScreenState extends ConsumerState<BillboardScreen> {
  late final PageController _pageController;
  Timer? _autoScrollTimer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  void _startAutoScroll(int itemCount) {
    _autoScrollTimer?.cancel();
    if (itemCount <= 1) return;
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final next = (_currentPage + 1) % itemCount;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncItems = ref.watch(billboardItemsProvider);

    return Scaffold(
      backgroundColor: MonacoColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: asyncItems.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: MonacoColors.gold),
        ),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: Colors.white70)),
        ),
        data: (items) {
          if (items.isEmpty) return _buildEmptyState();
          // Schedule auto-scroll after build.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _startAutoScroll(items.length);
          });
          return _buildCarousel(items);
        },
      ),
    );
  }

  // ---- Empty state ----
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.campaign_outlined,
              size: 72, color: MonacoColors.gold.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text(
            'Sin novedades',
            style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.w500),
          ),
        ],
      ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1),
    );
  }

  // ---- Carousel ----
  Widget _buildCarousel(List<Map<String, dynamic>> items) {
    return Stack(
      children: [
        // Pages
        PageView.builder(
          controller: _pageController,
          itemCount: items.length,
          onPageChanged: (i) => setState(() => _currentPage = i),
          itemBuilder: (context, index) {
            final item = items[index];
            return _BillboardPage(item: item);
          },
        ),

        // Indicator
        Positioned(
          bottom: MediaQuery.of(context).padding.bottom + 32,
          left: 0,
          right: 0,
          child: Center(
            child: SmoothPageIndicator(
              controller: _pageController,
              count: items.length,
              effect: WormEffect(
                dotHeight: 8,
                dotWidth: 8,
                activeDotColor: MonacoColors.gold,
                dotColor: Colors.white24,
                spacing: 10,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Single page inside the PageView
// ---------------------------------------------------------------------------
class _BillboardPage extends StatelessWidget {
  const _BillboardPage({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final imageUrl = item['image_url'] as String?;
    final title = item['title'] as String? ?? '';
    final subtitle = item['subtitle'] as String? ?? '';

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background image
        if (imageUrl != null && imageUrl.isNotEmpty)
          CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: MonacoColors.surface),
            errorWidget: (_, __, ___) => Container(
              color: MonacoColors.surface,
              child: const Icon(Icons.broken_image,
                  color: Colors.white24, size: 64),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  MonacoColors.surface,
                  MonacoColors.background,
                ],
              ),
            ),
          ),

        // Dark gradient overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.4, 0.75, 1.0],
              colors: [
                Colors.black.withOpacity(0.3),
                Colors.transparent,
                Colors.black.withOpacity(0.6),
                Colors.black.withOpacity(0.9),
              ],
            ),
          ),
        ),

        // Text content
        Positioned(
          left: 24,
          right: 24,
          bottom: MediaQuery.of(context).padding.bottom + 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.05),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                  ),
                ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
