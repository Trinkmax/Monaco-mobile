import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/core/supabase/supabase_provider.dart';
import 'package:monaco_mobile/features/reviews/providers/reviews_provider.dart';

class ReviewFlowScreen extends ConsumerStatefulWidget {
  final String token;

  const ReviewFlowScreen({super.key, required this.token});

  @override
  ConsumerState<ReviewFlowScreen> createState() => _ReviewFlowScreenState();
}

class _ReviewFlowScreenState extends ConsumerState<ReviewFlowScreen> {
  int _currentStep = 0; // 0 = rating, 1 = follow-up
  int _rating = 0;
  bool _submitting = false;
  bool _submitted = false;
  final List<String> _improvementCategories = [
    'Tiempo de espera',
    'Atención',
    'Limpieza',
    'Resultado',
    'Precio',
    'Otro',
  ];
  final Set<String> _selectedCategories = {};
  final TextEditingController _commentController = TextEditingController();

  String get _ratingLabel {
    switch (_rating) {
      case 5:
        return '¡Excelente!';
      case 4:
        return 'Muy bueno';
      case 3:
        return 'Bueno';
      case 2:
        return 'Regular';
      case 1:
        return 'Malo';
      default:
        return 'Tocá una estrella';
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview({
    List<String>? categories,
    String? comment,
  }) async {
    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      final supabase = ref.read(supabaseClientProvider);
      final params = <String, dynamic>{
        'p_token': widget.token,
        'p_rating': _rating,
      };

      if (categories != null && categories.isNotEmpty) {
        params['p_improvement_categories'] = categories;
      }
      if (comment != null && comment.trim().isNotEmpty) {
        params['p_comment'] = comment.trim();
      }

      await supabase.rpc('submit_client_review', params: params);

      ref.invalidate(pendingReviewsProvider);

      if (!mounted) return;

      setState(() => _submitted = true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Reseña enviada correctamente'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

      // For rating 5, try opening Google Maps first
      if (_rating == 5) {
        await _tryOpenGoogleMaps();
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al enviar reseña: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _tryOpenGoogleMaps() async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      final res = await supabase.rpc(
        'get_review_branch_google_maps_url',
        params: {'p_token': widget.token},
      );
      if (res != null && res.toString().isNotEmpty) {
        final uri = Uri.parse(res.toString());
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (_) {
      // Silently fail — the review was already submitted
    }
  }

  void _onRatingSelected(int rating) {
    HapticFeedback.mediumImpact();
    setState(() {
      _rating = rating;
    });
  }

  void _proceedToStep2() {
    if (_rating == 0) return;

    setState(() => _currentStep = 1);

    // For ratings 1-2, auto-submit
    if (_rating <= 2) {
      _submitReview();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MonacoColors.background,
      appBar: AppBar(
        backgroundColor: MonacoColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _currentStep == 0 ? 'Calificá tu visita' : 'Tu opinión',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: 350.ms,
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _currentStep == 0
            ? _buildStarRatingStep()
            : _buildFollowUpStep(),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // STEP 1 — Star Rating
  // ──────────────────────────────────────────────
  Widget _buildStarRatingStep() {
    return Center(
      key: const ValueKey('step_rating'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '¿Cómo fue tu experiencia?',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ).animate().fadeIn(duration: 400.ms),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starIndex = index + 1;
                final isSelected = starIndex <= _rating;
                return GestureDetector(
                  onTap: () => _onRatingSelected(starIndex),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: AnimatedScale(
                      scale: isSelected ? 1.15 : 1.0,
                      duration: 200.ms,
                      curve: Curves.easeOutBack,
                      child: Icon(
                        isSelected
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 48,
                        color: isSelected
                            ? MonacoColors.starFilled
                            : MonacoColors.starEmpty,
                      ),
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(
                      delay: Duration(milliseconds: 100 + index * 60),
                      duration: 350.ms,
                    )
                    .slideY(
                      begin: 0.3,
                      end: 0,
                      delay: Duration(milliseconds: 100 + index * 60),
                      duration: 350.ms,
                      curve: Curves.easeOut,
                    );
              }),
            ),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: 200.ms,
              child: Text(
                _ratingLabel,
                key: ValueKey(_rating),
                style: TextStyle(
                  color: _rating > 0
                      ? Colors.white
                      : Colors.white.withOpacity(0.3),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 48),
            AnimatedOpacity(
              opacity: _rating > 0 ? 1.0 : 0.0,
              duration: 300.ms,
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _rating > 0 ? _proceedToStep2 : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MonacoColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Continuar',
                    style: TextStyle(
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

  // ──────────────────────────────────────────────
  // STEP 2 — Follow-up based on rating
  // ──────────────────────────────────────────────
  Widget _buildFollowUpStep() {
    if (_rating == 5) {
      return _buildRating5ThankYou();
    } else if (_rating >= 3) {
      return _buildRating3or4Feedback();
    } else {
      return _buildRating1or2Support();
    }
  }

  // ── Rating 5: Thank you + Google Maps redirect ──
  Widget _buildRating5ThankYou() {
    return Center(
      key: const ValueKey('step_thankyou'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: MonacoColors.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.celebration_rounded,
                size: 48,
                color: MonacoColors.primary,
              ),
            )
                .animate()
                .fadeIn(duration: 400.ms)
                .scale(
                  begin: const Offset(0.5, 0.5),
                  end: const Offset(1, 1),
                  duration: 500.ms,
                  curve: Curves.easeOutBack,
                ),
            const SizedBox(height: 24),
            const Text(
              '¡Gracias por tu calificación!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
            const SizedBox(height: 12),
            Text(
              _submitting
                  ? 'Enviando...'
                  : 'Tu opinión fue registrada.\nRedirigiendo a Google Maps...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 15,
                height: 1.4,
              ),
            ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
            if (_submitting) ...[
              const SizedBox(height: 32),
              const CircularProgressIndicator(
                color: MonacoColors.primary,
                strokeWidth: 2.5,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Rating 3-4: Improvement feedback form ──
  Widget _buildRating3or4Feedback() {
    return SingleChildScrollView(
      key: const ValueKey('step_feedback'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¿En qué podemos mejorar?',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ).animate().fadeIn(duration: 350.ms),
          const SizedBox(height: 8),
          Text(
            'Seleccioná las áreas que consideres importantes.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 14,
            ),
          ).animate().fadeIn(delay: 100.ms, duration: 350.ms),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _improvementCategories.asMap().entries.map((entry) {
              final index = entry.key;
              final category = entry.value;
              final isSelected = _selectedCategories.contains(category);

              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    if (isSelected) {
                      _selectedCategories.remove(category);
                    } else {
                      _selectedCategories.add(category);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: 200.ms,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? MonacoColors.primary.withOpacity(0.2)
                        : MonacoColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected
                          ? MonacoColors.primary
                          : Colors.white.withOpacity(0.08),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    category,
                    style: TextStyle(
                      color: isSelected
                          ? MonacoColors.primary
                          : Colors.white.withOpacity(0.7),
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(
                    delay: Duration(milliseconds: 150 + index * 50),
                    duration: 300.ms,
                  )
                  .slideX(
                    begin: 0.1,
                    end: 0,
                    delay: Duration(milliseconds: 150 + index * 50),
                    duration: 300.ms,
                    curve: Curves.easeOut,
                  );
            }).toList(),
          ),
          const SizedBox(height: 28),
          Text(
            'Comentario (opcional)',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _commentController,
            maxLines: 4,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Contanos más sobre tu experiencia...',
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.25),
                fontSize: 14,
              ),
              filled: true,
              fillColor: MonacoColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: MonacoColors.primary.withOpacity(0.5),
                ),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _submitting
                  ? null
                  : () => _submitReview(
                        categories: _selectedCategories.toList(),
                        comment: _commentController.text,
                      ),
              style: ElevatedButton.styleFrom(
                backgroundColor: MonacoColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: MonacoColors.primary.withOpacity(0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'Enviar feedback',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Rating 1-2: Support message + auto-submit ──
  Widget _buildRating1or2Support() {
    return Center(
      key: const ValueKey('step_support'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.support_agent_rounded,
                size: 48,
                color: Colors.orange.shade300,
              ),
            )
                .animate()
                .fadeIn(duration: 400.ms)
                .scale(
                  begin: const Offset(0.5, 0.5),
                  end: const Offset(1, 1),
                  duration: 500.ms,
                  curve: Curves.easeOutBack,
                ),
            const SizedBox(height: 28),
            const Text(
              'Lamentamos tu experiencia',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
            const SizedBox(height: 12),
            Text(
              'Te vamos a contactar pronto\npara solucionarlo.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 16,
                height: 1.4,
              ),
            ).animate().fadeIn(delay: 350.ms, duration: 400.ms),
            const SizedBox(height: 36),
            if (_submitting)
              const CircularProgressIndicator(
                color: MonacoColors.primary,
                strokeWidth: 2.5,
              ).animate().fadeIn(delay: 500.ms, duration: 300.ms),
          ],
        ),
      ),
    );
  }
}
