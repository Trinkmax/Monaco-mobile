import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/features/appointments/data/fechas.dart';
import 'package:monaco_mobile/features/appointments/presentation/widgets/confirmacion_verde.dart';

import '../../data/sena_models.dart';
import '../../providers/sena_estado_provider.dart';
import '../checkout_launcher.dart';

/// **Confirmando tu pago.**
///
/// Es la pantalla a la que el cliente vuelve del navegador —por el deep link
/// `monaco://pago?deposit=<id>`, por el botón de atrás, o entrando desde el
/// cartel de "Mis turnos" tres horas después—. Los tres caminos tienen que
/// terminar acá y mostrar lo mismo, porque ninguno de los tres es confiable:
/// el deep link puede no llegar nunca y los parámetros que Mercado Pago agrega
/// a la URL de vuelta viajan por el browser del cliente y son falsificables.
///
/// La verdad sale de `GET /api/mobile/senas/<id>`, alimentada por Realtime
/// (ver `SenaEstadoController`).
class PagoSenaScreen extends ConsumerStatefulWidget {
  final String depositId;

  /// Link del checkout, si lo tenemos a mano (venimos del wizard). Si no,
  /// se busca en la marca local; y si tampoco está, no se ofrece reabrirlo.
  final String? initPoint;

  const PagoSenaScreen({super.key, required this.depositId, this.initPoint});

  @override
  ConsumerState<PagoSenaScreen> createState() => _PagoSenaScreenState();
}

class _PagoSenaScreenState extends ConsumerState<PagoSenaScreen> {
  bool _verdeMostrado = false;
  bool _mostrandoVerde = false;
  String? _initPointGuardado;

  @override
  void initState() {
    super.initState();
    unawaited(_recuperarInitPoint());
  }

  /// El link puede no venir por parámetro (deep link, cartel de "Mis turnos",
  /// arranque en frío): se busca en la marca local que dejamos al abrir el pago.
  Future<void> _recuperarInitPoint() async {
    if (widget.initPoint != null && widget.initPoint!.isNotEmpty) return;
    final pendiente = await ref.read(senaPendienteStoreProvider).leer();
    if (!mounted) return;
    if (pendiente?.depositId == widget.depositId &&
        (pendiente?.initPoint.isNotEmpty ?? false)) {
      setState(() => _initPointGuardado = pendiente!.initPoint);
    }
  }

  String? get _link {
    final directo = widget.initPoint;
    if (directo != null && directo.isNotEmpty) return directo;
    return _initPointGuardado;
  }

  void _salir() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/turnos');
    }
  }

  Future<void> _reabrirPago() async {
    final link = _link;
    if (link == null) return;
    final ok = await abrirCheckoutSena(link);
    if (!ok && mounted) {
      showLiquidToast(
        context,
        'No pudimos abrir el pago en este dispositivo.',
        tone: LiquidToastTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final estadoState = ref.watch(senaEstadoProvider(widget.depositId));
    final ctrl = ref.read(senaEstadoProvider(widget.depositId).notifier);
    final estado = estadoState.estado;
    final situacion = estado?.estado ?? EstadoSena.iniciada;

    // "Hay un turno vivo del otro lado", que NO es lo mismo que
    // `situacion.turnoConfirmado`:
    //
    //  · `perdida` entra en `turnoConfirmado` porque el turno existió, pero
    //    llega acá después de una cancelación tardía o una ausencia: festejar
    //    "Turno confirmado · te esperamos" sobre una seña que el cliente acaba
    //    de perder es la peor pantalla que le podemos mostrar.
    //  · `pagada` sin turno son los dos casos que el motor deja abiertos a
    //    propósito: la creación del turno falló (queda para resolver a mano) o
    //    el cliente canceló a tiempo y la plata le quedó a favor. En los dos
    //    el turno NO existe, y el server lo dice mandando `appointment: null`.
    //
    // El server ya manda el texto correcto en `mensaje` para los dos; el que
    // los pisaba con el verde era este switch.
    final hayTurno = estado?.turno != null &&
        (situacion == EstadoSena.pagada || situacion == EstadoSena.consumida);

    // El velo verde se dispara UNA vez, cuando el turno queda confirmado. Es la
    // misma celebración que la reserva sin seña: el cliente que pagó no merece
    // menos que el que no pagó.
    if (estado != null && hayTurno && !_verdeMostrado) {
      // Se prende ACÁ y no en un `ref.listen` a propósito: el listener sólo
      // dispara con un CAMBIO, y si el estado ya venía confirmado en la primera
      // lectura —el cliente vuelve a la pantalla un rato después, o entra desde
      // el cartel— nunca habría festejo. El `Stack` de abajo ya lo ve en este
      // mismo build, así que no hace falta un `setState`.
      _verdeMostrado = true;
      _mostrandoVerde = true;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _salir();
      },
      child: Scaffold(
        backgroundColor: MonacoColors.background,
        body: Stack(
          children: [
            Column(
              children: [
                LiquidAppBar(
                  title: hayTurno ? 'Listo' : 'Tu pago',
                  showBackButton: true,
                  onBack: _salir,
                  scrolled: true,
                ),
                Expanded(
                  child: _cuerpo(estadoState, ctrl, situacion, hayTurno),
                ),
              ],
            ),
            if (_mostrandoVerde)
              Positioned.fill(
                child: ConfirmacionVerde(
                  onDone: () {
                    if (mounted) setState(() => _mostrandoVerde = false);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// El desenlace, con los MISMOS nombres de estado que `/pago/[id]` en la web
  /// ("Turno confirmado", "Ese horario se ocupó", "El pago no se aprobó",
  /// "Seña devuelta", "Seña no reintegrable"…).
  ///
  /// No es prolijidad: la vuelta de Mercado Pago pasa por esa página del
  /// navegador antes de rebotar al deep link, así que el mismo cliente puede
  /// leer las dos pantallas con dos segundos de diferencia. Si cambia una,
  /// cambian las dos.
  Widget _cuerpo(
    SenaEstadoState s,
    SenaEstadoController ctrl,
    EstadoSena situacion,
    bool hayTurno,
  ) {
    if (s.cargando && s.estado == null) {
      return const _Esperando(
        titulo: 'Buscando tu pago',
        detalle: 'Un segundo, estamos leyendo el estado.',
        monto: null,
      );
    }

    // No pudimos leer NADA todavía: no es "el pago falló", es "no sabemos".
    // Decirlo con esas palabras evita que el cliente vuelva a pagar.
    if (s.estado == null) {
      return LiquidErrorState(
        title: 'No pudimos revisar el pago',
        message: '${s.errorDeLectura ?? 'Probá de nuevo en un momento.'}\n\n'
            'Si ya pagaste, tu plata está a salvo: el turno se confirma solo '
            'apenas Mercado Pago nos avise.',
        onRetry: ctrl.revisarAhora,
      );
    }

    final estado = s.estado!;

    switch (situacion) {
      case EstadoSena.pagada:
      case EstadoSena.consumida:
        if (hayTurno) {
          return _Confirmado(
              estado: estado, onVerTurno: _verTurno, onMisTurnos: _misTurnos);
        }
        // Pagó y no hay turno. Nunca se le dice "turno confirmado", pero
        // tampoco "el pago falló": la plata entró y está registrada, y decirle
        // lo contrario es cómo se llega a que pague dos veces.
        //
        // Son DOS situaciones opuestas y el server las separa con
        // `seguir_esperando`: si sigue esperando, el turno se está armando; si
        // no, el cliente canceló a tiempo y la seña le quedó a favor. Con un
        // solo título, a quien canceló su turno le decíamos que se lo estamos
        // armando. La misma distinción que hace `/pago/[id]` en la web.
        final aFavor = !estado.seguirEsperando;
        return _Resultado(
          icono: aFavor
              ? Icons.account_balance_wallet_rounded
              : Icons.hourglass_bottom_rounded,
          tono: MonacoColors.warning,
          titulo: aFavor ? 'La seña te quedó a favor' : 'Recibimos tu pago',
          detalle: estado.mensaje ??
              (aFavor
                  ? 'Este turno está cancelado. Los '
                      '${Fechas.moneda(estado.monto)} que pagaste te quedan a '
                      'favor para tu próxima reserva: avisanos cuando quieras '
                      'usarlos.'
                  : 'Nos falta terminar de armar tu turno. Te confirmamos por '
                      'WhatsApp apenas esté: tu pago de '
                      '${Fechas.moneda(estado.monto)} ya quedó registrado, no lo '
                      'repitas. Si en un rato no tenés novedades, escribinos y '
                      'lo resolvemos.'),
          accionPrincipal: aFavor ? 'Reservar de nuevo' : 'Mis turnos',
          onPrincipal: aFavor ? _reservarDeNuevo : _misTurnos,
          accionSecundaria: aFavor ? 'Mis turnos' : 'Volver',
          onSecundaria: aFavor ? _misTurnos : _salir,
        );

      case EstadoSena.perdida:
        return _Resultado(
          icono: Icons.event_busy_rounded,
          tono: MonacoColors.warning,
          titulo: 'Seña no reintegrable',
          detalle: estado.mensaje ??
              'La seña de ${Fechas.moneda(estado.monto)} quedó a favor del '
                  'local por la cancelación fuera de término.',
          accionPrincipal: 'Reservar de nuevo',
          onPrincipal: _reservarDeNuevo,
          accionSecundaria: 'Mis turnos',
          onSecundaria: _misTurnos,
        );

      case EstadoSena.sinCupo:
        return _Resultado(
          icono: Icons.event_busy_rounded,
          tono: MonacoColors.warning,
          titulo: 'Ese horario se ocupó',
          detalle: estado.mensaje ??
              'Alguien lo tomó justo antes que vos. Te devolvimos la seña de '
                  '${Fechas.moneda(estado.monto)} a Mercado Pago —puede tardar '
                  'unos días en verse— y podés elegir otro horario.',
          accionPrincipal: 'Elegir otro horario',
          onPrincipal: _reservarDeNuevo,
          accionSecundaria: 'Mis turnos',
          onSecundaria: _misTurnos,
        );

      case EstadoSena.rechazada:
        return _Resultado(
          icono: Icons.credit_card_off_rounded,
          tono: MonacoColors.destructive,
          // El motivo viene traducido del server (`motivoRechazo`): colapsar
          // todo en "el pago falló" es lo que hace que el cliente reintente
          // cinco veces con la misma tarjeta sin fondos.
          titulo: 'El pago no se aprobó',
          detalle: estado.mensaje ??
              'Mercado Pago rechazó el pago. Probá con otro medio.',
          accionPrincipal: 'Probar de nuevo',
          onPrincipal: _reservarDeNuevo,
          accionSecundaria: 'Volver',
          onSecundaria: _salir,
        );

      case EstadoSena.devuelta:
        return _Resultado(
          icono: Icons.undo_rounded,
          tono: MonacoColors.warning,
          titulo: 'Seña devuelta',
          detalle: estado.mensaje ??
              'Te devolvimos la seña de ${Fechas.moneda(estado.monto)} a '
                  'Mercado Pago. Puede tardar unos días en verse según el '
                  'medio de pago que hayas usado.',
          accionPrincipal: 'Reservar de nuevo',
          onPrincipal: _reservarDeNuevo,
          accionSecundaria: 'Mis turnos',
          onSecundaria: _misTurnos,
        );

      case EstadoSena.expirada:
        return _Resultado(
          icono: Icons.timer_off_rounded,
          tono: MonacoColors.warning,
          titulo: 'El link de pago venció',
          detalle: estado.mensaje ??
              'No se cobró nada. Podés volver a reservar cuando quieras.',
          accionPrincipal: 'Reservar de nuevo',
          onPrincipal: _reservarDeNuevo,
          accionSecundaria: 'Volver',
          onSecundaria: _salir,
        );

      // `cancelada` no es `expirada`: una es "se te pasó el tiempo" y la otra
      // "lo dejaste antes de pagar". Estaban juntas bajo "el link venció", que
      // para el que abandonó el checkout es una explicación falsa.
      case EstadoSena.cancelada:
        return _Resultado(
          icono: Icons.timer_off_rounded,
          tono: MonacoColors.warning,
          titulo: 'El pago quedó cancelado',
          detalle: estado.mensaje ??
              'No se cobró nada. Podés volver a reservar cuando quieras.',
          accionPrincipal: 'Reservar de nuevo',
          onPrincipal: _reservarDeNuevo,
          accionSecundaria: 'Volver',
          onSecundaria: _salir,
        );

      case EstadoSena.iniciada:
      case EstadoSena.desconocida:
        return _Esperando(
          titulo: 'Estamos confirmando el pago',
          detalle: 'Mercado Pago nos avisa en unos segundos. No hace falta que '
              'pagues de nuevo: apenas se acredite, tu turno queda reservado. '
              'Podés quedarte acá: se actualiza solo.',
          monto: estado.monto,
          revisando: s.revisando,
          esperaAgotada: s.esperaAgotada,
          errorDeLectura: s.errorDeLectura,
          onRevisar: ctrl.revisarAhora,
          onReabrir: _link == null ? null : _reabrirPago,
        );
    }
  }

  void _verTurno() {
    final id = ref
        .read(senaEstadoProvider(widget.depositId))
        .estado
        ?.turno
        ?.id;
    if (id != null && id.isNotEmpty) {
      context.go('/turnos/$id');
    } else {
      context.go('/turnos');
    }
  }

  void _misTurnos() => context.go('/turnos');

  void _reservarDeNuevo() => context.go('/turnos/reservar');
}

// ── Estados ────────────────────────────────────────────────────────────────

class _Esperando extends StatelessWidget {
  final String titulo;
  final String detalle;
  final num? monto;
  final bool revisando;
  final bool esperaAgotada;
  final String? errorDeLectura;
  final VoidCallback? onRevisar;
  final VoidCallback? onReabrir;

  const _Esperando({
    required this.titulo,
    required this.detalle,
    required this.monto,
    this.revisando = false,
    this.esperaAgotada = false,
    this.errorDeLectura,
    this.onRevisar,
    this.onReabrir,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
      children: [
        const Center(child: _Latido()),
        const SizedBox(height: 26),
        Text(
          titulo,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: MonacoColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
          ),
        ),
        if (monto != null) ...[
          const SizedBox(height: 6),
          Text(
            Fechas.moneda(monto!),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ],
        const SizedBox(height: 10),
        Text(
          detalle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 14,
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (esperaAgotada) ...[
          const SizedBox(height: 18),
          _Aviso(
            icono: Icons.schedule_rounded,
            texto: 'Está tardando más de lo normal. Si ya pagaste, tocá '
                '"Ya pagué" y volvemos a revisar. Si el cobro salió, el turno '
                'se confirma igual aunque cierres la app.',
          ),
        ],
        if (errorDeLectura != null) ...[
          const SizedBox(height: 14),
          _Aviso(icono: Icons.wifi_off_rounded, texto: errorDeLectura!),
        ],
        const SizedBox(height: 26),
        if (onRevisar != null)
          LiquidButton(
            tint: MonacoColors.seleccion,
            onPressed: revisando ? null : onRevisar,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            child: revisando
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Revisando…',
                        style: TextStyle(
                            color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                    ],
                  )
                : const Text(
                    'Ya pagué, revisá de nuevo',
                    style: TextStyle(
                        color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                  ),
          ),
        if (onReabrir != null) ...[
          const SizedBox(height: 10),
          LiquidPill(
            onTap: onReabrir,
            borderRadius: 16,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.open_in_new_rounded, size: 17, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Volver a abrir el pago',
                  style: TextStyle(
                      color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        Text(
          'No cierres esta pantalla si acabás de pagar. Si igual la cerrás, '
          'podés volver desde Mis turnos.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 12,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Círculo que respira mientras esperamos. No es una barra de progreso a
/// propósito: no sabemos cuánto falta, y una barra que se llena sola miente.
class _Latido extends StatelessWidget {
  const _Latido();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.18),
            Colors.white.withValues(alpha: 0.04),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: const Icon(Icons.hourglass_top_rounded, color: Colors.white, size: 36),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(begin: 1, end: 1.06, duration: 1100.ms, curve: Curves.easeInOut)
        .fadeIn(duration: 300.ms);
  }
}

class _Aviso extends StatelessWidget {
  final IconData icono;
  final String texto;
  const _Aviso({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: MonacoColors.warning.withValues(alpha: 0.10),
        border: Border.all(color: MonacoColors.warning.withValues(alpha: 0.32), width: 0.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 17, color: MonacoColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 12.5,
                height: 1.42,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Turno confirmado. El verde acá SÍ corresponde: es lo que significa algo del
/// negocio (turno confirmado), no un estado de interfaz.
class _Confirmado extends StatelessWidget {
  final SenaEstado estado;
  final VoidCallback onVerTurno;
  final VoidCallback onMisTurnos;

  const _Confirmado({
    required this.estado,
    required this.onVerTurno,
    required this.onMisTurnos,
  });

  @override
  Widget build(BuildContext context) {
    final turno = estado.turno;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
      children: [
        Text(
          'Turno confirmado',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: MonacoColors.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
          ),
        ).liquidEnter(index: 0),
        const SizedBox(height: 6),
        Text(
          'Recibimos la seña de ${Fechas.moneda(estado.monto)}. '
          'Te mandamos la confirmación por WhatsApp.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.62),
            fontSize: 13.5,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        ).liquidEnter(index: 1),
        const SizedBox(height: 22),
        if (turno != null)
          LiquidGlass(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            borderRadius: 26,
            tint: MonacoColors.monacoGreen,
            tintOpacity: 0.10,
            pressable: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TU TURNO',
                  style: TextStyle(
                    color: MonacoColors.monacoGreen.withValues(alpha: 0.9),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  Fechas.hhmm(turno.hora),
                  style: const TextStyle(
                    color: MonacoColors.textPrimary,
                    fontSize: 46,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: -1.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  Fechas.fechaLargaDeStr(turno.fecha),
                  style: const TextStyle(
                    color: MonacoColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 12),
                Container(height: 0.6, color: Colors.white.withValues(alpha: 0.10)),
                const SizedBox(height: 12),
                Text(
                  [
                    turno.sucursal,
                    if (turno.barbero != null) 'Te atiende ${turno.barbero}',
                    if (turno.servicios != null) turno.servicios!,
                  ].join(' · '),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ).liquidEnter(index: 2),
        if (estado.resto > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white.withValues(alpha: 0.05),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 0.8),
            ),
            child: Row(
              children: [
                Icon(Icons.account_balance_wallet_outlined,
                    size: 18, color: Colors.white.withValues(alpha: 0.75)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'En el local pagás los ${Fechas.moneda(estado.resto)} que faltan.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ).liquidEnter(index: 3),
        ],
        const SizedBox(height: 22),
        LiquidButton(
          tint: MonacoColors.seleccion,
          onPressed: onVerTurno,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          child: const Text(
            'Ver mi turno',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ).liquidEnter(index: 4),
        const SizedBox(height: 10),
        LiquidPill(
          onTap: onMisTurnos,
          borderRadius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: const Center(
            child: Text(
              'Mis turnos',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
            ),
          ),
        ).liquidEnter(index: 5),
      ],
    );
  }
}

/// Pantalla de resultado no feliz: ícono, título, explicación y dos salidas.
/// Siempre hay una salida que es "seguir reservando": dejar al cliente sin
/// próximo paso después de un rechazo es perderlo.
class _Resultado extends StatelessWidget {
  final IconData icono;
  final Color tono;
  final String titulo;
  final String detalle;
  final String accionPrincipal;
  final VoidCallback onPrincipal;
  final String accionSecundaria;
  final VoidCallback onSecundaria;

  const _Resultado({
    required this.icono,
    required this.tono,
    required this.titulo,
    required this.detalle,
    required this.accionPrincipal,
    required this.onPrincipal,
    required this.accionSecundaria,
    required this.onSecundaria,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
      children: [
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tono.withValues(alpha: 0.14),
              border: Border.all(color: tono.withValues(alpha: 0.4)),
            ),
            child: Icon(icono, color: tono, size: 34),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          titulo,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: MonacoColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          detalle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.62),
            fontSize: 14,
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 26),
        LiquidButton(
          tint: MonacoColors.seleccion,
          onPressed: onPrincipal,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          child: Text(
            accionPrincipal,
            style: const TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 10),
        LiquidPill(
          onTap: onSecundaria,
          borderRadius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Center(
            child: Text(
              accionSecundaria,
              style: const TextStyle(
                  color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}
