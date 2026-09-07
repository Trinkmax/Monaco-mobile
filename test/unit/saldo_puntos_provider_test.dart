import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:monaco_mobile/features/loyalty/data/loyalty_models.dart';
import 'package:monaco_mobile/features/loyalty/providers/loyalty_provider.dart';
import 'package:monaco_mobile/features/rewards/providers/premios_provider.dart';

/// `saldoPuntosProvider` deriva de `loyaltyProvider` y tiene que conservar el
/// ÚLTIMO SALDO BUENO mientras se refresca y cuando el refresh falla. Con
/// `whenData` a secas, un pull-to-refresh con la red caída dejaba la tarjeta
/// del Home en "0 PUNTOS" y la grilla diciendo "Te faltan N pts" en todo.
void main() {
  final resumen = LoyaltySummary.fromJson({
    'program': {'enabled': true},
    'client': {'id': 'c1', 'name': 'Nacho'},
    'points': {'balance': 650},
    'tiers': const [],
  });

  test('conserva el saldo durante el refresh y tras un refresh fallido', () async {
    final falla = StateProvider<bool>((_) => false);
    final container = ProviderContainer(overrides: [
      loyaltyProvider.overrideWith((ref) async {
        if (ref.watch(falla)) throw Exception('red caída');
        return resumen;
      }),
    ]);
    addTearDown(container.dispose);
    container.listen(saldoPuntosProvider, (_, _) {});

    await container.read(loyaltyProvider.future);
    expect(container.read(saldoPuntosProvider).valueOrNull, 650);

    // Refresh que falla: el resumen viejo sigue vivo en loyaltyProvider…
    container.read(falla.notifier).state = true;
    // …y mientras carga, el saldo derivado no cae a null.
    final cargando = container.read(saldoPuntosProvider);
    expect(cargando.isLoading, isTrue);
    expect(cargando.valueOrNull, 650);

    await expectLater(container.read(loyaltyProvider.future), throwsException);
    final conError = container.read(saldoPuntosProvider);
    expect(container.read(loyaltyProvider).valueOrNull?.points.balance, 650);
    expect(conError.hasError, isTrue);
    expect(conError.valueOrNull, 650, reason: 'el último saldo bueno se conserva');
  });

  test('sin valor previo, un error sigue siendo un error (sin saldo)', () async {
    final container = ProviderContainer(overrides: [
      loyaltyProvider.overrideWith((ref) async => throw Exception('red caída')),
    ]);
    addTearDown(container.dispose);
    container.listen(saldoPuntosProvider, (_, _) {});
    await expectLater(container.read(loyaltyProvider.future), throwsException);
    final s = container.read(saldoPuntosProvider);
    expect(s.hasError, isTrue);
    expect(s.valueOrNull, isNull);
  });
}
