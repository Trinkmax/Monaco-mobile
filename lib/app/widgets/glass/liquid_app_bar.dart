import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/monaco_colors.dart';

/// AppBar translúcido con blur que se intensifica al scrollear, y una
/// hairline que aparece debajo cuando el contenido pasa por detrás.
///
/// Para habilitar el efecto reactive-on-scroll, envolvé tu screen con
/// [LiquidAppBarScaffold] — maneja el scroll listener internamente.
class LiquidAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool scrolled;
  final bool centerTitle;
  final bool showBackButton;
  final VoidCallback? onBack;

  const LiquidAppBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.scrolled = false,
    this.centerTitle = false,
    this.showBackButton = false,
    this.onBack,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: scrolled ? 30 : 12,
          sigmaY: scrolled ? 30 : 12,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          decoration: BoxDecoration(
            color: MonacoColors.background.withOpacity(scrolled ? 0.55 : 0.18),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(scrolled ? 0.10 : 0.0),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: kToolbarHeight,
              child: Row(
                children: [
                  if (leading != null)
                    leading!
                  else if (showBackButton)
                    _BackArrow(onBack: onBack)
                  else
                    const SizedBox(width: 16),
                  Expanded(
                    child: Align(
                      alignment: centerTitle
                          ? Alignment.center
                          : Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: centerTitle ? 0 : 4,
                          right: centerTitle ? 0 : 4,
                        ),
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: MonacoColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (actions != null)
                    ...actions!
                  else
                    const SizedBox(width: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackArrow extends StatelessWidget {
  final VoidCallback? onBack;
  const _BackArrow({this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Colors.white.withOpacity(0.9),
          size: 20,
        ),
        onPressed: onBack ?? () => context.pop(),
      ),
    );
  }
}

/// Scaffold wrapper que conecta automáticamente un [LiquidAppBar] con el
/// scroll del body — el blur y la hairline reaccionan al pasar el contenido.
class LiquidAppBarScaffold extends StatefulWidget {
  final String title;
  final Widget body;
  final Widget? leading;
  final List<Widget>? actions;
  final bool centerTitle;
  final bool showBackButton;
  final VoidCallback? onBack;
  final Color backgroundColor;
  final Widget? background;
  final Widget? bottomNavigationBar;
  final bool extendBody;

  /// Si `extendBodyBehindAppBar` es true, el body arranca en y=0 y el primer
  /// elemento queda oculto detrás del app bar — solo activá si tu scrollable
  /// agrega `top: kToolbarHeight + systemTop` a su padding.
  final bool extendBodyBehindAppBar;

  const LiquidAppBarScaffold({
    super.key,
    required this.title,
    required this.body,
    this.leading,
    this.actions,
    this.centerTitle = false,
    this.showBackButton = false,
    this.onBack,
    this.backgroundColor = MonacoColors.background,
    this.background,
    this.bottomNavigationBar,
    this.extendBody = true,
    this.extendBodyBehindAppBar = false,
  });

  @override
  State<LiquidAppBarScaffold> createState() => _LiquidAppBarScaffoldState();
}

class _LiquidAppBarScaffoldState extends State<LiquidAppBarScaffold> {
  bool _scrolled = false;

  bool _handleScroll(ScrollNotification n) {
    final isScrolled = n.metrics.pixels > 4;
    if (isScrolled != _scrolled) {
      setState(() => _scrolled = isScrolled);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      extendBodyBehindAppBar: widget.extendBodyBehindAppBar,
      extendBody: widget.extendBody,
      appBar: LiquidAppBar(
        title: widget.title,
        leading: widget.leading,
        actions: widget.actions,
        centerTitle: widget.centerTitle,
        showBackButton: widget.showBackButton,
        onBack: widget.onBack,
        scrolled: _scrolled,
      ),
      bottomNavigationBar: widget.bottomNavigationBar,
      body: Stack(
        children: [
          if (widget.background != null)
            Positioned.fill(child: widget.background!),
          NotificationListener<ScrollNotification>(
            onNotification: _handleScroll,
            child: widget.body,
          ),
        ],
      ),
    );
  }
}
