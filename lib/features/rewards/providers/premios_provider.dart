import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:monaco_mobile/core/auth/auth_provider.dart';
import 'package:monaco_mobile/core/supabase/supabase_provider.dart';
import 'package:monaco_mobile/features/convenios/providers/convenios_provider.dart';
import 'package:monaco_mobile/features/loyalty/providers/loyalty_provider.dart';
import 'package:monaco_mobile/features/loyalty/providers/referral_provider.dart';
import 'package:monaco_mobile/features/points/providers/points_provider.dart'
    show pointsHistoryProvider;
import 'package:monaco_mobile/features/rewards/data/beneficio_canjeado.dart';
import 'package:monaco_mobile/features/rewards/data/premio_item.dart';
import 'package:monaco_mobile/features/rewards/providers/rewards_provider.dart';

/// Catálogo canjeable de la barbería, **con los candados ya resueltos para
/// este cliente**: `get_loyalty_catalog()` (mig 197) devuelve cada premio
/// activo y vigente con `locked_by_tier` / `tier_required_name` calculados
/// contra la categoría del cliente. La app no sabe qué categoría exige cada
/// premio ni cuál tiene el cliente: lo pinta.
///
/// Es dato personal (depende de quién pregunta), así que se ata al `clientId`
/// como el resto: sin sesión devuelve vacío y al cambiar de cliente se
/// recomputa solo.
final catalogoPremiosProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  if (ref.watch(authProvider.select((a) => a.clientId)) == null) return const [];
  final supabase = ref.read(supabaseClientProvider);
  final res = await supabase.rpc('get_loyalty_catalog');
  if (res is List) {
    return res
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  debugPrint('[premios] get_loyalty_catalog devolvió ${res.runtimeType}');
  return const [];
});

/// Deriva un valor de otro `AsyncValue` **sin perder el último valor bueno**.
///
/// `whenData` sobre un `AsyncLoading`/`AsyncError` que todavía lleva el valor
/// anterior lo DESCARTA (`hasValue: false`): en cada refresh, y peor, en cada
/// refresh fallido, el saldo pasaba a `null` → `?? 0`, la tarjeta del Home
/// animaba 650 → "0 PUNTOS", la grilla decía "Te faltan N pts" en todas las
/// tarjetas y `abrirPremio` abría "Te faltan 2.000 pts" en vez de canjear —
/// mientras `loyaltyProvider.valueOrNull` seguía diciendo 650. Acá se deriva
/// del último valor conocido y se conservan las banderas de carga y error.
AsyncValue<R> _derivar<T, R>(AsyncValue<T> origen, R Function(T) f) {
  final v = origen.valueOrNull;
  if (v == null) return origen.whenData(f);
  final dato = AsyncValue<R>.data(f(v));
  if (origen.isLoading) return AsyncValue<R>.loading().copyWithPrevious(dato);
  if (origen.hasError) {
    return AsyncValue<R>.error(
      origen.error!,
      origen.stackTrace ?? StackTrace.current,
    ).copyWithPrevious(dato);
  }
  return dato;
}

/// Saldo de puntos del cliente, como `int` pelado: lo leen la tarjeta del Home
/// y la pastilla de Premios, que sólo necesitan el número.
///
/// Sale de `loyaltyProvider` (`get_client_loyalty().points.balance`), que es la
/// misma fuente que la categoría y los vencimientos: así la tarjeta nunca
/// muestra un saldo de una llamada y una categoría de otra. Los totales
/// Ganados/Canjeados de `/points` salen del mismo resumen.
final saldoPuntosProvider = Provider<AsyncValue<int>>((ref) {
  return _derivar(ref.watch(loyaltyProvider), (s) => s.points.balance);
});

/// Grupo de orden de la grilla: 0 = lo puede usar ya, 1 = le faltan puntos,
/// 2 = agotado, 3 = bloqueado por categoría.
int _grupo(PremioItem p, int saldo) {
  if (p.lockedByTier) return 3;
  if (p.agotado) return 2;
  if (p.alcanza(saldo)) return 0;
  return 1;
}

/// **La grilla de Premios**: catálogo + convenios, con la categoría ya resuelta.
///
/// Los convenios vencidos NO entran: un beneficio que el comercio ya no honra
/// es ruido, y el chip "Marcas" con un solo ítem vencido se lee como que la
/// sección está rota. La pantalla `/convenios` sigue mostrando todo.
///
/// Orden: primero lo que el cliente **puede** usar hoy, después lo que le
/// falta poco, después lo agotado y al final lo bloqueado por categoría —
/// dentro de cada grupo los destacados (`is_featured`) arriba. Una grilla que
/// arranca con tres premios con candado desalienta; una que arranca con lo que
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
    final ga = _grupo(a, saldo);
    final gb = _grupo(b, saldo);
    if (ga != gb) return ga.compareTo(gb);
    // Los destacados por el dueño van arriba de su grupo, no de la grilla:
    // un destacado bloqueado por categoría sigue siendo un premio que el
    // cliente no puede tocar.
    if (a.isFeatured != b.isFeatured) return a.isFeatured ? -1 : 1;
    // Dentro de lo disponible, **primero los premios de la barbería**. Los
    // convenios son gratis, así que ordenando sólo por precio se quedaban con
    // toda la primera fila y una sección titulada "Canjeá tus puntos" abría con
    // tres tarjetas que dicen GRATIS.
    if (a.origen != b.origen) {
      return a.origen == PremioOrigen.catalogo ? -1 : 1;
    }
    // "Los que faltan pocos" primero: lo que se ordena en ese grupo es cuánto
    // falta, que con saldo fijo es lo mismo que el precio.
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
/// Salen de `get_client_wallet`, que desde la mig 197 devuelve también `kind`,
/// `service_name`, `points_spent`, `redeemed_at` y `cancel_reason`.
final premiosListosProvider = Provider<AsyncValue<List<Map<String, dynamic>>>>((ref) {
  return _derivar(
    ref.watch(clientWalletProvider),
    // Por `estadoDe` y no por el string: un premio vencido que el cron todavía
    // no marcó (`available` con `expires_at` pasado) no puede seguir en la
    // tira como "LISTO".
    (list) => list
        .where((r) =>
            BeneficioCanjeado.estadoDe(r) == EstadoBeneficio.disponible)
        .toList(),
  );
});

/// El premio del catálogo **más cercano** que el cliente todavía no puede
/// canjear. Es lo que alimenta la línea "A N pts de …" de la tarjeta de puntos del
/// Home: se deriva del catálogo real, así que si mañana cargan "Corte gratis"
/// a 300 pts, la línea pasa a decir eso sola. `null` = no hay catálogo, o ya le
/// alcanza para todo (y entonces la tarjeta dice otra cosa).
///
/// Los bloqueados por categoría no cuentan: juntar puntos no los destraba.
final proximoPremioProvider = Provider<PremioItem?>((ref) {
  final items = ref.watch(premiosProvider).valueOrNull;
  if (items == null) return null;
  final saldo = ref.watch(saldoPuntosProvider).valueOrNull ?? 0;
  PremioItem? mejor;
  for (final p in items) {
    if (p.esGratis || p.agotado || p.lockedByTier) continue;
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
  return items.where((p) => !p.esGratis && p.puedeCanjear(saldo)).length;
});

/// Invalida TODO lo que cambia después de un canje. Vive acá y no en la
/// pantalla para que ningún camino nuevo se olvide de alguno: un saldo
/// desactualizado deja al cliente canjeando dos veces el mismo premio.
void invalidarTrasCanje(WidgetRef ref) {
  for (final p in _trasCanje) {
    ref.invalidate(p);
  }
}

/// Lo que un canje deja viejo. Lista compartida con [invalidarFidelizacionEn]
/// para que los dos caminos nunca diverjan.
final _trasCanje = <ProviderOrFamily>[
  catalogoPremiosProvider,
  loyaltyProvider,
  pointsHistoryProvider,
  clientWalletProvider,
];

/// Refresca TODO lo de fidelización desde un contexto sin `WidgetRef` (el tap
/// de un push, la bandeja de notificaciones): estos providers son globales y
/// cacheados de por vida, y sin esto "Sumaste 110 pts" abría `/points` con el
/// saldo de la última carga. En arranque frío los providers todavía no se
/// computaron e `invalidate` es un no-op inofensivo. Con Riverpod 2.6 el valor
/// previo se conserva durante el refetch: el Home no parpadea a skeleton.
void invalidarFidelizacionEn(ProviderContainer container) {
  for (final p in [..._trasCanje, referralCodeProvider, misReferidosProvider]) {
    container.invalidate(p);
  }
}
