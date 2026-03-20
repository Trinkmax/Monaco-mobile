import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';

class _SlideData {
  final String title;
  final String subtitle;
  final IconData? icon;
  final String? imagePath;

  const _SlideData({
    required this.title,
    required this.subtitle,
    this.icon,
    this.imagePath,
  });
}

const _slides = [
  _SlideData(
    title: 'Tu barberia inteligente',
    subtitle: 'Consulta la disponibilidad en tiempo real',
    imagePath: 'assets/images/onboarding_barber.png',
  ),
  _SlideData(
    title: 'Acumula puntos',
    subtitle: 'Ganas puntos por cada servicio y canjealos por premios',
    imagePath: 'assets/images/onboarding_reviews.png',
  ),
  _SlideData(
    title: 'Opina y mejoramos',
    subtitle: 'Tu feedback nos ayuda a darte un mejor servicio',
    imagePath: 'assets/images/onboarding_gifts.png',
  ),
];

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
  }

  void _goToLogin() => context.go('/login');

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _slides.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SafeArea(
        child: Column(
          children: [
            // --- Skip button ---
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 16, right: 24),
                child: AnimatedOpacity(
                  opacity: isLastPage ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 250),
                  child: TextButton(
                    onPressed: isLastPage ? null : _goToLogin,
                    child: Text(
                      'Saltar',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // --- Page view ---
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _slides.length,
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return _SlideWidget(
                    key: ValueKey(index),
                    slide: slide,
                  );
                },
              ),
            ),

            // --- Page indicator ---
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: SmoothPageIndicator(
                controller: _pageController,
                count: _slides.length,
                effect: ExpandingDotsEffect(
                  activeDotColor: MonacoColors.gold,
                  dotColor: Colors.white.withOpacity(0.2),
                  dotHeight: 8,
                  dotWidth: 8,
                  expansionFactor: 3,
                  spacing: 6,
                ),
              ),
            ),

            // --- Action button ---
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: isLastPage ? _goToLogin : _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MonacoColors.gold,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    isLastPage ? 'Comenzar' : 'Siguiente',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideWidget extends StatelessWidget {
  final _SlideData slide;

  const _SlideWidget({super.key, required this.slide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // --- Animated icon or image ---
          (slide.imagePath != null)
              ? SizedBox(
                  width: 360, // Make the illustration much bigger as requested
                  height: 360,
                  child: Image.asset(
                    slide.imagePath!,
                    fit: BoxFit.contain,
                  ),
                )
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1.0, 1.0),
                    duration: 500.ms,
                    curve: Curves.easeOut,
                  )
              : Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: MonacoColors.gold.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    slide.icon,
                    size: 56,
                    color: MonacoColors.gold,
                  ),
                )
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1.0, 1.0),
                    duration: 500.ms,
                    curve: Curves.easeOut,
                  ),

          const SizedBox(height: 48),

          // --- Title ---
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.2,
            ),
          )
              .animate()
              .fadeIn(delay: 200.ms, duration: 500.ms)
              .slideY(begin: 0.15, end: 0, duration: 500.ms),

          const SizedBox(height: 16),

          // --- Subtitle ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              slide.subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Colors.white.withOpacity(0.55),
                height: 1.5,
              ),
            ),
          )
              .animate()
              .fadeIn(delay: 350.ms, duration: 500.ms)
              .slideY(begin: 0.15, end: 0, duration: 500.ms),
        ],
      ),
    );
  }
}
