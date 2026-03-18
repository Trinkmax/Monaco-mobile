import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monaco_mobile/features/home/presentation/widgets/occupancy_mini_card.dart';

void main() {
  Widget buildSubject({
    required String branchName,
    required String occupancyLevel,
    required int etaMinutes,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 200,
          height: 200,
          child: OccupancyMiniCard(
            branchName: branchName,
            occupancyLevel: occupancyLevel,
            etaMinutes: etaMinutes,
          ),
        ),
      ),
    );
  }

  group('OccupancyMiniCard', () {
    testWidgets('shows branch name', (tester) async {
      await tester.pumpWidget(buildSubject(
        branchName: 'Sucursal Centro',
        occupancyLevel: 'baja',
        etaMinutes: 10,
      ));
      // pump again for flutter_animate animations
      await tester.pumpAndSettle();

      expect(find.text('Sucursal Centro'), findsOneWidget);
    });

    testWidgets('shows ETA in minutes when etaMinutes > 0', (tester) async {
      await tester.pumpWidget(buildSubject(
        branchName: 'Sucursal Norte',
        occupancyLevel: 'baja',
        etaMinutes: 15,
      ));
      await tester.pumpAndSettle();

      expect(find.text('~15 min'), findsOneWidget);
    });

    testWidgets('shows "Sin espera" when etaMinutes is 0', (tester) async {
      await tester.pumpWidget(buildSubject(
        branchName: 'Sucursal Sur',
        occupancyLevel: 'baja',
        etaMinutes: 0,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Sin espera'), findsOneWidget);
    });

    testWidgets('renders green color and "Baja" label for baja occupancy',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        branchName: 'Test Branch',
        occupancyLevel: 'baja',
        etaMinutes: 5,
      ));
      await tester.pumpAndSettle();

      // Verify the level label text
      expect(find.text('Baja'), findsOneWidget);

      // Verify the label color is green
      final labelWidget = tester.widget<Text>(find.text('Baja'));
      expect(labelWidget.style?.color, const Color(0xFF22C55E));
    });

    testWidgets('renders amber color and "Media" label for media occupancy',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        branchName: 'Test Branch',
        occupancyLevel: 'media',
        etaMinutes: 20,
      ));
      await tester.pumpAndSettle();

      // Verify the level label text
      expect(find.text('Media'), findsOneWidget);

      // Verify the label color is amber
      final labelWidget = tester.widget<Text>(find.text('Media'));
      expect(labelWidget.style?.color, const Color(0xFFF59E0B));
    });

    testWidgets('renders red color and "Alta" label for alta occupancy',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        branchName: 'Test Branch',
        occupancyLevel: 'alta',
        etaMinutes: 45,
      ));
      await tester.pumpAndSettle();

      // Verify the level label text
      expect(find.text('Alta'), findsOneWidget);

      // Verify the label color is red
      final labelWidget = tester.widget<Text>(find.text('Alta'));
      expect(labelWidget.style?.color, const Color(0xFFEF4444));
    });

    testWidgets('occupancy level matching is case-insensitive', (tester) async {
      await tester.pumpWidget(buildSubject(
        branchName: 'Test Branch',
        occupancyLevel: 'ALTA',
        etaMinutes: 30,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Alta'), findsOneWidget);
    });

    testWidgets('defaults to green/Baja for unknown occupancy level',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        branchName: 'Test Branch',
        occupancyLevel: 'unknown',
        etaMinutes: 10,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Baja'), findsOneWidget);

      final labelWidget = tester.widget<Text>(find.text('Baja'));
      expect(labelWidget.style?.color, const Color(0xFF22C55E));
    });
  });
}
