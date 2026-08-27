import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:monaco_mobile/core/supabase/supabase_provider.dart';
import 'package:monaco_mobile/features/convenios/providers/convenios_provider.dart';
import 'package:monaco_mobile/features/points/providers/points_provider.dart';
import 'package:monaco_mobile/features/rewards/data/premio_item.dart';
import 'package:monaco_mobile/features/rewards/providers/rewards_provider.dart';

/// Catálogo canjeable de la barbería (`reward_catalog`).
///
/// No filtra por `organization_id`: lo contiene la RLS de clientes (mig 192).
/// Tampoco filtra por `valid_until` — históricamente no lo hacía y hay premios
/// vivos con la fecha vencida cargada por error; filtrarlos acá dejaría el
/// catálogo de Monaco en cero.
final catalogoPremiosProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final res = await supabase
      .from('reward_catalog')
      .select()
      .eq('is_active', true)
      .gt('points_cost', 0)
      .order('points_cost');
  return (res as List).map((e) => Map<String, dynamic>.from(e)).toList();
});

/// Saldo de puntos global del cliente (`get_client_global_points`).
///
/// Es el mismo dato que `globalPointsProvider`, pero como `int` pelado: lo leen
/// la tarjeta de puntos del Home y la pastilla de Premios, que sólo necesitan el
/// número. Se invalidan juntos al canjear.
final saldoPuntosProvider = Provider<AsyncValue<int>>((ref) {
  return ref.watch(globalPointsProvider).whenData(
        (m) => (m['total_balance'] as num?)?.toInt() ?? 0,
      );
});

/// **La grilla de Premios**: catálogo + convenios, con la categoría ya resuelta.
///
/// Los convenios vencidos NO entran: un beneficio que el comercio ya no honra
/// es ruido, y el chip "Marcas" con un solo ítem vencido se lee como que la
/// sección está rota. La pantalla `/convenios` sigue mostrando todo.
///
/// Orden: primero lo que el cliente **puede** usar hoy (le alcanza el saldo o
/// es gratis), y dentro de cada grupo lo más barato primero. Una grilla que
/// arranca con tres premios bloqueados desalienta; una que arranca con lo que
/// ya se ganó, invita.
final premiosProvider = Provider<AsyncValue<List<PremioItem>>>((ref) {
  final catalogo = ref.watch(catalogoPremiosProvider);
  final convenios = ref.watch(conveniosProvider);
  final saldo = ref.watch(saldoPuntosProvider).valueOrNull ?? 0;

  // Si el catálogo falló, la pantalla es un error. Si sólo fallaron los
  // convenios, se muestran los premios igual: perder las Marcas no puede
  // llevarse puesta la pantalla entera.
  if (catalogo.isLoading && !catalogo.hasValue) return const AsyncValue.loading();
  if (catalogo.hasError && !catalogo.hasValue) {
    return AsyncValue.error(catalogo.error!, catalogo.stackTrace ?? StackTrace.current);
  }

  final ahora = DateTime.now();
  final items = <PremioItem>[
    for (final row in catalogo.value ?? const <Map<String, dynamic>>[])
      PremioItem.deCatalogo(row),
    for (final row in convenios.valueOrNull ?? const <Map<String, dynamic>>[])
      PremioItem.deConvenio(row),
  ].where((p) {
    if (p.origen != PremioOrigen.convenio) return true;
    final hasta = p.validoHasta;
    return hasta == null || hasta.isAfter(ahora);
  }).toList();

  items.sort((a, b) {
    final aPuede = a.alcanza(saldo) && !a.agotado;
    final bPuede = b.alcanza(saldo) && !b.agotado;
    if (aPuede != bPuede) return aPuede ? -1 : 1;
    // Dentro de lo disponible, **primero los premios de la barbería**. Los
    // convenios son gratis, así que ordenando sólo por precio se quedaban con
    // toda la primera fila y una sección titulada "Canjeá tus puntos" abría con
    // tres tarjetas que dicen GRATIS.
    if (a.origen != b.origen) {
      return a.origen == PremioOrigen.catalogo ? -1 : 1;
    }
    final ap = a.puntos ?? 0;
    final bp = b.puntos ?? 0;
    if (ap != bp) return ap.compareTo(bp);
    return a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
  });

  return AsyncValue.data(items);
});

/// Las categorías que **tienen** algo. Dibujar "Merch" vacío para que el cliente
/// lo toque y encuentre la nada es peor que no ofrecerlo: los chips salen de los
/// datos, no de una lista fija.
final categoriasConPremiosProvider = Provider<List<PremioCategoria>>((ref) {
  final items = ref.watch(premiosProvider).valueOrNull ?? const <PremioItem>[];
  final presentes = items.map((p) => p.categoria).toSet();
  return [
    for (final c in PremioCategoria.values)
      if (presentes.contains(c)) c,
  ];
});

/// Premios ya canjeados y **listos para usar** en el local (la tira de arriba).
/// Salen de `get_client_wallet`, que desde la mig 194 devuelve también
/// `image_url`, `points_cost` y `category`.
final premiosListosProvider = Provider<AsyncValue<List<Map<String, dynamic>>>>((ref) {
  return ref.watch(clientWalletProvider).whenData(
        (list) => list.where((r) => r['status'] == 'available').toList(),
      );
});

/// El premio del catálogo **más cercano** que el cliente todavía no puede
/// canjear. Es lo que alimenta la línea "A N pts de …" de la tarjeta de puntos del
/// Home: se deriva del catálogo real, así que si mañana cargan "Corte gratis"
/// a 300 pts, la línea pasa a decir eso sola. `null` = no hay catálogo, o ya le
/// alcanza para todo (y entonces la tarjeta dice otra cosa).
final proximoPremioProvider = Provider<PremioItem?>((ref) {
  final items = ref.watch(premiosProvider).valueOrNull;
  if (items == null) return null;
  final saldo = ref.watch(saldoPuntosProvider).valueOrNull ?? 0;
  PremioItem? mejor;
  for (final p in items) {
    if (p.esGratis || p.agotado) continue;
    if (p.alcanza(saldo)) continue;
    if (mejor == null || p.puntos! < mejor.puntos!) mejor = p;
  }
  return mejor;
});

/// Cuántos premios del catálogo puede canjear YA. Con esto la tarjeta de puntos
/// puede decir "Podés canjear 2 premios" en vez de una barra al 100%.
final premiosCanjeablesProvider = Provider<int>((ref) {
  final items = ref.watch(premiosProvider).valueOrNull;
  if (items == null) return 0;
  final saldo = ref.watch(saldoPuntosProvider).valueOrNull ?? 0;
  return items
      .where((p) => !p.esGratis && !p.agotado && p.alcanza(saldo))
      .length;
});

/// Invalida TODO lo que cambia después de un canje. Vive acá y no en la
/// pantalla para que ningún camino nuevo se olvide de alguno: un saldo
/// desactualizado deja al cliente canjeando dos veces el mismo premio.
void invalidarTrasCanje(WidgetRef ref) {
  ref.invalidate(catalogoPremiosProvider);
  ref.invalidate(globalPointsProvider);
  ref.invalidate(pointsHistoryProvider);
  ref.invalidate(branchPointsProvider);
  ref.invalidate(clientWalletProvider);
}
