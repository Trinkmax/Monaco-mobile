import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monaco_mobile/features/occupancy/presentation/widgets/barber_status_tile.dart';

void main() {
  Widget buildSubject({
    required String name,
    required String status,
    String? currentClientName,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: BarberStatusTile(
          name: name,
          status: status,
          currentClientName: currentClientName,
        ),
      ),
    );
  }

  group('BarberStatusTile', () {
    testWidgets('shows barber name', (tester) async {
      await tester.pumpWidget(buildSubject(
        name: 'Carlos Lopez',
        status: 'disponible',
      ));

      expect(find.text('Carlos Lopez'), findsOneWidget);
    });

    testWidgets('shows "Disponible" status text for disponible status',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        name: 'Juan Perez',
        status: 'disponible',
      ));

      expect(find.text('Disponible'), findsOneWidget);
    });

    testWidgets('shows "Ocupado" status text for ocupado status',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        name: 'Miguel Torres',
        status: 'ocupado',
      ));

      expect(find.text('Ocupado'), findsOneWidget);
    });

    testWidgets('shows "En descanso" status text for descanso status',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        name: 'Pedro Sanchez',
        status: 'descanso',
      ));

      expect(find.text('En descanso'), findsOneWidget);
    });

    testWidgets('disponible status uses green color', (tester) async {
      await tester.pumpWidget(buildSubject(
        name: 'Test Barber',
        status: 'disponible',
      ));

      final statusText = tester.widget<Text>(find.text('Disponible'));
      expect(statusText.style?.color, const Color(0xFF22C55E));
    });

    testWidgets('ocupado status uses amber color', (tester) async {
      await tester.pumpWidget(buildSubject(
        name: 'Test Barber',
        status: 'ocupado',
      ));

      final statusText = tester.widget<Text>(find.text('Ocupado'));
      expect(statusText.style?.color, const Color(0xFFF59E0B));
    });

    testWidgets('descanso status uses grey color', (tester) async {
      await tester.pumpWidget(buildSubject(
        name: 'Test Barber',
        status: 'descanso',
      ));

      final statusText = tester.widget<Text>(find.text('En descanso'));
      expect(statusText.style?.color, Colors.grey);
    });

    testWidgets('shows "Atendiendo a" text when ocupado with client name',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        name: 'Carlos Lopez',
        status: 'ocupado',
        currentClientName: 'Maria Garcia',
      ));

      expect(find.text('Atendiendo a Maria Garcia'), findsOneWidget);
    });

    testWidgets('does not show "Atendiendo a" when not ocupado',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        name: 'Carlos Lopez',
        status: 'disponible',
        currentClientName: 'Maria Garcia',
      ));

      expect(find.textContaining('Atendiendo'), findsNothing);
    });

    testWidgets('does not show "Atendiendo a" when client name is null',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        name: 'Carlos Lopez',
        status: 'ocupado',
        currentClientName: null,
      ));

      expect(find.textContaining('Atendiendo'), findsNothing);
    });

    testWidgets('does not show "Atendiendo a" when client name is empty',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        name: 'Carlos Lopez',
        status: 'ocupado',
        currentClientName: '',
      ));

      expect(find.textContaining('Atendiendo'), findsNothing);
    });

    testWidgets('shows initials in avatar for two-word name', (tester) async {
      await tester.pumpWidget(buildSubject(
        name: 'Carlos Lopez',
        status: 'disponible',
      ));

      // The avatar should show "CL"
      expect(find.text('CL'), findsOneWidget);
    });

    testWidgets('shows single initial for single-word name', (tester) async {
      await tester.pumpWidget(buildSubject(
        name: 'Carlos',
        status: 'disponible',
      ));

      // The avatar should show "C"
      expect(find.text('C'), findsOneWidget);
    });

    testWidgets('defaults to "Disponible" for unknown status', (tester) async {
      await tester.pumpWidget(buildSubject(
        name: 'Test Barber',
        status: 'unknown_status',
      ));

      expect(find.text('Disponible'), findsOneWidget);
    });
  });
}
