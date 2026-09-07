import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/core/supabase/supabase_provider.dart';
import 'package:monaco_mobile/features/loyalty/data/loyalty_models.dart';
import 'package:monaco_mobile/features/loyalty/providers/loyalty_provider.dart';
import 'package:monaco_mobile/features/rewards/data/premio_item.dart';
import 'package:monaco_mobile/features/rewards/providers/premios_provider.dart';

final _pts = NumberFormat.decimalPattern('es_AR');
final _diaMes = DateFormat('dd/MM');

/// Canje en vuelo. `loyalty_redeem_reward` **no es idempotente**: cada
/// llamada descuenta puntos y crea un `client_reward`. Entre que se confirma y
/// contesta el server pasan uno o dos segundos en los que la grilla seguía
/// interactiva y sin ningún cambio visible; el cliente que creía que no había
/// registrado tocaba de nuevo, y el segundo diálogo se abría con el saldo
/// VIEJO (todavía no se invalidó nada), así que le decía que le alcanzaba.
/// Resultado: doble descuento y dos unidades de stock.
///
/// Es una variable de módulo y no un provider a propósito: el guard tiene que
/// sobrevivir a que la pantalla se reconstruya o se desmonte mientras la RPC
/// está en el aire.
String? _canjeEnVuelo;

/// Toca un premio de la grilla.
///
/// - **Convenio** → a su detalle: no cuesta puntos y el código lo emite otra RPC.
/// - **Bloqueado por categoría** → "Exclusivo para Oro y Platinum", cuántas
///   visitas faltan y el atajo a `/categoria`. Va ANTES que el stock y el
///   saldo: juntar puntos no lo destraba.
/// - **Agotado** → aviso, sin diálogo.
/// - **No le alcanza** → cuánto le falta, con la vista previa del premio.
/// - **Le alcanza** → confirmación (validez, dónde se retira) y canje.
Future<void> abrirPremio(
  BuildContext context,
  WidgetRef ref,
  PremioItem premio,
  int saldo,
) async {
  if (_canjeEnVuelo != null) return;
  HapticFeedback.selectionClick();

  if (premio.origen == PremioOrigen.convenio) {
    context.push('/convenio/${premio.id}');
    return;
  }

  if (premio.lockedByTier) {
    final loyalty = ref.read(loyaltyProvider).valueOrNull;
    final verCategorias = await showLiquidDialog<bool>(
      context,
      title: 'Exclusivo para ${_nombresDeTiers(premio, loyalty)}',
      icon: Icons.workspace_premium_rounded,
      message: _faltanVisitas(premio, loyalty),
      content: VistaPreviaCanje(premio: premio, saldo: saldo),
      actions: const [
        LiquidDialogAction<bool>(label: 'Cerrar', value: false),
        LiquidDialogAction<bool>(
          label: 'Ver categorías',
          value: true,
          primary: true,
          icon: Icons.arrow_forward_rounded,
        ),
      ],
    );
    if (verCategorias == true && context.mounted) context.push('/categoria');
    return;
  }

  if (premio.agotado) {
    showLiquidToast(
      context,
      'Este premio está agotado por ahora.',
      tone: LiquidToastTone.info,
    );
    return;
  }

  // Saldo desconocido (la RPC del resumen falló y nunca hubo uno bueno): el
  // `saldo` que llega es el 0 de relleno, y "Te faltan 2.000 pts" sería
  // mentirle. Se pide actualizar en vez de decidir con un número inventado.
  final resumen = ref.read(loyaltyProvider);
  if (resumen.hasError && !resumen.hasValue) {
    showLiquidToast(
      context,
      'No pudimos leer tu saldo. Deslizá hacia abajo para actualizar.',
      tone: LiquidToastTone.error,
    );
    return;
  }

  if (!premio.alcanza(saldo)) {
    await showLiquidDialog<void>(
      context,
      title: premio.nombre,
      icon: Icons.lock_outline_rounded,
      message:
          'Te faltan ${_pts.format(premio.faltan(saldo))} pts para canjearlo. Cada visita suma puntos, así que ya casi.',
      content: VistaPreviaCanje(premio: premio, saldo: saldo),
      actions: const [LiquidDialogAction<void>(label: 'Entendido')],
    );
    return;
  }

  final confirmado = await showLiquidDialog<bool>(
    context,
    title: 'Confirmar canje',
    icon: Icons.redeem_rounded,
    message: 'Vas a canjear ${_pts.format(premio.puntos)} pts por este premio.',
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VistaPreviaCanje(premio: premio, saldo: saldo),
        const SizedBox(height: 10),
        _DetallesCanje(
          premio: premio,
          diasDelPrograma: resumen.valueOrNull?.program.rewardValidityDays,
        ),
      ],
    ),
    actions: const [
      LiquidDialogAction<bool>(label: 'Cancelar', value: false),
      LiquidDialogAction<bool>(
        label: 'Canjear',
        value: true,
        primary: true,
        icon: Icons.check_rounded,
      ),
    ],
  );
  if (confirmado != true || !context.mounted) return;
  await _canjear(context, ref, premio);
}

/// "Oro y Platinum" / "Plata, Oro y Platinum": los nombres de las categorías
/// que destraban el premio, resueltos contra `loyalty.tiers` (el server manda
/// los códigos en `allowed_tiers`). Si no hay con qué resolverlos, la más baja
/// que manda la RPC.
String _nombresDeTiers(PremioItem premio, LoyaltySummary? loyalty) {
  final allowed = premio.allowedTiers;
  if (allowed != null && loyalty != null && loyalty.tiers.isNotEmpty) {
    final nombres = [
      for (final t in loyalty.tiers)
        if (allowed.contains(t.code)) t.name,
    ];
    if (nombres.length == 1) return nombres.first;
    if (nombres.length > 1) {
      return '${nombres.sublist(0, nombres.length - 1).join(', ')} y ${nombres.last}';
    }
  }
  return premio.tierRequiredName ?? 'otra categoría';
}

/// Cuántas visitas le faltan al cliente para la categoría más baja que
/// destraba el premio. Los umbrales son del server (`min_visits` del tier y
/// `visits_in_window` del cliente); acá sólo se resta.
String _faltanVisitas(PremioItem premio, LoyaltySummary? loyalty) {
  if (loyalty == null || !loyalty.programEnabled) {
    return 'El programa de categorías todavía no está activo. Cuando arranque, este premio se destraba subiendo de categoría.';
  }
  final req = loyalty.tierPorCode(premio.tierRequiredCode);
  final actual = loyalty.tier;
  // Reservado para una categoría MÁS BAJA que la del cliente (p. ej. un
  // premio de bienvenida sólo Bronce): no hay visitas que lo arreglen.
  if (req != null && actual != null && req.sort <= actual.sort) {
    return 'Este premio está reservado para otra categoría.';
  }
  final int faltan;
  final String destino;
  if (req != null) {
    faltan = req.minVisits - loyalty.visitsInWindow;
    destino = req.name;
  } else if (loyalty.nextTier != null) {
    faltan = loyalty.nextTierFaltan;
    destino = loyalty.nextTier!.name;
  } else {
    return 'Se destraba cuando subas de categoría.';
  }
  if (faltan <= 0) {
    return 'Ya tenés las visitas para $destino: tu categoría se actualiza con la próxima visita.';
  }
  final visitas = faltan == 1 ? 'falta 1 visita' : 'faltan $faltan visitas';
  return 'Te $visitas para llegar a $destino y poder canjearlo.';
}

Future<void> _canjear(
  BuildContext context,
  WidgetRef ref,
  PremioItem premio,
) async {
  if (_canjeEnVuelo != null) return;
  _canjeEnVuelo = premio.id;
  // Barrera modal mientras dura la llamada: además de bloquear el segundo
  // toque, es el único feedback de que algo está pasando.
  _mostrarBarrera(context);
  try {
    final supabase = ref.read(supabaseClientProvider);
    final res = await supabase.rpc(
      'loyalty_redeem_reward',
      params: {'p_reward_id': premio.id},
    );

    // `loyalty_redeem_reward` NO lanza en el camino de negocio: devuelve
    // `{success:false, error:'out_of_stock'|'insufficient_points'|…}` con 200.
    // Ignorarlo —como se hacía— le decía "Premio canjeado" a un cliente que no
    // canjeó nada, y lo mandaba a una billetera vacía.
    //
    // La RPC es `RETURNS json`, así que hoy llega un Map; se contempla igual el
    // caso `List` (una fila) por si algún día pasa a `RETURNS TABLE`: ahí un
    // `res is Map` a secas volvería a tratar un rechazo como éxito, en silencio.
    final mapa = _comoMapa(res);
    // Un shape que no se reconoce tampoco es un éxito: el saldo se refresca y
    // el cliente mira Mis premios antes de volver a tocar.
    if (mapa == null || mapa['success'] != true) {
      invalidarTrasCanje(ref);
      invalidarLoyalty(ref);
      if (!context.mounted) return;
      _cerrarBarrera(context);
      showLiquidToast(
        context,
        mapa == null
            ? 'No pudimos confirmar el canje. Revisá Mis premios antes de volver a intentar.'
            : _mensajeDeRechazo(mapa),
        tone: LiquidToastTone.error,
        duration: const Duration(seconds: 4),
      );
      return;
    }

    invalidarTrasCanje(ref);
    invalidarLoyalty(ref);
    if (!context.mounted) return;
    _cerrarBarrera(context);
    HapticFeedback.mediumImpact();
    final vence = DateTime.tryParse(mapa['expires_at']?.toString() ?? '')?.toLocal();
    showLiquidToast(
      context,
      vence == null
          ? 'Listo. Mostralo en el local para usarlo.'
          : 'Listo. Vence el ${_diaMes.format(vence)}.',
      tone: LiquidToastTone.success,
    );
    // El cliente quiere ver su QR: se abre directo, sin pasar por la tira.
    final clientRewardId = mapa['client_reward_id']?.toString();
    if (clientRewardId != null && clientRewardId.isNotEmpty) {
      context.push('/reward-qr/$clientRewardId');
    }
  } catch (e) {
    // Un timeout DESPUÉS de que la RPC commiteó es un canje hecho que la app
    // no vio: si el saldo y la wallet no se releen, el siguiente toque abre el
    // diálogo con el saldo viejo y emite un segundo canje. Se invalida
    // siempre, también acá.
    invalidarTrasCanje(ref);
    if (!context.mounted) return;
    _cerrarBarrera(context);
    showLiquidToast(
      context,
      _mensajeDeError(e),
      tone: LiquidToastTone.error,
      duration: const Duration(seconds: 4),
    );
  } finally {
    _canjeEnVuelo = null;
  }
}

/// Diálogo sin barrier dismiss ni back: nada de lo que hay debajo se puede
/// tocar mientras la RPC está en el aire.
void _mostrarBarrera(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    useRootNavigator: true,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(
        child: SizedBox(
          width: 34,
          height: 34,
          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
        ),
      ),
    ),
  );
}

void _cerrarBarrera(BuildContext context) {
  if (!context.mounted) return;
  final nav = Navigator.of(context, rootNavigator: true);
  if (nav.canPop()) nav.pop();
}

Map<String, dynamic>? _comoMapa(Object? res) {
  if (res is Map) return Map<String, dynamic>.from(res);
  if (res is List && res.isNotEmpty && res.first is Map) {
    return Map<String, dynamic>.from(res.first as Map);
  }
  return null;
}

/// Traduce el `error` de `loyalty_redeem_reward` (códigos `snake_case` de la
/// mig 197). Se tolera también el shape viejo de `redeem_points_for_reward`
/// ("Insufficient points") por si el server volviera a él.
String _mensajeDeRechazo(Map<String, dynamic> res) {
  final error = (res['error'] ?? '').toString().trim().toLowerCase();
  switch (error) {
    case 'insufficient_points':
    case 'insufficient points':
      final required = res['required'] as num?;
      final available = res['available'] as num?;
      final falta = required != null && available != null
          ? (required - available).round()
          : null;
      return falta != null && falta > 0
          ? 'Te faltan ${_pts.format(falta)} pts para este premio.'
          : 'No te alcanzan los puntos para este premio.';
    case 'tier_locked':
    case 'tier locked':
      final tier = (res['tier_required'] ?? '').toString().trim();
      return tier.isEmpty
          ? 'Este premio es exclusivo de otra categoría.'
          : 'Este premio es exclusivo para clientes $tier.';
    case 'out_of_stock':
    case 'out of stock':
      return 'Este premio se agotó justo. Probá con otro.';
    case 'expired':
      return 'Este premio ya no está vigente.';
    case 'not_available':
    case 'reward not available':
      return 'Este premio ya no está disponible.';
    case 'program_disabled':
      return 'El programa de puntos no está activo todavía.';
    case 'client_not_found':
    case 'client not found':
      return 'No pudimos identificar tu cuenta. Cerrá sesión y volvé a entrar.';
    default:
      return 'No pudimos hacer el canje. Probá de nuevo en unos segundos.';
  }
}

String _mensajeDeError(Object e) {
  final raw = e is PostgrestException ? e.message : e.toString();
  final lower = raw.toLowerCase();
  if (lower.contains('insuficiente') || lower.contains('insufficient')) {
    return 'No te alcanzan los puntos para este premio.';
  }
  if (lower.contains('stock') || lower.contains('agotado')) {
    return 'Este premio se agotó. Probá con otro.';
  }
  if (LiquidErrorState.isNetworkError(e)) {
    // La red pudo cortarse con el canje ya hecho: que mire antes de repetir.
    return 'Sin conexión. Revisá Mis premios antes de volver a intentar.';
  }
  return 'No pudimos hacer el canje. Revisá Mis premios antes de volver a intentar.';
}

/// Lo que el cliente tiene que saber ANTES de confirmar: cuánto dura el
/// beneficio y dónde/cómo lo usa. Los días salen del premio
/// (`validity_days`) o, si el premio no los define, del default del programa
/// (`program.reward_validity_days`, que `get_client_loyalty` manda desde la
/// mig 200 — es el caso de los premios reales de Monaco). Si tampoco llegó
/// eso, no se inventa un número: el vencimiento real llega en el toast y en
/// el QR.
class _DetallesCanje extends StatelessWidget {
  final PremioItem premio;
  final int? diasDelPrograma;
  const _DetallesCanje({required this.premio, required this.diasDelPrograma});

  @override
  Widget build(BuildContext context) {
    final dias = premio.validityDays ?? diasDelPrograma;
    final servicio = premio.serviceName;
    final filas = <(IconData, String)>[
      if (dias != null)
        (
          Icons.schedule_rounded,
          dias == 1
              ? 'Válido por 1 día desde el canje'
              : 'Válido por $dias días desde el canje',
        ),
      if (premio.esMerch)
        (
          Icons.storefront_rounded,
          'Lo retirás en cualquier sucursal mostrando el QR',
        )
      else if (servicio != null)
        (Icons.qr_code_scanner_rounded, 'Lo mostrás con el QR al pagar $servicio')
      else
        (Icons.qr_code_scanner_rounded, 'Lo mostrás con el QR al barbero al pagar'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < filas.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  filas[i].$1,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  filas[i].$2,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Fila premio + costo + saldo resultante, dentro del diálogo de canje.
class VistaPreviaCanje extends StatelessWidget {
  final PremioItem premio;
  final int saldo;

  const VistaPreviaCanje({super.key, required this.premio, required this.saldo});

  @override
  Widget build(BuildContext context) {
    final costo = premio.puntos ?? 0;
    final resto = saldo - costo;
    final alcanza = resto >= 0;
    final bloqueado = premio.lockedByTier;
    // Verde sólo cuando el canje ES posible (le alcanza y no está bloqueado):
    // es la misma condición del "Te quedan N pts" de abajo. Este widget vive
    // también en el diálogo "Te faltan N pts", y ahí un tile verde decía lo
    // contrario que el texto.
    final acento = !bloqueado && alcanza ? MonacoColors.monacoGreen : Colors.white;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 0.8),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  acento.withValues(alpha: 0.28),
                  acento.withValues(alpha: 0.08),
                ],
              ),
              border: Border.all(
                color: acento.withValues(alpha: 0.35),
                width: 0.8,
              ),
            ),
            child: Icon(
              bloqueado ? Icons.lock_rounded : premio.icono,
              color: acento,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  premio.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MonacoColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Cuesta ${_pts.format(costo)} pts',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  bloqueado
                      ? 'Tenés ${_pts.format(saldo)} pts'
                      : alcanza
                          ? 'Te quedan ${_pts.format(resto)} pts'
                          : 'Tenés ${_pts.format(saldo)} pts',
                  style: TextStyle(
                    color: !bloqueado && alcanza
                        ? MonacoColors.monacoGreen
                        : Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
