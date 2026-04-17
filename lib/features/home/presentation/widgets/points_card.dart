import 'package:flutter/material.dart' hide AnimatedBuilder;
import 'package:flutter/material.dart' as m show AnimatedBuilder;
import 'package:flutter_animate/flutter_animate.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';

/// Tarjeta hero de puntos del cliente — lámina glass neutra (gris) con
/// contador animado y pill "pts".
class PointsCard extends StatefulWidget {
  final int totalBalance;
  final int totalEarned;
  final VoidCallback? onTap;

  const PointsCard({
    super.key,
    required this.totalBalance,
    required this.totalEarned,
    this.onTap,
  });

  @override
  State<PointsCard> createState() => _PointsCardState();
}

class _PointsCardState extends State<PointsCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _counterController;
  late Animation<int> _counterAnim;

  @override
  void initState() {
    super.initState();
    _counterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _counterAnim = IntTween(begin: 0, end: widget.totalBalance).animate(
      CurvedAnimation(parent: _counterController, curve: Curves.easeOutCubic),
    );
    _counterController.forward();
  }

  @override
  void didUpdateWidget(covariant PointsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.totalBalance != widget.totalBalance) {
      _counterAnim = IntTween(
        begin: oldWidget.totalBalance,
        end: widget.totalBalance,
      ).animate(CurvedAnimation(
        parent: _counterController,
        curve: Curves.easeOutCubic,
      ));
      _counterController
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _counterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      onTap: widget.onTap,
      borderRadius: 26,
      padding: const EdgeInsets.all(22),
      tintOpacity: 0.09,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _NeutralBadge(icon: Icons.auto_awesome_rounded),
              const SizedBox(width: 10),
              const Text(
                'Tus Puntos',
                style: TextStyle(
                  color: MonacoColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Ver detalle',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.88),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 10,
                    color: Colors.white.withOpacity(0.88),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              m.AnimatedBuilder(
                animation: _counterAnim,
                builder: (context, _) {
                  return Text(
                    '${_counterAnim.value}',
                    style: const TextStyle(
                      color: MonacoColors.textPrimary,
                      fontSize: 52,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      letterSpacing: -1.6,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  );
                },
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.18),
                        Colors.white.withOpacity(0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.22),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    'pts',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.trending_up_rounded,
                size: 13,
                color: Colors.white.withOpacity(0.55),
              ),
              const SizedBox(width: 5),
              Text(
                'Acumulados: ${widget.totalEarned} pts',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .slideY(begin: 0.08, end: 0, duration: 500.ms);
  }
}

class _NeutralBadge extends StatelessWidget {
  final IconData icon;
  const _NeutralBadge({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.22),
            Colors.white.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white.withOpacity(0.22), width: 0.8),
      ),
      child: Icon(icon, color: Colors.white, size: 17),
    );
  }
}
