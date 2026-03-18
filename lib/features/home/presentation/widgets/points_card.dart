import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';

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
    _counterAnim = IntTween(begin: 0, end: widget.totalBalance)
        .animate(CurvedAnimation(
      parent: _counterController,
      curve: Curves.easeOutCubic,
    ));
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
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              MonacoColors.gold.withOpacity(0.15),
              MonacoColors.gold.withOpacity(0.05),
              MonacoColors.surface,
            ],
          ),
          border: Border.all(
            color: MonacoColors.gold.withOpacity(0.25),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.stars_rounded,
                  color: MonacoColors.gold,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  'Tus Puntos',
                  style: TextStyle(
                    color: MonacoColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  'Ver detalle',
                  style: TextStyle(
                    color: MonacoColors.gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 11,
                  color: MonacoColors.gold,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AnimatedBuilder(
                  listenable: _counterAnim,
                  builder: (context, _) {
                    return Text(
                      '${_counterAnim.value}',
                      style: TextStyle(
                        color: MonacoColors.textPrimary,
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: MonacoColors.gold.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'pts',
                      style: TextStyle(
                        color: MonacoColors.gold,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Acumulados: ${widget.totalEarned} pts',
              style: TextStyle(
                color: MonacoColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .slideY(begin: 0.08, end: 0, duration: 500.ms);
  }
}

/// Minimal AnimatedBuilder wrapper around [AnimatedWidget].
class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;

  const AnimatedBuilder({
    super.key,
    required super.listenable,
    required this.builder,
  });

  Animation<dynamic> get animation => listenable as Animation<dynamic>;

  @override
  Widget build(BuildContext context) => builder(context, null);
}
