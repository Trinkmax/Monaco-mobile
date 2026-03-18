import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monaco_mobile/features/points/presentation/widgets/points_history_tile.dart';

void main() {
  Widget buildSubject(Map<String, dynamic> transaction) {
    return MaterialApp(
      home: Scaffold(
        body: PointsHistoryTile(transaction: transaction),
      ),
    );
  }

  group('PointsHistoryTile', () {
    testWidgets('renders green up-arrow and + prefix for earned transactions',
        (tester) async {
      await tester.pumpWidget(buildSubject({
        'points': 50,
        'description': 'Earned from visit',
        'created_at': DateTime.now().toIso8601String(),
      }));

      // Verify the up-arrow icon is present
      final iconFinder = find.byIcon(Icons.arrow_upward_rounded);
      expect(iconFinder, findsOneWidget);

      // Verify the icon color is the success green
      final icon = tester.widget<Icon>(iconFinder);
      expect(icon.color, const Color(0xFF30A46C));

      // Verify the points text shows + prefix
      expect(find.text('+50 pts'), findsOneWidget);
    });

    testWidgets('renders red down-arrow and no + prefix for redeemed transactions',
        (tester) async {
      await tester.pumpWidget(buildSubject({
        'points': -30,
        'description': 'Redeemed for discount',
        'created_at': DateTime.now().toIso8601String(),
      }));

      // Verify the down-arrow icon is present
      final iconFinder = find.byIcon(Icons.arrow_downward_rounded);
      expect(iconFinder, findsOneWidget);

      // Verify the icon color is the destructive red
      final icon = tester.widget<Icon>(iconFinder);
      expect(icon.color, const Color(0xFFE5484D));

      // Verify the points text shows negative value without extra + prefix
      expect(find.text('-30 pts'), findsOneWidget);
    });

    testWidgets('shows the description text', (tester) async {
      await tester.pumpWidget(buildSubject({
        'points': 100,
        'description': 'Bonus points for referral',
        'created_at': DateTime.now().toIso8601String(),
      }));

      expect(find.text('Bonus points for referral'), findsOneWidget);
    });

    testWidgets('shows formatted points value for earned', (tester) async {
      await tester.pumpWidget(buildSubject({
        'points': 250,
        'description': 'Big reward',
      }));

      expect(find.text('+250 pts'), findsOneWidget);
    });

    testWidgets('shows formatted points value for redeemed', (tester) async {
      await tester.pumpWidget(buildSubject({
        'points': -75,
        'description': 'Used points',
      }));

      expect(find.text('-75 pts'), findsOneWidget);
    });

    testWidgets('handles zero points as not earned (down arrow)', (tester) async {
      await tester.pumpWidget(buildSubject({
        'points': 0,
        'description': 'Zero transaction',
      }));

      // Zero is not > 0, so isEarned = false -> down arrow
      expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
      expect(find.text('0 pts'), findsOneWidget);
    });

    testWidgets('handles missing description gracefully', (tester) async {
      await tester.pumpWidget(buildSubject({
        'points': 10,
      }));

      // Description defaults to empty string; widget still renders
      expect(find.text('+10 pts'), findsOneWidget);
    });

    testWidgets('earned points text uses success color', (tester) async {
      await tester.pumpWidget(buildSubject({
        'points': 20,
        'description': 'Test',
      }));

      final textWidget = tester.widget<Text>(find.text('+20 pts'));
      expect(textWidget.style?.color, const Color(0xFF30A46C));
    });

    testWidgets('redeemed points text uses destructive color', (tester) async {
      await tester.pumpWidget(buildSubject({
        'points': -20,
        'description': 'Test',
      }));

      final textWidget = tester.widget<Text>(find.text('-20 pts'));
      expect(textWidget.style?.color, const Color(0xFFE5484D));
    });
  });
}
