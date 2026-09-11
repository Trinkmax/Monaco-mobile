import 'package:flutter/material.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/theme/monaco_theme.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';

import '../widgets/onboarding_scaffold.dart';

/// Lo que se muestra cuando el arranque falla **antes** de que exista la app
/// (Supabase no se pudo inicializar ni después de limpiar el almacenamiento
/// seguro). Es un `MaterialApp` propio, sin Riverpod ni router: no puede
/// depender de nada de lo que justamente no pudo arrancar.
///
/// Existe por una regla: **nunca pantalla negra.** Antes, una excepción acá
/// dejaba a `runApp` sin correr y el cliente veía la app "abrirse y quedarse en
/// negro" en cada intento, sin ningún texto ni botón. Con esto ve qué pasó, en
/// español, y tiene un "Reintentar" que vuelve a correr el arranque entero.
class ArranqueFallidoApp extends StatefulWidget {
  /// Vuelve a intentar el arranque. Si sale bien, quien lo implementa llama a
  /// `runApp` con la app real y esta pantalla desaparece sola.
  final Future<void> Function() onReintentar;

  const ArranqueFallidoApp({super.key, required this.onReintentar});

  @override
  State<ArranqueFallidoApp> createState() => _ArranqueFallidoAppState();
}

class _ArranqueFallidoAppState extends State<ArranqueFallidoApp> {
  bool _reintentando = false;

  Future<void> _reintentar() async {
    if (_reintentando) return;
    setState(() => _reintentando = true);
    try {
      await widget.onReintentar();
    } finally {
      if (mounted) setState(() => _reintentando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Monaco',
      debugShowCheckedModeBanner: false,
      theme: MonacoTheme.dark,
      darkTheme: MonacoTheme.dark,
      themeMode: ThemeMode.dark,
      home: OnboardingScaffold(
        centered: true,
        child: _reintentando
            ? const Center(
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    color: Colors.white,
                  ),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const MonacoLogo.monogram(width: 54),
                  const SizedBox(height: 30),
                  LiquidErrorState(
                    scrollable: false,
                    title: 'No pudimos abrir la app',
                    message:
                        'Algo falló al arrancar. Probá de nuevo; si sigue '
                        'pasando, cerrá la app del todo y volvé a abrirla.',
                    onRetry: _reintentar,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Monaco Barber Studio',
                    style: TextStyle(
                      color: MonacoColors.textPrimary.withValues(alpha: 0.35),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
