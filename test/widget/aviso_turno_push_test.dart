import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:monaco_mobile/app/theme/monaco_theme.dart';
import 'package:monaco_mobile/features/appointments/presentation/widgets/aviso_turno_push.dart';

/// El pedido contextual del permiso de notificaciones, después de reservar.
///
/// Acá sólo se puede verificar el guard que hoy está activo en producción —**y
/// es el que más importa para App Review**—: mientras `firebase_options.dart`
/// tenga los placeholders, `PushService.isAvailable` es `false` y la app no
/// puede mostrar nada. Un diálogo que pide un permiso que después no se puede
/// pedir es exactamente la clase de pantalla muerta que rechaza la guideline
/// 2.1.
///
/// El resto de la cadena (permiso `sinPedir` → pre-prompt → prompt nativo)
/// necesita FCM vivo y se prueba en el dispositivo.
void main() {
  testWidgets('sin Firebase configurado no aparece ningún diálogo', (t) async {
    await t.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: MonacoTheme.dark,
          home: Scaffold(
            body: Consumer(
              builder: (ctx, ref, _) => Center(
                child: TextButton(
                  onPressed: () => ofrecerAvisosDeTurno(ctx, ref),
                  child: const Text('reservar'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await t.tap(find.text('reservar'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));

    expect(find.text('¿Te recordamos el turno?'), findsNothing);
    expect(find.text('Sí, avisame'), findsNothing);
  });
}
