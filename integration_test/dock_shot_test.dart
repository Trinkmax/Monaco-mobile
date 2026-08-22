// Captura visual del dock Liquid Glass (shaders) sin login ni red.
//
//   QA_SHOTS_DIR=build/qa-shots flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/dock_shot_test.dart -d <udid-simulador>
//
// Pinta un fondo con contenido (texto + tarjetas de color) para que se vea la
// refracción de la barra y de la burbuja, y saca tres capturas: en reposo,
// a mitad de un arrastre y después de soltar en "Premios".

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:monaco_mobile/app/widgets/glass/liquid.dart';

Future<void> shot(IntegrationTestWidgetsFlutterBinding binding, WidgetTester tester, String name) async {
  await tester.pumpAndSettle(const Duration(milliseconds: 200));
  await binding.takeScreenshot(name);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('dock liquid glass — reposo, arrastre y soltar', (tester) async {
    int index = 0;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: const Color(0xFF0B0B0C),
            extendBody: true,
            body: Stack(
              children: [
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF0B0B0C), Color(0xFF10261A), Color(0xFF0B0B0C)],
                      ),
                    ),
                  ),
                ),
                ListView(
                  padding: const EdgeInsets.fromLTRB(20, 80, 20, 40),
                  children: [
                    const Text(
                      'Inicio',
                      style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 16),
                    for (var i = 0; i < 12; i++)
                      Container(
                        height: 72,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: [
                            const Color(0xFF22C55E),
                            const Color(0xFF3B82F6),
                            const Color(0xFFF59E0B),
                            Colors.white,
                          ][i % 4]
                              .withValues(alpha: 0.22),
                        ),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Tarjeta de prueba #$i · texto para ver la refracción del vidrio',
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            bottomNavigationBar: LiquidDock(
              items: const [
                LiquidDockItem(icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Inicio'),
                LiquidDockItem(icon: Icons.event_available_outlined, selectedIcon: Icons.event_available_rounded, label: 'Turnos'),
                LiquidDockItem(icon: Icons.storefront_outlined, selectedIcon: Icons.storefront_rounded, label: 'Sucursales'),
                LiquidDockItem(icon: Icons.card_giftcard_outlined, selectedIcon: Icons.card_giftcard_rounded, label: 'Premios'),
                LiquidDockItem(icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'Perfil'),
              ],
              currentIndex: index,
              onSelect: (i) => setState(() => index = i),
            ),
          ),
        ),
      ),
    );

    await shot(binding, tester, 'dock_01_reposo');

    // Arrastre: desde "Inicio" hacia la derecha, capturando a mitad de camino.
    final dock = find.byType(LiquidDock);
    final rect = tester.getRect(dock);
    final start = Offset(rect.left + rect.width * 0.10, rect.center.dy);
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 50));
    for (var i = 1; i <= 10; i++) {
      await gesture.moveBy(Offset(rect.width * 0.045, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 100));
    await binding.takeScreenshot('dock_02_arrastre');

    for (var i = 1; i <= 8; i++) {
      await gesture.moveBy(Offset(rect.width * 0.03, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await shot(binding, tester, 'dock_03_soltado');
    expect(index, greaterThan(0));

    // Toque directo en "Perfil".
    await tester.tap(find.text('Perfil'));
    await shot(binding, tester, 'dock_04_tap_perfil');
    expect(index, 4);
  });
}
