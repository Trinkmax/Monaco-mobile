import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid_dock.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid_glass_capability.dart';

/// El dock es el 100 % de la navegación y lo dibuja un paquete experimental
/// (`liquid_glass_renderer 0.2.0-dev.4`). Estos tests fijan que exista un
/// camino sin shader y que el dock siga siendo un dock cuando se toma.
void main() {
  const items = <LiquidDockItem>[
    LiquidDockItem(icon: Icons.home_outlined, label: 'Inicio'),
    LiquidDockItem(icon: Icons.event_available_outlined, label: 'Turnos'),
    LiquidDockItem(icon: Icons.storefront_outlined, label: 'Sucursales'),
    LiquidDockItem(icon: Icons.card_giftcard_outlined, label: 'Premios'),
    LiquidDockItem(icon: Icons.person_outline_rounded, label: 'Perfil'),
  ];

  Widget app({required int index, ValueChanged<int>? onSelect}) => MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF0A0A0A),
          bottomNavigationBar: LiquidDock(
            items: items,
            currentIndex: index,
            onSelect: onSelect ?? (_) {},
          ),
        ),
      );

  tearDown(LiquidGlassCapability.reiniciarParaTests);

  testWidgets('con el vidrio apagado el dock renderiza sin excepción y usa FakeGlass',
      (tester) async {
    LiquidGlassCapability.apagar('test');

    await tester.pumpWidget(app(index: 0));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    // Barra + burbuja + el warmup no está acá: dos piezas de vidrio simple.
    expect(find.byType(FakeGlass), findsNWidgets(2));
    for (final it in items) {
      expect(find.text(it.label), findsOneWidget);
    }
  });

  testWidgets('el dock sigue navegando con el vidrio apagado', (tester) async {
    LiquidGlassCapability.apagar('test');
    var elegido = -1;

    await tester.pumpWidget(app(index: 0, onSelect: (i) => elegido = i));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Premios'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(elegido, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('apagar el vidrio en runtime repinta el dock sin reconstruirlo',
      (tester) async {
    // Ojo: en el host `ImageFilter.isShaderFilterSupported` es false, así que
    // el propio paquete cae a FakeGlass aunque nuestro interruptor esté
    // prendido. Lo que se mide acá es lo que NOSOTROS decidimos: el `fake:`
    // que le pasamos a `LiquidGlass.withOwnLayer`.
    List<bool> fakes() => tester
        .widgetList<LiquidGlass>(find.byType(LiquidGlass))
        .map((w) => w.ownLayerConfig!.$2)
        .toList();

    LiquidGlassCapability.reiniciarParaTests();
    await tester.pumpWidget(app(index: 0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(fakes(), everyElement(isFalse), reason: 'barra + burbuja con shader');

    LiquidGlassCapability.apagar('el shader no compiló');
    await tester.pump();

    expect(fakes(), <bool>[true, true]);
    expect(LiquidGlassCapability.activo, isFalse);
    expect(LiquidGlassCapability.motivo, 'el shader no compiló');
    expect(tester.takeException(), isNull);
  });

  test('calentar() nunca tira, aunque el shader no exista', () async {
    LiquidGlassCapability.reiniciarParaTests();
    // En el host los .frag del paquete no están empaquetados: la carga falla y
    // el interruptor tiene que quedar en apagado, no propagar la excepción.
    await expectLater(LiquidGlassCapability.calentar(), completes);
    LiquidGlassCapability.reiniciarParaTests();
  });

  test('prender() vuelve a habilitarlo si el build lo permite', () {
    LiquidGlassCapability.apagar('test');
    expect(LiquidGlassCapability.activo, isFalse);

    LiquidGlassCapability.prender();
    expect(
      LiquidGlassCapability.activo,
      LiquidGlassCapability.permitidoEnElBuild,
    );
  });
}
