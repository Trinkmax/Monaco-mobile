import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/core/supabase/supabase_provider.dart';
import 'package:monaco_mobile/features/reviews/providers/reviews_provider.dart';

/// Flujo de reseña post-visita:
///   paso 0 → estrellas;
///   paso 1 → según rating: 3-4 formulario de mejoras, 1-2 auto-envío con
///            mensaje de contención, 5 envío directo;
///   paso 2 → pantalla final (5★ ofrece abrir Google Maps).
class ReviewFlowScreen extends ConsumerStatefulWidget {
  final String token;

  const ReviewFlowScreen({super.key, required this.token});

  @override
  ConsumerState<ReviewFlowScreen> createState() => _ReviewFlowScreenState();
}

class _ReviewFlowScreenState extends ConsumerState<ReviewFlowScreen> {
  static const _improvementCategories = [
    'Tiempo de espera',
    'Atención',
    'Limpieza',
    'Resultado',
    'Precio',
    'Otro',
  ];

  int _step = 0; // 0 = rating, 1 = seguimiento, 2 = final
  int _rating = 0;
  bool _submitting = false;
  bool _submitted = false;
  String? _mapsUrl;
  final Set<String> _selectedCategories = {};
  final TextEditingController _commentController = TextEditingController();

  String get _ratingLabel {
    switch (_rating) {
      case 5:
        return 'Excelente';
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

  String get _title {
    switch (_step) {
      case 0:
        return 'Calificá tu visita';
      case 1:
        return _rating >= 3 ? 'Tu opinión' : 'Lo sentimos';
      default:
        return 'Listo';
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // ── Envío ─────────────────────────────────────────────────────────────

  Future<bool> _submitReview({
    List<String>? categories,
    String? comment,
  }) async {
    if (_submitting || _submitted) return _submitted;
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

      if (!mounted) return true;
      setState(() {
        _submitting = false;
        _submitted = true;
      });
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() => _submitting = false);
      showLiquidToast(
        context,
        LiquidErrorState.isNetworkError(e)
            ? 'Sin conexión. Revisá tu internet e intentá de nuevo.'
            : 'No pudimos enviar tu reseña. Probá de nuevo.',
        tone: LiquidToastTone.error,
      );
      return false;
    }
  }

  Future<String?> _fetchMapsUrl() async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      final res = await supabase.rpc(
        'get_review_branch_google_maps_url',
        params: {'p_token': widget.token},
      );
      final url = res?.toString().trim();
      if (url == null || url.isEmpty) return null;
      return url;
    } catch (_) {
      // La reseña ya se guardó: sin link sólo no ofrecemos el botón.
      return null;
    }
  }

  Future<void> _openMaps() async {
    final url = _mapsUrl;
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      showLiquidToast(
        context,
        'No pudimos abrir Google Maps en este dispositivo.',
        tone: LiquidToastTone.error,
      );
    }
  }

  // ── Interacción ───────────────────────────────────────────────────────

  void _onRatingSelected(int rating) {
    if (rating == 5) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.selectionClick();
    }
    setState(() => _rating = rating);
  }

  Future<void> _proceed() async {
    if (_rating == 0 || _submitting) return;
    HapticFeedback.lightImpact();

    if (_rating == 5) {
      final ok = await _submitReview();
      if (!ok || !mounted) return;
      final url = await _fetchMapsUrl();
      if (!mounted) return;
      setState(() {
        _mapsUrl = url;
        _step = 2;
      });
      // Intento directo: si el sistema no puede, queda el botón en pantalla.
      await _openMaps();
      return;
    }

    setState(() => _step = 1);
    if (_rating <= 2) {
      final ok = await _submitReview();
      if (ok && mounted) setState(() => _step = 2);
    }
  }

  Future<void> _submitFeedback() async {
    final ok = await _submitReview(
      categories: _selectedCategories.toList(),
      comment: _commentController.text,
    );
    if (ok && mounted) {
      FocusScope.of(context).unfocus();
      setState(() => _step = 2);
    }
  }

  Future<void> _retryLowRating() async {
    final ok = await _submitReview();
    if (ok && mounted) setState(() => _step = 2);
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LiquidAppBarScaffold(
      title: _title,
      showBackButton: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          ),
        ),
        child: switch (_step) {
          0 => _buildRatingStep(),
          1 => _rating >= 3 ? _buildFeedbackForm() : _buildLowRatingWait(),
          _ => _buildFinal(),
        },
      ),
    );
  }

  // ── Paso 0: estrellas ──

  Widget _buildRatingStep() {
    return Center(
      key: const ValueKey('step_rating'),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '¿Cómo fue tu visita?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: MonacoColors.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
                height: 1.1,
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.06, end: 0),
            const SizedBox(height: 8),
            Text(
              'Nos ayuda a mejorar cada corte.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ).animate().fadeIn(delay: 120.ms, duration: 400.ms),
            const SizedBox(height: 36),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starIndex = index + 1;
                final isSelected = starIndex <= _rating;
                return _Star(
                  selected: isSelected,
                  onTap: () => _onRatingSelected(starIndex),
                ).animate().fadeIn(
                      delay: Duration(milliseconds: 120 + index * 60),
                      duration: 350.ms,
                    ).slideY(
                      begin: 0.3,
                      end: 0,
                      delay: Duration(milliseconds: 120 + index * 60),
                      duration: 350.ms,
                      curve: Curves.easeOutCubic,
                    );
              }),
            ),
            const SizedBox(height: 22),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _ratingLabel,
                key: ValueKey(_rating),
                style: TextStyle(
                  color: _rating > 0
                      ? MonacoColors.textPrimary
                      : Colors.white.withValues(alpha: 0.35),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            const SizedBox(height: 44),
            AnimatedOpacity(
              opacity: _rating > 0 ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 260),
              child: IgnorePointer(
                ignoring: _rating == 0,
                child: LiquidButton(
                  onPressed: _submitting ? null : _proceed,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  child: _submitting
                      ? const _ButtonSpinner()
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Continuar',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(width: 6),
                            Icon(Icons.arrow_forward_rounded,
                                size: 18, color: Colors.white),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Paso 1 (3-4★): formulario ──

  Widget _buildFeedbackForm() {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return ListView(
      key: const ValueKey('step_feedback'),
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 40 + bottomInset),
      children: [
        _RatingRecap(rating: _rating, label: _ratingLabel).liquidEnter(index: 0),
        const SizedBox(height: 22),
        const Text(
          '¿En qué podemos mejorar?',
          style: TextStyle(
            color: MonacoColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            height: 1.1,
          ),
        ).liquidEnter(index: 1),
        const SizedBox(height: 6),
        Text(
          'Marcá lo que te parezca. Es opcional, pero nos sirve.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          ),
        ).liquidEnter(index: 2),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < _improvementCategories.length; i++)
              LiquidChip(
                label: _improvementCategories[i],
                selected: _selectedCategories.contains(_improvementCategories[i]),
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    final c = _improvementCategories[i];
                    if (!_selectedCategories.remove(c)) {
                      _selectedCategories.add(c);
                    }
                  });
                },
              ).liquidEnter(index: 3 + i, stagger: 45),
          ],
        ),
        const SizedBox(height: 26),
        LiquidTextField(
          controller: _commentController,
          label: 'COMENTARIO (OPCIONAL)',
          hint: 'Contanos un poco más sobre tu experiencia…',
          maxLines: 4,
          maxLength: 500,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.newline,
          enabled: !_submitting,
        ).liquidEnter(index: 10),
        const SizedBox(height: 26),
        LiquidButton(
          onPressed: _submitting ? null : _submitFeedback,
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: _submitting
              ? const _ButtonSpinner()
              : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.send_rounded, size: 17, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Enviar opinión',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
        ).liquidEnter(index: 11),
      ],
    );
  }

  // ── Paso 1 (1-2★): contención mientras se envía ──

  Widget _buildLowRatingWait() {
    return _FinalLayout(
      key: const ValueKey('step_support_wait'),
      icon: Icons.support_agent_rounded,
      accent: MonacoColors.warning,
      title: 'Lamentamos tu experiencia',
      message: 'Te vamos a contactar pronto para solucionarlo.',
      children: [
        if (_submitting)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.4,
              ),
            ),
          ).animate().fadeIn(delay: 300.ms, duration: 300.ms)
        else
          LiquidPill(
            onTap: _retryLowRating,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Reintentar envío',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ── Paso 2: final por rating ──

  Widget _buildFinal() {
    if (_rating == 5) {
      return _FinalLayout(
        key: const ValueKey('step_final_5'),
        icon: Icons.check_rounded,
        accent: MonacoColors.monacoGreen,
        title: '¡Gracias!',
        message: _mapsUrl != null
            ? 'Tu opinión nos ayuda un montón. ¿Nos dejás también una reseña en Google? Te lleva un minuto.'
            : 'Tu opinión nos ayuda un montón. Nos vemos en la próxima.',
        children: [
          if (_mapsUrl != null) ...[
            SizedBox(
              width: double.infinity,
              child: LiquidButton(
                onPressed: _openMaps,
                padding: const EdgeInsets.symmetric(vertical: 15),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.rate_review_rounded, size: 18, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Dejar reseña en Google',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          _DoneButton(onTap: _close),
        ],
      );
    }

    if (_rating >= 3) {
      return _FinalLayout(
        key: const ValueKey('step_final_mid'),
        icon: Icons.check_rounded,
        accent: MonacoColors.monacoGreen,
        title: 'Gracias por tu opinión',
        message: 'Vamos a trabajar en eso para que la próxima visita sea mejor.',
        children: [_DoneButton(onTap: _close)],
      );
    }

    return _FinalLayout(
      key: const ValueKey('step_final_low'),
      icon: Icons.support_agent_rounded,
      accent: MonacoColors.warning,
      title: 'Lamentamos tu experiencia',
      message:
          'Ya avisamos a la barbería. Te vamos a contactar pronto para solucionarlo.',
      children: [_DoneButton(onTap: _close)],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PIEZAS
// ═══════════════════════════════════════════════════════════════════════════

class _Star extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  const _Star({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const filled = MonacoColors.starFilled;
    return Semantics(
      button: true,
      label: selected ? 'Estrella seleccionada' : 'Estrella',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 58,
          height: 64,
          child: Center(
            child: AnimatedScale(
              scale: selected ? 1.14 : 1.0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              child: Icon(
                selected ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 50,
                color: selected ? filled : MonacoColors.starEmpty,
                shadows: selected
                    ? [
                        Shadow(
                          color: filled.withValues(alpha: 0.55),
                          blurRadius: 18,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RatingRecap extends StatelessWidget {
  final int rating;
  final String label;
  const _RatingRecap({required this.rating, required this.label});

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderRadius: 16,
      tintOpacity: 0.06,
      pressable: false,
      showVignette: false,
      blur: LiquidTokens.blurSubtle,
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              5,
              (i) => Icon(
                i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 18,
                color: i < rating
                    ? MonacoColors.starFilled
                    : MonacoColors.starEmpty,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              color: MonacoColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _FinalLayout extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String message;
  final List<Widget> children;

  const _FinalLayout({
    super.key,
    required this.icon,
    required this.accent,
    required this.title,
    required this.message,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withValues(alpha: 0.32),
                      accent.withValues(alpha: 0.10),
                    ],
                  ),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.45),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 28,
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: Icon(icon, size: 50, color: accent),
              )
                  .animate()
                  .fadeIn(duration: 350.ms)
                  .scale(
                    begin: const Offset(0.6, 0.6),
                    end: const Offset(1, 1),
                    duration: 520.ms,
                    curve: Curves.easeOutBack,
                  ),
            ),
            const SizedBox(height: 26),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: MonacoColors.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
                height: 1.1,
              ),
            ).animate().fadeIn(delay: 150.ms, duration: 400.ms),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 15,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ).animate().fadeIn(delay: 280.ms, duration: 400.ms),
            const SizedBox(height: 34),
            ...children.map(
              (c) => c.animate().fadeIn(delay: 420.ms, duration: 400.ms),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoneButton extends StatelessWidget {
  final VoidCallback onTap;
  const _DoneButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LiquidPill(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
        child: const Text(
          'Listo',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
    );
  }
}
