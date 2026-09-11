import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:monaco_mobile/features/loyalty/data/loyalty_models.dart';
import 'package:monaco_mobile/features/loyalty/presentation/widgets/card_tilt.dart';
import 'package:monaco_mobile/features/loyalty/presentation/widgets/monaco_card.dart';

/// `MonacoCard` escucha el acelerómetro para mover el brillo de la tarjeta y
/// `sensors_plus` **no mira el ciclo de vida**: sin pausar, bloquear el
/// teléfono con el Home abierto dejaba el sensor muestreando a ~16 Hz en
/// background (Android 7-13, que es la gama baja del público) hasta que el
/// freezer del sistema lo pare.
///
/// En el host no hay plugins: `CardTilt.escuchar` devuelve `null` y la
/// suscripción que se pausaría no existe — el mismo caso que el simulador de
/// iOS, donde el acelerómetro tampoco está. Lo que este test fija es que ese
/// camino no tire nada, ni con la tarjeta montada ni **después** de
/// desmontarla (que es donde se paga olvidar el `removeObserver`: el binding
/// llamaría a `didChangeAppLifecycleState` sobre un `State` ya disposeado).
///
/// El pausado real del sensor sólo se puede ver en un equipo: banco de prueba
/// en `integration_test/wallet_preview_test.dart`.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    CardTilt.forzarSinSensor = true;
    await initializeDateFormatting('es');
    await initializeDateFormatting('es_AR');
  });

  final resumen = LoyaltySummary.disabled(clientName: 'Nacho', balance: 240);

  Widget envolver(Widget child) => MaterialApp(
        home: Scaffold(
          body: Center(child: SizedBox(width: 390, child: child)),
        ),
      );

  const transiciones = <AppLifecycleState>[
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ];

  testWidgets('la tarjeta sobrevive a irse a background y volver',
      (tester) async {
    await tester.pumpWidget(envolver(MonacoCard(summary: resumen, saldo: 240)));
    await tester.pump(const Duration(milliseconds: 100));

    for (final estado in transiciones) {
      tester.binding.handleAppLifecycleStateChanged(estado);
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull, reason: 'estado $estado');
    }

    expect(find.byType(MonacoCard), findsOneWidget);
  });

  testWidgets('desmontada, un cambio de ciclo de vida no la alcanza',
      (tester) async {
    await tester.pumpWidget(envolver(MonacoCard(summary: resumen, saldo: 240)));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.pumpWidget(envolver(const SizedBox.shrink()));
    await tester.pump();

    for (final estado in transiciones) {
      tester.binding.handleAppLifecycleStateChanged(estado);
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull, reason: 'estado $estado');
    }
  });

  testWidgets('la variante compact no escucha el sensor y tampoco se rompe',
      (tester) async {
    await tester.pumpWidget(
      envolver(MonacoCard(summary: resumen, saldo: 240, compact: true)),
    );
    await tester.pump(const Duration(milliseconds: 100));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(milliseconds: 50));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    expect(find.byType(MonacoCard), findsOneWidget);
  });
}
