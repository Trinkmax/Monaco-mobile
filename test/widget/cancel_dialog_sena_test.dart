import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:monaco_mobile/app/theme/monaco_theme.dart';
import 'package:monaco_mobile/features/appointments/data/appointment_model.dart';
import 'package:monaco_mobile/features/appointments/presentation/cancel_dialog.dart';
import 'package:monaco_mobile/features/senas/data/sena_models.dart';

/// El diálogo de cancelar un turno **con seña**.
///
/// Lo que se está midiendo es qué se le dice al cliente sobre su plata:
///  · con seña pagada, el monto tiene que aparecer;
///  · sin seña, ni una palabra de seña (la mayoría de los turnos no tiene);
///  · **nunca** una promesa de devolución: la app no sabe si corresponde
///    (`refund_on_early_cancel` es config de la sucursal y el cliente no la
///    lee), y `POST /api/mobile/turnos/cancel` contesta `{ok:true}` pelado.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_AR');
  });

  AppointmentDeposit sena(String status) => AppointmentDeposit(
        id: 'dep-1',
        estado: EstadoSena.desde(status),
        amount: 8000,
      );

  Widget harness(AppointmentDeposit? deposito, {VoidCallback? onAbierto}) {
    return MaterialApp(
      theme: MonacoTheme.dark,
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: TextButton(
              onPressed: () {
                onAbierto?.call();
                confirmCancelAppointment(
                  ctx,
                  summary: 'Jueves, 11 de septiembre · 16:00 · Parana',
                  cancellationMinHours: 2,
                  sena: deposito,
                );
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> abrir(WidgetTester t, AppointmentDeposit? deposito) async {
    await t.pumpWidget(harness(deposito));
    await t.tap(find.text('abrir'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }

  testWidgets('con seña pagada nombra el monto y no promete la devolución', (t) async {
    await abrir(t, sena('pagada'));

    expect(find.text('¿Seguro que querés cancelar?'), findsOneWidget);
    expect(find.textContaining('seña de'), findsOneWidget);
    expect(find.textContaining(r'$8.000'), findsOneWidget);
    expect(find.text('Ver política de cancelación'), findsOneWidget);

    // Lo que NO puede decir: la devolución la decide el server al cancelar.
    expect(find.textContaining('Te devolvemos'), findsNothing);
    expect(find.textContaining('te devolvemos'), findsNothing);
  });

  testWidgets('sin seña, el diálogo no habla de plata', (t) async {
    await abrir(t, null);

    expect(find.text('¿Seguro que querés cancelar?'), findsOneWidget);
    expect(find.textContaining('El horario se libera'), findsOneWidget);
    expect(find.textContaining('seña'), findsNothing);
  });

  testWidgets('una seña ya devuelta no reabre el tema', (t) async {
    await abrir(t, sena('devuelta'));
    expect(find.textContaining('seña'), findsNothing);
  });

  testWidgets('la seña no tapa la ventana de cancelación', (t) async {
    await abrir(t, sena('pagada'));
    expect(find.textContaining('Podés cancelar hasta 2 horas antes'), findsOneWidget);
    expect(find.text('Mantener turno'), findsOneWidget);
    expect(find.text('Sí, cancelar'), findsOneWidget);
  });
}
