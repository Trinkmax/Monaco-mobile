import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/monaco_colors.dart';
import 'liquid_tokens.dart';

/// Hoja inferior del lenguaje Liquid Glass: vidrio con blur, manija, título
/// opcional y contenido scrolleable. Devuelve lo que se le pase a `pop`.
///
/// ```dart
/// final elegido = await showLiquidSheet<String>(
///   context,
///   title: '¿Con quién te querés atender?',
///   builder: (ctx) => ...,
/// );
/// ```
Future<T?> showLiquidSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  String? title,
  String? subtitle,
  bool isDismissible = true,
  bool enableDrag = true,
  bool scrollable = true,
  double maxHeightFactor = 0.9,
  EdgeInsets padding = const EdgeInsets.fromLTRB(20, 8, 20, 24),
  bool useRootNavigator = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.62),
    builder: (ctx) => LiquidSheetBody(
      title: title,
      subtitle: subtitle,
      scrollable: scrollable,
      maxHeightFactor: maxHeightFactor,
      padding: padding,
      child: builder(ctx),
    ),
  );
}

/// Cuerpo de la hoja (se puede usar directo dentro de un `showModalBottomSheet`
/// propio si hace falta más control).
class LiquidSheetBody extends StatelessWidget {
  final Widget child;
  final String? title;
  final String? subtitle;
  final bool scrollable;
  final double maxHeightFactor;
  final EdgeInsets padding;

  const LiquidSheetBody({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.scrollable = true,
    this.maxHeightFactor = 0.9,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 24),
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * maxHeightFactor;
    final bottomInset = media.viewInsets.bottom;

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4.5,
            margin: const EdgeInsets.only(top: 10, bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Text(
              title!,
              style: const TextStyle(
                color: MonacoColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                height: 1.15,
              ),
            ),
          ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 5, 20, 0),
            child: Text(
              subtitle!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
        if (title != null || subtitle != null) const SizedBox(height: 8),
      ],
    );

    final body = Padding(padding: padding, child: child);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(LiquidTokens.radiusCardLarge),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: LiquidTokens.blurHeavy,
            sigmaY: LiquidTokens.blurHeavy,
          ),
          child: Container(
            constraints: BoxConstraints(maxHeight: maxHeight),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF161616).withValues(alpha: 0.96),
                  const Color(0xFF0C0C0C).withValues(alpha: 0.98),
                ],
              ),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.18),
                  width: 0.8,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  header,
                  if (scrollable)
                    Flexible(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: body,
                      ),
                    )
                  else
                    Flexible(child: body),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
