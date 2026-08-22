import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/theme/monaco_theme.dart';
import 'package:monaco_mobile/features/home/presentation/widgets/occupancy_mini_card.dart';

/// La mini card tiene un LED que pulsa en loop (flutter_animate repeat), así
/// que NO se puede usar pumpAndSettle: se bombea un par de frames a mano.
///
/// Se carga Poppins de verdad: con la fuente de prueba (Ahem, glifos cuadrados
/// de 1 em) "Alta demanda" mide casi el doble y la pastilla desborda la card
/// de 160 px — un falso positivo que no existe en el teléfono.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final loader = FontLoader('Poppins');
    for (final f in ['Poppins-Regular', 'Poppins-Bold', 'Poppins-ExtraBold', 'Poppins-Black']) {
      final bytes = await File('assets/fonts/$f.ttf').readAsBytes();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  });

  Widget buildSubject({
    required String branchName,
    required String occupancyLevel,
    bool isOpen = true,
    int totalBarbers = 1,
    VoidCallback? onTap,
  }) {
    return MaterialApp(
      theme: MonacoTheme.dark,
      home: Scaffold(
        backgroundColor: MonacoColors.background,
        body: Center(
          child: OccupancyMiniCard(
            branchName: branchName,
            occupancyLevel: occupancyLevel,
            isOpen: isOpen,
            totalBarbers: totalBarbers,
            onTap: onTap,
          ),
        ),
      ),
    );
  }

  Future<void> pumpFrames(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Color? labelColor(WidgetTester tester, String label) =>
      tester.widget<Text>(find.text(label)).style?.color;

  group('OccupancyMiniCard', () {
    testWidgets('muestra el nombre de la sucursal', (tester) async {
      await tester.pumpWidget(buildSubject(
        branchName: 'Rondeau',
        occupancyLevel: 'baja',
      ));
      await pumpFrames(tester);
      expect(find.text('Rondeau'), findsOneWidget);
    });

    testWidgets('sin_espera → "Sin espera" en verde Monaco', (tester) async {
      await tester.pumpWidget(buildSubject(
        branchName: 'Parana',
        occupancyLevel: 'sin_espera',
      ));
      await pumpFrames(tester);
      expect(find.text('Sin espera'), findsOneWidget);
      expect(labelColor(tester, 'Sin espera'), MonacoColors.monacoGreen);
    });

    testWidgets('baja → "Espera corta" en lima', (tester) async {
      await tester.pumpWidget(buildSubject(
        branchName: 'Parana',
        occupancyLevel: 'baja',
      ));
      await pumpFrames(tester);
      expect(find.text('Espera corta'), findsOneWidget);
      expect(labelColor(tester, 'Espera corta'), const Color(0xFF84CC16));
    });

    testWidgets('media → "Movimiento" en ámbar', (tester) async {
      await tester.pumpWidget(buildSubject(
        branchName: 'Parana',
        occupancyLevel: 'media',
      ));
      await pumpFrames(tester);
      expect(find.text('Movimiento'), findsOneWidget);
      expect(labelColor(tester, 'Movimiento'), const Color(0xFFF59E0B));
    });

    testWidgets('alta → "Alta demanda" en rojo', (tester) async {
      await tester.pumpWidget(buildSubject(
        branchName: 'Parana',
        occupancyLevel: 'alta',
      ));
      await pumpFrames(tester);
      expect(find.text('Alta demanda'), findsOneWidget);
      expect(labelColor(tester, 'Alta demanda'), const Color(0xFFEF4444));
    });

    testWidgets('el nivel no distingue mayúsculas', (tester) async {
      await tester.pumpWidget(buildSubject(
        branchName: 'Parana',
        occupancyLevel: 'ALTA',
      ));
      await pumpFrames(tester);
      expect(find.text('Alta demanda'), findsOneWidget);
    });

    testWidgets('un nivel desconocido cae en "Sin espera"', (tester) async {
      await tester.pumpWidget(buildSubject(
        branchName: 'Parana',
        occupancyLevel: 'lo-que-sea',
      ));
      await pumpFrames(tester);
      expect(find.text('Sin espera'), findsOneWidget);
    });

    testWidgets('cerrada → "Cerrado" en gris, aunque el nivel diga alta',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        branchName: 'Caseros',
        occupancyLevel: 'alta',
        isOpen: false,
      ));
      await pumpFrames(tester);
      expect(find.text('Cerrado'), findsOneWidget);
      expect(find.text('Alta demanda'), findsNothing);
      expect(labelColor(tester, 'Cerrado'), const Color(0xFF6B6B6B));
    });

    testWidgets('abierta pero sin barberos en turno también es "Cerrado"',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        branchName: 'Caseros',
        occupancyLevel: 'baja',
        isOpen: true,
        totalBarbers: 0,
      ));
      await pumpFrames(tester);
      expect(find.text('Cerrado'), findsOneWidget);
    });

    testWidgets('onTap se dispara al tocar la card', (tester) async {
      var taps = 0;
      await tester.pumpWidget(buildSubject(
        branchName: 'Rondeau',
        occupancyLevel: 'baja',
        onTap: () => taps++,
      ));
      await pumpFrames(tester);
      await tester.tap(find.text('Rondeau'));
      await pumpFrames(tester);
      expect(taps, 1);
    });
  });
}
