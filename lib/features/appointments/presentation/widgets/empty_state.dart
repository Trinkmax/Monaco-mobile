import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';

/// Empty state reutilizable para listas de turnos. Acepta un CTA opcional.
class AppointmentsEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? ctaLabel;
  final VoidCallback? onCta;

  const AppointmentsEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.ctaLabel,
    this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
      children: [
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.18),
                  Colors.white.withOpacity(0.05),
                ],
              ),
              border:
                  Border.all(color: Colors.white.withOpacity(0.22)),
            ),
            child: Icon(icon, color: Colors.white, size: 40),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: MonacoColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            fontSize: 14,
            height: 1.45,
          ),
        ),
        if (ctaLabel != null && onCta != null) ...[
          const SizedBox(height: 22),
          Center(
            child: LiquidButton(
              onPressed: onCta,
              padding: const EdgeInsets.symmetric(
                  horizontal: 26, vertical: 14),
              child: Text(
                ctaLabel!,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ],
    ).animate().fadeIn(duration: 400.ms);
  }
}
