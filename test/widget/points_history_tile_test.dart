import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/features/points/presentation/widgets/points_history_tile.dart';

void main() {
  // `Formatters.relativeTime` cae en `DateFormat(..., 'es')` para cualquier
  // movimiento de más de una semana, y ese constructor TIRA si el locale no
  // está inicializado. Los tests con `created_at` viejo fallaban por eso, no
  // por el widget.
  setUpAll(() async {
    await initializeDateFormatting('es');
    await initializeDateFormatting('es_AR');
  });

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
      expect(find.byIcon(Icons.redeem_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward_rounded), findsNothing);
    });

    testWidgets('cada type de la mig 196 tiene su ícono', (tester) async {
      const esperado = {
        'earned': Icons.content_cut_rounded,
        'welcome_bonus': Icons.card_giftcard_rounded,
        'referral_referrer': Icons.person_add_rounded,
        'referral_referred': Icons.person_add_rounded,
        'redeemed': Icons.redeem_rounded,
        'expired': Icons.hourglass_disabled_rounded,
        'reversal': Icons.undo_rounded,
        'manual_adjust': Icons.tune_rounded,
      };
      for (final e in esperado.entries) {
        await tester.pumpWidget(buildSubject({'points': 10, 'type': e.key}));
        expect(find.byIcon(e.value), findsOneWidget, reason: e.key);
      }
    });

    testWidgets('un lote vivo dice cuándo vence y cuánto queda', (tester) async {
      final ahora = DateTime(2026, 8, 30, 12);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          backgroundColor: MonacoColors.background,
          body: PointsHistoryTile(
            ahora: ahora,
            transaction: {
              'points': 100,
              'remaining': 80,
              'type': 'earned',
              'description': 'Corte en Rondeau',
              'created_at': ahora.subtract(const Duration(days: 2)).toIso8601String(),
              'expires_at': ahora.add(const Duration(days: 40)).toIso8601String(),
              'is_expired': false,
            },
          ),
        ),
      ));
      expect(find.textContaining('Vence en 40 días · quedan 80'), findsOneWidget);
      expect(find.text('+100'), findsOneWidget);
      expect(tester.widget<Text>(find.text('+100')).style?.color,
          MonacoColors.monacoGreen);
    });

    testWidgets('miles con separador es_AR: +2.000 y quedan 1.200',
        (tester) async {
      final ahora = DateTime(2026, 8, 30, 12);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          backgroundColor: MonacoColors.background,
          body: PointsHistoryTile(
            ahora: ahora,
            transaction: {
              'points': 2000,
              'remaining': 1200,
              'type': 'manual_adjust',
              'description': 'Ajuste manual',
              'created_at':
                  ahora.subtract(const Duration(days: 1)).toIso8601String(),
              'expires_at':
                  ahora.add(const Duration(days: 120)).toIso8601String(),
              'is_expired': false,
            },
          ),
        ),
      ));
      expect(find.text('+2.000'), findsOneWidget);
      expect(find.textContaining('quedan 1.200'), findsOneWidget);
    });

    testWidgets('un lote entero no dice "quedan" (no se consumió nada)',
        (tester) async {
      final ahora = DateTime(2026, 8, 30, 12);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PointsHistoryTile(
            ahora: ahora,
            transaction: {
              'points': 100,
              'remaining': 100,
              'type': 'earned',
              'expires_at': ahora.add(const Duration(days: 12)).toIso8601String(),
            },
          ),
        ),
      ));
      expect(find.textContaining('Vence en 12 días'), findsOneWidget);
      expect(find.textContaining('quedan'), findsNothing);
    });

    testWidgets('un lote vencido (is_expired) se atenúa y se pinta gris',
        (tester) async {
      await tester.pumpWidget(buildSubject({
        'points': 100,
        'remaining': 0,
        'type': 'earned',
        'description': 'Corte viejo',
        'expires_at': '2026-01-01T12:00:00Z',
        'is_expired': true,
      }));
      expect(find.textContaining('Vencido'), findsOneWidget);
      final color = tester.widget<Text>(find.text('+100')).style?.color;
      expect(color, isNot(MonacoColors.monacoGreen));
      expect(color, isNot(MonacoColors.destructive));
      final opacity = tester.widget<Opacity>(find.byType(Opacity).first);
      expect(opacity.opacity, lessThan(1));
    });

    testWidgets('un lote revertido dice "Revertido", no "Ya usado"', (tester) async {
      // `loyalty_reverse_lot` deja remaining = 0 y marca el meta; la RPC no
      // expone reversed_by y is_expired es falso para estos lotes.
      await tester.pumpWidget(buildSubject({
        'points': 100,
        'remaining': 0,
        'type': 'earned',
        'description': 'Puntos por tu visita',
        'expires_at': '2099-01-01T12:00:00Z',
        'is_expired': false,
        'meta': {'reversal_reason': 'visita anulada', 'reversed_at': '2026-08-30T12:00:00Z'},
      }));
      expect(find.textContaining('Revertido'), findsOneWidget);
      expect(find.textContaining('Ya usado'), findsNothing);
      final opacity = tester.widget<Opacity>(find.byType(Opacity).first);
      expect(opacity.opacity, lessThan(1));
    });

    testWidgets('un lote consumido entero dice "Ya usado"', (tester) async {
      await tester.pumpWidget(buildSubject({
        'points': 100,
        'remaining': 0,
        'type': 'earned',
        'expires_at': '2099-01-01T12:00:00Z',
        'is_expired': false,
        'meta': {},
      }));
      expect(find.textContaining('Ya usado'), findsOneWidget);
    });

    testWidgets('un movimiento negativo no tiene vencimiento', (tester) async {
      await tester.pumpWidget(buildSubject({
        'points': -50,
        'type': 'redeemed',
        'expires_at': '2099-01-01T12:00:00Z',
      }));
      expect(find.textContaining('Vence'), findsNothing);
      expect(find.text('-50'), findsOneWidget);
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
