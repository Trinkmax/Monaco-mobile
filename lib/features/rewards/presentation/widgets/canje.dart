import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/core/supabase/supabase_provider.dart';
import 'package:monaco_mobile/features/rewards/data/premio_item.dart';
import 'package:monaco_mobile/features/rewards/providers/premios_provider.dart';

final _pts = NumberFormat.decimalPattern('es_AR');

/// Canje en vuelo. `redeem_points_for_reward` **no es idempotente**: cada
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
/// - **Agotado** → aviso, sin diálogo.
/// - **No le alcanza** → cuánto le falta, con la vista previa del premio.
/// - **Le alcanza** → confirmación y canje.
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

  if (premio.agotado) {
    showLiquidToast(
      context,
      'Este premio está agotado por ahora.',
      tone: LiquidToastTone.info,
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
    iconColor: MonacoColors.monacoGreen,
    message:
        'Vas a canjear ${_pts.format(premio.puntos)} pts por este premio. Después lo mostrás con un QR al barbero.',
    content: VistaPreviaCanje(premio: premio, saldo: saldo),
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
      'redeem_points_for_reward',
      params: {'p_reward_id': premio.id},
    );

    // `redeem_points_for_reward` NO lanza en el camino de negocio: devuelve
    // `{success:false, error:'Out of stock'|'Insufficient points'|…}` con 200.
    // Ignorarlo —como se hacía— le decía "Premio canjeado" a un cliente que no
    // canjeó nada, y lo mandaba a una billetera vacía.
    //
    // La RPC es `RETURNS json`, así que hoy llega un Map; se contempla igual el
    // caso `List` (una fila) por si algún día pasa a `RETURNS TABLE`: ahí un
    // `res is Map` a secas volvería a tratar un rechazo como éxito, en silencio.
    final mapa = _comoMapa(res);
    if (mapa != null && mapa['success'] == false) {
      // El saldo/stock que creíamos tener estaba viejo: refrescamos igual.
      invalidarTrasCanje(ref);
      _cerrarBarrera(context);
      if (!context.mounted) return;
      showLiquidToast(
        context,
        _mensajeDeRechazo(mapa),
        tone: LiquidToastTone.error,
        duration: const Duration(seconds: 4),
      );
      return;
    }

    invalidarTrasCanje(ref);
    _cerrarBarrera(context);
    if (!context.mounted) return;
    HapticFeedback.mediumImpact();
    showLiquidToast(
      context,
      'Listo. Mostralo en el local para usarlo.',
      tone: LiquidToastTone.success,
    );
  } catch (e) {
    _cerrarBarrera(context);
    if (!context.mounted) return;
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

/// Traduce el `error` de la RPC. Los textos vienen en inglés desde la base.
String _mensajeDeRechazo(Map<String, dynamic> res) {
  final error = (res['error'] ?? '').toString().toLowerCase();
  if (error.contains('insufficient')) {
    final falta = (res['required'] as num?) != null && (res['available'] as num?) != null
        ? ((res['required'] as num) - (res['available'] as num)).round()
        : null;
    return falta != null && falta > 0
        ? 'Te faltan ${_pts.format(falta)} pts para este premio.'
        : 'No te alcanzan los puntos para este premio.';
  }
  if (error.contains('stock')) return 'Este premio se agotó justo. Probá con otro.';
  if (error.contains('not available')) {
    return 'Este premio ya no está disponible.';
  }
  if (error.contains('client not found')) {
    return 'No pudimos identificar tu cuenta. Cerrá sesión y volvé a entrar.';
  }
  return 'No pudimos hacer el canje. Probá de nuevo en unos segundos.';
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
    return 'Sin conexión. Revisá tu internet e intentá de nuevo.';
  }
  return 'No pudimos hacer el canje. Probá de nuevo en unos segundos.';
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
                  MonacoColors.monacoGreen.withValues(alpha: 0.28),
                  MonacoColors.monacoGreen.withValues(alpha: 0.08),
                ],
              ),
              border: Border.all(
                color: MonacoColors.monacoGreen.withValues(alpha: 0.35),
                width: 0.8,
              ),
            ),
            child: Icon(premio.icono, color: MonacoColors.monacoGreen, size: 24),
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
                  alcanza
                      ? 'Te quedan ${_pts.format(resto)} pts'
                      : 'Tenés ${_pts.format(saldo)} pts',
                  style: TextStyle(
                    color: alcanza
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
