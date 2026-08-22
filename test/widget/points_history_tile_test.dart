import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/features/points/presentation/widgets/points_history_tile.dart';

void main() {
  Widget buildSubject(Map<String, dynamic> transaction) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: MonacoColors.background,
        body: PointsHistoryTile(transaction: transaction),
      ),
    );
  }

  group('PointsHistoryTile', () {
    testWidgets('puntos ganados: flecha arriba verde y prefijo +', (tester) async {
      await tester.pumpWidget(buildSubject({
        'points': 50,
        'description': 'Corte en Rondeau',
        'created_at': DateTime.now().toIso8601String(),
      }));

      final iconFinder = find.byIcon(Icons.arrow_upward_rounded);
      expect(iconFinder, findsOneWidget);
      expect(tester.widget<Icon>(iconFinder).color, MonacoColors.monacoGreen);
      expect(find.text('+50'), findsOneWidget);
      expect(find.text('pts'), findsOneWidget);
      expect(tester.widget<Text>(find.text('+50')).style?.color,
          MonacoColors.monacoGreen);
    });

    testWidgets('puntos canjeados: flecha abajo roja y sin prefijo +',
        (tester) async {
      await tester.pumpWidget(buildSubject({
        'points': -30,
        'description': 'Canje de premio',
        'created_at': DateTime.now().toIso8601String(),
      }));

      final iconFinder = find.byIcon(Icons.arrow_downward_rounded);
      expect(iconFinder, findsOneWidget);
      expect(tester.widget<Icon>(iconFinder).color, MonacoColors.destructive);
      expect(find.text('-30'), findsOneWidget);
      expect(tester.widget<Text>(find.text('-30')).style?.color,
          MonacoColors.destructive);
    });

    testWidgets('el tipo elige el ícono aunque el delta sea negativo',
        (tester) async {
      await tester.pumpWidget(buildSubject({
        'points': -300,
        'type': 'redeemed',
        'description': 'Canje',
      }));
      expect(find.byIcon(Icons.card_giftcard_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward_rounded), findsNothing);
    });

    testWidgets('muestra la descripción', (tester) async {
      await tester.pumpWidget(buildSubject({
        'points': 100,
        'description': 'Bono por referido',
        'created_at': DateTime.now().toIso8601String(),
      }));
      expect(find.text('Bono por referido'), findsOneWidget);
    });

    testWidgets('sin descripción usa un texto según el tipo', (tester) async {
      await tester.pumpWidget(buildSubject({'points': 10, 'type': 'visit'}));
      expect(find.text('Puntos por tu visita'), findsOneWidget);

      await tester.pumpWidget(buildSubject({'points': -10, 'type': 'redeemed'}));
      expect(find.text('Canje de premio'), findsOneWidget);

      await tester.pumpWidget(buildSubject({'points': 10}));
      expect(find.text('Movimiento de puntos'), findsOneWidget);
    });

    testWidgets('cero puntos se muestra como +0 (no es un canje)', (tester) async {
      await tester.pumpWidget(buildSubject({
        'points': 0,
        'description': 'Movimiento nulo',
      }));
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
      expect(find.text('+0'), findsOneWidget);
    });

    testWidgets('sin descripción ni fecha igual renderiza', (tester) async {
      await tester.pumpWidget(buildSubject({'points': 10}));
      expect(find.text('+10'), findsOneWidget);
    });

    testWidgets('points como num decimal se redondea a entero', (tester) async {
      await tester.pumpWidget(buildSubject({'points': 25.0, 'description': 'x'}));
      expect(find.text('+25'), findsOneWidget);
    });
  });
}
