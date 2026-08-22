import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';

/// Paleta de orbes del onboarding (splash / welcome / login / gates).
/// Home se mantiene sobrio sin orbes; acá sí hay ambiente.
const kOnboardingOrbs = [
  MonacoColors.monacoGreen,
  MonacoColors.deepBlue,
  MonacoColors.deepViolet,
];
const kOnboardingOrbIntensity = 0.55;

/// Esqueleto común de las pantallas de onboarding: fondo negro con orbes,
/// botón "volver" de vidrio opcional arriba a la izquierda, contenido
/// scrolleable que se corre con el teclado y un pie fijo (CTA + legales).
class OnboardingScaffold extends StatelessWidget {
  final Widget child;
  final Widget? footer;
  final bool showBack;
  final VoidCallback? onBack;
  final Widget? topRight;
  final EdgeInsets padding;
  final bool scrollable;
  final bool orbs;

  /// Centra verticalmente al hijo y, si no entra (pantallas chicas, teclado),
  /// deja scrollear en vez de desbordar. Ignora [scrollable].
  final bool centered;

  /// Texto del paso ("Paso 1 de 3") que se dibuja al lado del botón volver.
  final String? stepLabel;

  const OnboardingScaffold({
    super.key,
    required this.child,
    this.footer,
    this.showBack = false,
    this.onBack,
    this.topRight,
    this.padding = const EdgeInsets.fromLTRB(24, 8, 24, 24),
    this.scrollable = true,
    this.orbs = true,
    this.centered = false,
    this.stepLabel,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showBack || topRight != null || stepLabel != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                if (showBack)
                  GlassBackButton(onTap: onBack ?? () => context.pop()),
                if (stepLabel != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    stepLabel!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
                const Spacer(),
                ?topRight,
              ],
            ),
          ),
        Expanded(
          child: centered
              ? LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: padding,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - padding.vertical,
                      ),
                      child: IntrinsicHeight(child: Center(child: child)),
                    ),
                  ),
                )
              : scrollable
              ? SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: padding,
                  child: child,
                )
              : Padding(padding: padding, child: child),
        ),
        if (footer != null)
          AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.fromLTRB(24, 8, 24, bottomInset > 0 ? 12 : 16),
            child: footer!,
          ),
      ],
    );

    return Scaffold(
      backgroundColor: MonacoColors.background,
      resizeToAvoidBottomInset: true,
      body: LiquidBackdrop(
        orbColors: orbs ? kOnboardingOrbs : null,
        intensity: kOnboardingOrbIntensity,
        child: SafeArea(child: body),
      ),
    );
  }
}

/// Botón "volver" redondo de vidrio (44x44, el mínimo táctil).
class GlassBackButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String tooltip;

  const GlassBackButton({
    super.key,
    required this.onTap,
    this.icon = Icons.arrow_back_ios_new_rounded,
    this.tooltip = 'Volver',
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: LiquidPill(
          onTap: onTap,
          padding: EdgeInsets.zero,
          tintOpacity: 0.08,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              icon,
              size: 18,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
        ),
      ),
    );
  }
}

/// Título grande del onboarding (Poppins w900, tracking negativo) + subtítulo.
class OnboardingTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? eyebrow;
  final TextAlign align;

  const OnboardingTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.eyebrow,
    this.align = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    final cross = align == TextAlign.center
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;
    return Column(
      crossAxisAlignment: cross,
      children: [
        if (eyebrow != null) ...[eyebrow!, const SizedBox(height: 14)],
        Text(
          title,
          textAlign: align,
          style: const TextStyle(
            color: MonacoColors.textPrimary,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.2,
            height: 1.08,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 10),
          Text(
            subtitle!,
            textAlign: align,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.58),
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
        ],
      ],
    );
  }
}

/// Botón primario a lo ancho (56 de alto) con estado de carga.
class OnboardingCta extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  const OnboardingCta({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return AnimatedOpacity(
      duration: LiquidTokens.swap,
      opacity: enabled ? 1 : 0.55,
      child: SizedBox(
        height: 56,
        child: LiquidButton(
          onPressed: enabled ? onPressed : null,
          padding: EdgeInsets.zero,
          borderRadius: 18,
          child: AnimatedSwitcher(
            duration: LiquidTokens.swap,
            child: loading
                ? const SizedBox(
                    key: ValueKey('loading'),
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    key: const ValueKey('label'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (icon != null) ...[
                        const SizedBox(width: 8),
                        Icon(icon, size: 18, color: Colors.white),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Link secundario ("Ya tengo cuenta", "Cambiar número", "Cerrar sesión").
class OnboardingLink extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? color;
  final bool dense;

  const OnboardingLink({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.color,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white.withValues(alpha: 0.78);
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 8 : 12,
            vertical: 10,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: c),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: onTap == null ? c.withValues(alpha: 0.4) : c,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Caja de error inline (texto sobre lámina roja tenue), con animación de
/// entrada. Para errores que no pertenecen a un campo puntual.
class OnboardingErrorBox extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const OnboardingErrorBox({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            MonacoColors.destructive.withValues(alpha: 0.18),
            MonacoColors.destructive.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(
          color: MonacoColors.destructive.withValues(alpha: 0.45),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: MonacoColors.destructive,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            OnboardingLink(
              label: actionLabel!,
              onTap: onAction,
              color: Colors.white,
              dense: true,
            ),
          ],
        ],
      ),
    );
  }
}
