import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/monaco_colors.dart';
import 'liquid_tokens.dart';

/// Campo de texto del lenguaje Liquid Glass: lámina translúcida, overline
/// opcional, prefijo/sufijo, borde que se enciende en verde al enfocar y
/// mensaje de error debajo.
class LiquidTextField extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hint;
  final String? helper;
  final String? errorText;
  final Widget? prefix;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final bool autofocus;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final int maxLines;
  final int? maxLength;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final TextStyle? style;
  final TextAlign textAlign;

  const LiquidTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.helper,
    this.errorText,
    this.prefix,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.autofocus = false,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines = 1,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.style,
    this.textAlign = TextAlign.start,
  });

  @override
  State<LiquidTextField> createState() => _LiquidTextFieldState();
}

class _LiquidTextFieldState extends State<LiquidTextField> {
  late final FocusNode _focus = widget.focusNode ?? FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  void _onFocus() {
    if (_focused != _focus.hasFocus) setState(() => _focused = _focus.hasFocus);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
    final borderColor = hasError
        ? MonacoColors.destructive.withValues(alpha: 0.8)
        : _focused
            ? MonacoColors.monacoGreen.withValues(alpha: 0.75)
            : Colors.white.withValues(alpha: 0.14);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              widget.label!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
        AnimatedContainer(
          duration: LiquidTokens.swap,
          curve: LiquidTokens.curveSwap,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(LiquidTokens.radiusSmall + 2),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: _focused ? 0.11 : 0.07),
                Colors.white.withValues(alpha: 0.03),
              ],
            ),
            border: Border.all(color: borderColor, width: _focused ? 1.2 : 0.8),
            boxShadow: _focused && !hasError
                ? [
                    BoxShadow(
                      color: MonacoColors.monacoGreen.withValues(alpha: 0.18),
                      blurRadius: 16,
                      spreadRadius: -4,
                    ),
                  ]
                : null,
          ),
          child: Row(
            crossAxisAlignment: widget.maxLines > 1
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              if (widget.prefix != null)
                Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: widget.prefix!,
                ),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  autofocus: widget.autofocus,
                  enabled: widget.enabled,
                  readOnly: widget.readOnly,
                  obscureText: widget.obscureText,
                  keyboardType: widget.keyboardType,
                  textInputAction: widget.textInputAction,
                  inputFormatters: widget.inputFormatters,
                  maxLines: widget.maxLines,
                  maxLength: widget.maxLength,
                  textAlign: widget.textAlign,
                  textCapitalization: widget.textCapitalization,
                  autofillHints: widget.autofillHints,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  onTap: widget.onTap,
                  cursorColor: MonacoColors.monacoGreen,
                  style: widget.style ??
                      const TextStyle(
                        color: MonacoColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: widget.hint,
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontWeight: FontWeight.w500,
                    ),
                    counterText: '',
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: widget.prefix != null ? 10 : 16,
                      vertical: widget.maxLines > 1 ? 14 : 16,
                    ),
                  ),
                ),
              ),
              if (widget.suffix != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: widget.suffix!,
                ),
            ],
          ),
        ),
        AnimatedSize(
          duration: LiquidTokens.swap,
          curve: LiquidTokens.curveSwap,
          alignment: Alignment.topLeft,
          child: hasError
              ? Padding(
                  padding: const EdgeInsets.only(left: 4, top: 7),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 14, color: MonacoColors.destructive),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          widget.errorText!,
                          style: const TextStyle(
                            color: MonacoColors.destructive,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : (widget.helper != null
                  ? Padding(
                      padding: const EdgeInsets.only(left: 4, top: 7),
                      child: Text(
                        widget.helper!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  : const SizedBox.shrink()),
        ),
      ],
    );
  }
}

/// Cajas para un código numérico (OTP / PIN). Una sola `TextField` invisible
/// maneja el teclado y el pegado; las cajas sólo dibujan. Llama `onCompleted`
/// cuando se llenan todas.
class LiquidCodeField extends StatefulWidget {
  final int length;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;
  final bool autofocus;
  final bool obscure;
  final bool enabled;
  final String? errorText;
  final TextEditingController? controller;
  final double boxSize;

  const LiquidCodeField({
    super.key,
    this.length = 6,
    this.onChanged,
    this.onCompleted,
    this.autofocus = true,
    this.obscure = false,
    this.enabled = true,
    this.errorText,
    this.controller,
    this.boxSize = 48,
  });

  @override
  State<LiquidCodeField> createState() => _LiquidCodeFieldState();
}

class _LiquidCodeFieldState extends State<LiquidCodeField> {
  late final TextEditingController _ctrl =
      widget.controller ?? TextEditingController();
  final _focus = FocusNode();
  String _value = '';

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onText);
    _focus.addListener(() => setState(() {}));
  }

  void _onText() {
    final digits = _ctrl.text.replaceAll(RegExp(r'\D'), '');
    final clipped =
        digits.length > widget.length ? digits.substring(0, widget.length) : digits;
    if (clipped != _ctrl.text) {
      _ctrl.value = TextEditingValue(
        text: clipped,
        selection: TextSelection.collapsed(offset: clipped.length),
      );
      return;
    }
    if (clipped == _value) return;
    setState(() => _value = clipped);
    widget.onChanged?.call(clipped);
    if (clipped.length == widget.length) {
      widget.onCompleted?.call(clipped);
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onText);
    if (widget.controller == null) _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _focus.requestFocus(),
          child: Stack(
            children: [
              // TextField invisible que captura el teclado/pegado.
              Positioned.fill(
                child: Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _focus,
                    autofocus: widget.autofocus,
                    enabled: widget.enabled,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    autofillHints: const [AutofillHints.oneTimeCode],
                    maxLength: widget.length,
                    decoration: const InputDecoration(
                      counterText: '',
                      border: InputBorder.none,
                    ),
                    showCursor: false,
                    enableInteractiveSelection: true,
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.length, (i) {
                  final char = i < _value.length ? _value[i] : '';
                  final isActive = _focus.hasFocus &&
                      (i == _value.length ||
                          (i == widget.length - 1 &&
                              _value.length == widget.length));
                  return _CodeBox(
                    char: widget.obscure && char.isNotEmpty ? '•' : char,
                    active: isActive,
                    error: hasError,
                    size: widget.boxSize,
                    last: i == widget.length - 1,
                  );
                }),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: LiquidTokens.swap,
          curve: LiquidTokens.curveSwap,
          child: hasError
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    widget.errorText!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: MonacoColors.destructive,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _CodeBox extends StatelessWidget {
  final String char;
  final bool active;
  final bool error;
  final double size;
  final bool last;

  const _CodeBox({
    required this.char,
    required this.active,
    required this.error,
    required this.size,
    required this.last,
  });

  @override
  Widget build(BuildContext context) {
    final border = error
        ? MonacoColors.destructive.withValues(alpha: 0.8)
        : active
            ? MonacoColors.monacoGreen.withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: char.isEmpty ? 0.14 : 0.28);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: size,
      height: size * 1.2,
      margin: EdgeInsets.only(right: last ? 0 : 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: active ? 0.14 : 0.08),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
        border: Border.all(color: border, width: active ? 1.4 : 0.9),
        boxShadow: active && !error
            ? [
                BoxShadow(
                  color: MonacoColors.monacoGreen.withValues(alpha: 0.22),
                  blurRadius: 16,
                  spreadRadius: -4,
                ),
              ]
            : null,
      ),
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 140),
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: Tween<double>(begin: 0.7, end: 1).animate(anim),
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: Text(
            char,
            key: ValueKey(char),
            style: const TextStyle(
              color: MonacoColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}
