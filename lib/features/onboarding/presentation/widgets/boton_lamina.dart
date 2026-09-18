import 'package:flutter/material.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';

/// Botón de 56 de alto a lo ancho: un glifo opcional a la izquierda ([glyph],
/// el logo del proveedor), un ícono opcional a la derecha ([trailing], la
/// flecha de "Continuar") y el texto centrado ópticamente.
///
/// [solido] = lámina blanca opaca. Sobre vidrio oscuro es lo que el ojo lee
/// como "esto se toca", así que se reserva para lo que la pantalla quiere que
/// se use: el "Continuar" del carrusel de bienvenida y **los sociales** (Google
/// y Apple con el mismo peso, que es lo que exige la HIG de Sign in with Apple)
/// o, cuando no hay ninguno, el del teléfono. Nunca dos láminas blancas
/// compitiendo con una tercera en la misma columna.
///
/// Es UN widget para la bienvenida y el muro de login a propósito: el
/// "Continuar" de las dos primeras láminas se convierte, en la tercera, en el
/// primer botón social **en el mismo lugar y con la misma lámina**, y eso sólo
/// se lee como una transformación si las dos superficies son idénticas.
class BotonLamina extends StatelessWidget {
  final String label;
  final Widget? glyph;
  final IconData? trailing;
  final bool solido;
  final bool cargando;
  final VoidCallback? onPressed;

  const BotonLamina({
    super.key,
    required this.label,
    required this.solido,
    required this.onPressed,
    this.glyph,
    this.trailing,
    this.cargando = false,
  });

  @override
  Widget build(BuildContext context) {
    final habilitado = onPressed != null && !cargando;
    final colorTexto = solido ? MonacoColors.background : Colors.white;

    final contenido = cargando
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: colorTexto,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (glyph != null) ...[glyph!, const SizedBox(width: 12)],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorTexto,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                Icon(trailing, size: 19, color: colorTexto),
              ],
            ],
          );

    return Semantics(
      button: true,
      enabled: habilitado,
      label: label,
      child: AnimatedOpacity(
        duration: LiquidTokens.swap,
        opacity: habilitado ? 1 : 0.55,
        child: SizedBox(
          height: 56,
          width: double.infinity,
          child: solido
              // `LiquidTapEffect.onTap` no es opcional: el gate del estado
              // deshabilitado lo pone el AbsorbPointer.
              ? AbsorbPointer(
                  absorbing: !habilitado,
                  child: LiquidTapEffect(
                    onTap: onPressed ?? () {},
                    borderRadius: BorderRadius.circular(18),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.34),
                            blurRadius: 16,
                            spreadRadius: -4,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(child: contenido),
                    ),
                  ),
                )
              : LiquidPill(
                  onTap: habilitado ? onPressed : null,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  borderRadius: 18,
                  tintOpacity: 0.08,
                  child: Center(child: contenido),
                ),
        ),
      ),
    );
  }
}
