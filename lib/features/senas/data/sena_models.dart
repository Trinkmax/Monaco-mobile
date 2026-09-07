/// Modelos de la SEÑA (`booking_deposits`), espejo del contrato compartido
/// `MonacoSmartBarber/src/lib/senas/contrato.ts`. Todo `fromJson` es tolerante:
/// un campo que falte no puede tirar la pantalla donde el cliente está viendo
/// qué pasó con su plata.
library;

/// Ciclo de vida de la seña. Los nombres son los de la columna `status`.
///
///   iniciada  → hay un link de pago abierto; el horario NO está reservado
///   pagada    → se acreditó y el turno existe
///   consumida → el servicio se cobró y la seña se imputó al precio
///   perdida   → cancelación tardía o ausencia
///   devuelta  → se devolvió por Mercado Pago
///   sinCupo   → pagó pero alguien tomó el horario primero (devolución automática)
///   rechazada → Mercado Pago rechazó el pago
///   expirada  → venció el link sin pagar
///   cancelada → el cliente abandonó antes de pagar
///
/// `desconocida` es el caso que importa: un estado que esta versión de la app
/// no conoce **nunca** se lee como éxito. Es la misma regla que
/// `BeneficioCanjeado` (un status raro no es "Disponible").
enum EstadoSena {
  iniciada,
  pagada,
  consumida,
  perdida,
  devuelta,
  sinCupo,
  rechazada,
  expirada,
  cancelada,
  desconocida;

  static EstadoSena desde(Object? raw) {
    switch (raw?.toString().trim().toLowerCase()) {
      case 'iniciada':
        return EstadoSena.iniciada;
      case 'pagada':
        return EstadoSena.pagada;
      case 'consumida':
        return EstadoSena.consumida;
      case 'perdida':
        return EstadoSena.perdida;
      case 'devuelta':
        return EstadoSena.devuelta;
      case 'sin_cupo':
        return EstadoSena.sinCupo;
      case 'rechazada':
        return EstadoSena.rechazada;
      case 'expirada':
        return EstadoSena.expirada;
      case 'cancelada':
        return EstadoSena.cancelada;
      default:
        return EstadoSena.desconocida;
    }
  }

  /// El turno existe y está confirmado.
  bool get turnoConfirmado =>
      this == EstadoSena.pagada ||
      this == EstadoSena.consumida ||
      this == EstadoSena.perdida;

  /// No va a cambiar más solo: dejar de preguntar.
  bool get terminal =>
      this != EstadoSena.iniciada && this != EstadoSena.desconocida;
}

/// Los textos que hay que mostrar ANTES de cobrar, pegados al botón.
///
/// Los escribe el server (`construirPolitica`) a partir de la config de la
/// sucursal: porcentaje, ventana de cancelación, qué pasa con la plata y el
/// derecho de arrepentimiento. **La app no los inventa ni los reescribe.** El
/// art. 1111 CCyC exige que la información sobre revocación vaya "en caracteres
/// destacados inmediatamente antes de la aceptación"; hornear una versión
/// nuestra acá haría que el día que el dueño cambie la política, la app siga
/// prometiendo la vieja.
class PoliticaSena {
  /// "Seña $8.000 ARS"
  final String titulo;

  /// "Es el 50% de Corte + Barba. Los $8.000 restantes los pagás en el local."
  final String detalle;

  /// Qué pasa si cancela.
  final String cancelacion;

  /// El horario se confirma con el pago acreditado (con `hold_minutes = 0`,
  /// que es como está hoy, esto avisa que alguien puede ganarle de mano).
  final String reserva;

  /// Derecho de arrepentimiento, si la sucursal lo tiene activo.
  final String? arrepentimiento;

  const PoliticaSena({
    required this.titulo,
    required this.detalle,
    required this.cancelacion,
    required this.reserva,
    this.arrepentimiento,
  });

  /// Los textos, en el orden en que se muestran. Vacíos afuera.
  List<String> get parrafos => [
        detalle,
        reserva,
        cancelacion,
        ?arrepentimiento,
      ].map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

  factory PoliticaSena.fromJson(Map<String, dynamic> j) => PoliticaSena(
        titulo: _str(j['titulo']),
        detalle: _str(j['detalle']),
        cancelacion: _str(j['cancelacion']),
        reserva: _str(j['reserva']),
        arrepentimiento: _strOrNull(j['arrepentimiento']),
      );
}

/// `POST /api/mobile/turnos/[slug]/sena` cuando la sucursal SÍ pide seña.
class SenaIntencion {
  final String depositId;

  /// URL del checkout de Mercado Pago. Se abre en Custom Tabs / Safari, nunca
  /// en un WebView: MP deshabilitó ese modelo para todas las integraciones.
  final String initPoint;

  /// Lo que se cobra ahora.
  final num monto;

  /// Precio completo de los servicios.
  final num total;

  /// Lo que queda a pagar en el local.
  final num resto;

  /// Cuándo vence el link de pago.
  final DateTime? venceEn;

  final PoliticaSena politica;

  const SenaIntencion({
    required this.depositId,
    required this.initPoint,
    required this.monto,
    required this.total,
    required this.resto,
    required this.venceEn,
    required this.politica,
  });

  factory SenaIntencion.fromJson(Map<String, dynamic> j) => SenaIntencion(
        depositId: _str(j['deposit_id']),
        initPoint: _str(j['init_point']),
        monto: _num(j['amount']),
        total: _num(j['service_total']),
        resto: _num(j['resto']),
        venceEn: _fecha(j['expires_at']),
        politica: PoliticaSena.fromJson(_map(j['politica'])),
      );

  bool get usable => depositId.isNotEmpty && initPoint.startsWith('http');
}

/// El turno que nació del pago (`EstadoSenaResponse.appointment`).
class TurnoDeSena {
  final String id;
  final String fecha; // yyyy-MM-dd, hora de pared de la sucursal
  final String hora; // HH:MM
  final String? barbero;
  final String sucursal;
  final String? servicios;

  const TurnoDeSena({
    required this.id,
    required this.fecha,
    required this.hora,
    required this.barbero,
    required this.sucursal,
    required this.servicios,
  });

  factory TurnoDeSena.fromJson(Map<String, dynamic> j) => TurnoDeSena(
        id: _str(j['id']),
        fecha: _str(j['appointment_date']),
        hora: _str(j['start_time']),
        barbero: _strOrNull(j['barber_name']),
        sucursal: _str(j['branch_name'], 'Monaco'),
        servicios: _strOrNull(j['service_names']),
      );
}

/// `GET /api/mobile/senas/<id>` — lo que consulta "Confirmando tu pago".
class SenaEstado {
  final String depositId;
  final EstadoSena estado;
  final num monto;
  final num resto;
  final TurnoDeSena? turno;

  /// Por qué falló, ya traducido por el server (`motivoRechazo`). Se muestra
  /// tal cual: la app no reescribe el motivo de un rechazo de tarjeta.
  final String? mensaje;

  /// El server decide cuándo tiene sentido seguir preguntando.
  final bool seguirEsperando;

  const SenaEstado({
    required this.depositId,
    required this.estado,
    required this.monto,
    required this.resto,
    required this.turno,
    required this.mensaje,
    required this.seguirEsperando,
  });

  factory SenaEstado.fromJson(Map<String, dynamic> j) {
    final estado = EstadoSena.desde(j['status']);
    return SenaEstado(
      depositId: _str(j['deposit_id']),
      estado: estado,
      monto: _num(j['amount']),
      resto: _num(j['resto']),
      turno: j['appointment'] is Map ? TurnoDeSena.fromJson(_map(j['appointment'])) : null,
      mensaje: _strOrNull(j['mensaje']),
      // Si el server no mandó la bandera, se deriva del estado. Un `false`
      // inventado dejaría al cliente mirando "confirmando" para siempre; un
      // `true` inventado sobre un estado terminal es sólo una consulta de más.
      seguirEsperando: j['seguir_esperando'] is bool
          ? j['seguir_esperando'] as bool
          : !estado.terminal,
    );
  }
}

/// Resultado de pedir la seña. Es una unión porque "esta sucursal no pide
/// seña" **no es un error**: es el camino normal de las cuatro sucursales de
/// Monaco hasta que el dueño prenda el interruptor.
sealed class ResultadoSena {
  const ResultadoSena();
}

/// Hay que cobrar antes de reservar.
class SenaRequerida extends ResultadoSena {
  final SenaIntencion intencion;
  const SenaRequerida(this.intencion);
}

/// La sucursal no pide seña para este canal: se reserva por el camino de
/// siempre (`POST /book`).
class SenaNoAplica extends ResultadoSena {
  const SenaNoAplica();
}

/// Cualquier otra cosa. `code` es el `CodigoErrorSena` del contrato
/// (`MP_NO_CONECTADO`, `SLOT_TAKEN`, `MP_ERROR`, …) o uno sintético de red.
class SenaFallo extends ResultadoSena {
  final String code;
  final String mensaje;

  /// El horario se fue mientras el cliente decidía: hay que recargar la grilla.
  bool get grillaVieja => code == 'SLOT_TAKEN' || code == 'TOO_LATE';

  const SenaFallo(this.code, this.mensaje);
}

// ── helpers ────────────────────────────────────────────────────────────────

String _str(Object? v, [String fallback = '']) {
  final s = v?.toString().trim();
  return (s == null || s.isEmpty) ? fallback : s;
}

String? _strOrNull(Object? v) {
  final s = v?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

num _num(Object? v) {
  if (v is num) return v;
  return num.tryParse(v?.toString() ?? '') ?? 0;
}

DateTime? _fecha(Object? v) {
  final s = _strOrNull(v);
  if (s == null) return null;
  return DateTime.tryParse(s)?.toUtc();
}

Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
