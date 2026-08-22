import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/monaco_colors.dart';
import 'liquid_tokens.dart';

enum LiquidToastTone { neutral, success, error, info }

/// Aviso flotante de vidrio que baja desde arriba y se va solo. Reemplaza a
/// los `SnackBar` de Material en toda la app (que quedan tapados por el dock
/// y rompen la estética).
///
/// Usa un `Overlay` del navigator raíz: se puede llamar desde cualquier
/// contexto montado, incluso antes de un `pop`.
void showLiquidToast(
  BuildContext context,
  String message, {
  LiquidToastTone tone = LiquidToastTone.neutral,
  IconData? icon,
  Duration duration = const Duration(milliseconds: 2600),
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  _LiquidToastOverlay.dismissCurrent();

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _LiquidToastWidget(
      message: message,
      tone: tone,
      icon: icon,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
      onDismissed: () {
        if (entry.mounted) entry.remove();
        if (_LiquidToastOverlay.current == entry) {
          _LiquidToastOverlay.current = null;
        }
      },
    ),
  );
  _LiquidToastOverlay.current = entry;
  overlay.insert(entry);
}

class _LiquidToastOverlay {
  static OverlayEntry? current;

  static void dismissCurrent() {
    final c = current;
    if (c != null && c.mounted) c.remove();
    current = null;
  }
}

class _LiquidToastWidget extends StatefulWidget {
  final String message;
  final LiquidToastTone tone;
  final IconData? icon;
  final Duration duration;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDismissed;

  const _LiquidToastWidget({
    required this.message,
    required this.tone,
    required this.icon,
    required this.duration,
    required this.actionLabel,
    required this.onAction,
    required this.onDismissed,
  });

  @override
  State<_LiquidToastWidget> createState() => _LiquidToastWidgetState();
}

class _LiquidToastWidgetState extends State<_LiquidToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    reverseDuration: const Duration(milliseconds: 240),
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ctrl.forward();
    _timer = Timer(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    _timer?.cancel();
    if (!mounted) return;
    await _ctrl.reverse();
    widget.onDismissed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Color get _accent {
    switch (widget.tone) {
      case LiquidToastTone.success:
        return MonacoColors.monacoGreen;
      case LiquidToastTone.error:
        return MonacoColors.destructive;
      case LiquidToastTone.info:
        return MonacoColors.info;
      case LiquidToastTone.neutral:
        return Colors.white;
    }
  }

  IconData get _icon {
    if (widget.icon != null) return widget.icon!;
    switch (widget.tone) {
      case LiquidToastTone.success:
        return Icons.check_circle_rounded;
      case LiquidToastTone.error:
        return Icons.error_rounded;
      case LiquidToastTone.info:
        return Icons.info_rounded;
      case LiquidToastTone.neutral:
        return Icons.notifications_none_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + 10;
    final accent = _accent;
    final anim = CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return Positioned(
      top: top,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, -0.6), end: Offset.zero)
            .animate(anim),
        child: FadeTransition(
          opacity: anim,
          child: Material(
            color: Colors.transparent,
            child: Dismissible(
              key: UniqueKey(),
              direction: DismissDirection.up,
              onDismissed: (_) => widget.onDismissed(),
              child: GestureDetector(
                onTap: _dismiss,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: LiquidTokens.blurHeavy,
                      sigmaY: LiquidTokens.blurHeavy,
                    ),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF1B1B1B).withValues(alpha: 0.92),
                            const Color(0xFF0E0E0E).withValues(alpha: 0.94),
                          ],
                        ),
                        border: Border.all(
                          color: accent.withValues(
                              alpha: widget.tone == LiquidToastTone.neutral
                                  ? 0.18
                                  : 0.42),
                          width: 0.8,
                        ),
                        boxShadow: LiquidTokens.cardLift(),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  accent.withValues(alpha: 0.28),
                                  accent.withValues(alpha: 0.10),
                                ],
                              ),
                              border: Border.all(
                                  color: accent.withValues(alpha: 0.4),
                                  width: 0.8),
                            ),
                            child: Icon(_icon, size: 18, color: accent),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.message,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: MonacoColors.textPrimary,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                            ),
                          ),
                          if (widget.actionLabel != null) ...[
                            const SizedBox(width: 10),
                            TextButton(
                              onPressed: () {
                                widget.onAction?.call();
                                _dismiss();
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: accent,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                widget.actionLabel!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
