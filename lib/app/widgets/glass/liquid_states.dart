import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../theme/monaco_colors.dart';
import 'liquid_pill.dart';

/// Estado vacío reutilizable: ícono en burbuja de vidrio, título, mensaje y
/// CTA opcional. Va dentro de un scroll (usa `ListView` para que el
/// pull-to-refresh siga funcionando).
class LiquidEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? ctaLabel;
  final VoidCallback? onCta;
  final bool scrollable;
  final EdgeInsets padding;

  const LiquidEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.ctaLabel,
    this.onCta,
    this.scrollable = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 32, vertical: 72),
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
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
                Colors.white.withValues(alpha: 0.18),
                Colors.white.withValues(alpha: 0.05),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
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
      if (message != null) ...[
        const SizedBox(height: 8),
        Text(
          message!,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 14,
            height: 1.45,
          ),
        ),
      ],
      if (ctaLabel != null && onCta != null) ...[
        const SizedBox(height: 22),
        Center(
          child: LiquidButton(
            onPressed: onCta,
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
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
    ];

    final body = scrollable
        ? ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: padding,
            children: children,
          )
        : Padding(
            padding: padding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: children,
            ),
          );
    return body.animate().fadeIn(duration: 400.ms);
  }
}

/// Estado de error con reintento. Distingue "sin conexión" de "algo salió mal"
/// por el texto de la excepción.
class LiquidErrorState extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;
  final String? title;
  final String? message;
  final bool scrollable;

  const LiquidErrorState({
    super.key,
    this.error,
    required this.onRetry,
    this.title,
    this.message,
    this.scrollable = true,
  });

  static bool isNetworkError(Object? error) {
    if (error == null) return false;
    final s = error.toString().toLowerCase();
    return s.contains('socketexception') ||
        s.contains('failed host lookup') ||
        s.contains('no address associated') ||
        s.contains('authretryablefetchexception') ||
        s.contains('clientexception') ||
        s.contains('connection') ||
        s.contains('network is unreachable') ||
        s.contains('timeout') ||
        s.contains('timed out');
  }

  @override
  Widget build(BuildContext context) {
    final offline = isNetworkError(error);
    final icon = offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded;
    final t = title ?? (offline ? 'Sin conexión' : 'Algo salió mal');
    final m = message ??
        (offline
            ? 'Revisá tu conexión a internet e intentá de nuevo.'
            : 'No pudimos cargar esta pantalla. Probá en unos segundos.');

    final children = <Widget>[
      Center(
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.18),
                Colors.white.withValues(alpha: 0.05),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: Icon(icon, color: Colors.white, size: 34),
        ),
      ),
      const SizedBox(height: 20),
      Text(
        t,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: MonacoColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        m,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.55),
          fontSize: 14,
          height: 1.45,
        ),
      ),
      const SizedBox(height: 22),
      Center(
        child: LiquidPill(
          onTap: onRetry,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Reintentar',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    ];

    final body = scrollable
        ? ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 72),
            children: children,
          )
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: children,
            ),
          );
    return body.animate().fadeIn(duration: 400.ms);
  }
}

/// Título de sección ("Sucursales", "Cartelera", …) con subtítulo y acción.
class LiquidSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onAction;
  final String? actionLabel;

  const LiquidSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: MonacoColors.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (onAction != null && actionLabel != null)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onAction,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actionLabel!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 10,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
