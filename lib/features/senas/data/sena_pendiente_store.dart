import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:monaco_mobile/core/auth/secure_storage.dart';

/// La seña que el cliente fue a pagar y todavía no resolvimos.
///
/// Se guarda en el momento en que se abre el checkout, no cuando vuelve: entre
/// esos dos instantes la app está en segundo plano y el sistema —iOS sobre
/// todo— puede matarla. Sin esta marca, el cliente vuelve a una app recién
/// arrancada, con un cobro hecho y ninguna pantalla que se lo explique.
class SenaPendiente {
  final String depositId;

  /// Para el texto del cartel ("Corte + Barba · Jue 4 sep 18:30").
  final String resumen;
  final num monto;

  /// El link del checkout. Se guarda para que "Volver a abrir el pago" siga
  /// funcionando después de un arranque en frío: sin él, un cliente al que iOS
  /// le mató la app mientras pagaba puede ver el estado pero no puede terminar.
  final String initPoint;

  /// Cuándo vence el link de pago. Pasada esa hora + [_gracia] la marca se
  /// descarta sola: ofrecer "retomá tu pago" sobre un link muerto es peor que
  /// no ofrecer nada.
  final DateTime? venceEn;
  final DateTime creadaEn;

  const SenaPendiente({
    required this.depositId,
    required this.resumen,
    required this.monto,
    required this.initPoint,
    required this.venceEn,
    required this.creadaEn,
  });

  /// Margen después del vencimiento en el que la marca sigue viva: un pago
  /// acreditado sobre el filo del vencimiento todavía puede confirmarse, y el
  /// cliente merece ver el resultado.
  static const Duration _gracia = Duration(minutes: 30);

  /// Tope absoluto, por si `expires_at` no llegó.
  static const Duration _maxVida = Duration(hours: 6);

  bool vigente({DateTime? ahora}) {
    final n = (ahora ?? DateTime.now()).toUtc();
    if (n.difference(creadaEn.toUtc()) > _maxVida) return false;
    final v = venceEn;
    if (v == null) return true;
    return n.isBefore(v.toUtc().add(_gracia));
  }

  Map<String, dynamic> toJson() => {
        'deposit_id': depositId,
        'resumen': resumen,
        'monto': monto,
        'init_point': initPoint,
        'vence_en': venceEn?.toUtc().toIso8601String(),
        'creada_en': creadaEn.toUtc().toIso8601String(),
      };

  static SenaPendiente? fromJson(Map<String, dynamic> j) {
    final id = j['deposit_id']?.toString().trim() ?? '';
    if (id.isEmpty) return null;
    return SenaPendiente(
      depositId: id,
      resumen: j['resumen']?.toString() ?? '',
      monto: j['monto'] is num ? j['monto'] as num : num.tryParse('${j['monto']}') ?? 0,
      initPoint: j['init_point']?.toString() ?? '',
      venceEn: DateTime.tryParse(j['vence_en']?.toString() ?? '')?.toUtc(),
      creadaEn: DateTime.tryParse(j['creada_en']?.toString() ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
    );
  }
}

/// Persistencia de la seña en curso. Un solo pago a la vez: el cliente no
/// puede estar señando dos turnos al mismo tiempo, y si abriera un segundo
/// checkout el que vale es el último.
class SenaPendienteStore {
  const SenaPendienteStore();

  Future<void> guardar(SenaPendiente s) async {
    try {
      await SecureStorageService.setSenaPendiente(jsonEncode(s.toJson()));
    } catch (e) {
      // No bloquea el pago: perder la marca sólo cuesta que el cliente tenga
      // que entrar a "Mis turnos" para ver el estado.
      debugPrint('[sena] no se pudo guardar la seña pendiente: $e');
    }
  }

  /// Devuelve la marca si sigue vigente; si venció, la borra de paso.
  Future<SenaPendiente?> leer() async {
    try {
      final raw = await SecureStorageService.getSenaPendiente();
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final s = SenaPendiente.fromJson(Map<String, dynamic>.from(decoded));
      if (s == null) return null;
      if (!s.vigente()) {
        await limpiar();
        return null;
      }
      return s;
    } catch (e) {
      debugPrint('[sena] no se pudo leer la seña pendiente: $e');
      return null;
    }
  }

  Future<void> limpiar() async {
    try {
      await SecureStorageService.setSenaPendiente(null);
    } catch (e) {
      debugPrint('[sena] no se pudo limpiar la seña pendiente: $e');
    }
  }

  /// Borra la marca sólo si es la de ESTA seña. La pantalla de pago la limpia
  /// al llegar a un estado terminal, y sin el chequeo de id podría borrar la
  /// marca de un pago más nuevo que el cliente acaba de abrir.
  Future<void> limpiarSiEs(String depositId) async {
    final actual = await leer();
    if (actual == null || actual.depositId != depositId) return;
    await limpiar();
  }
}
