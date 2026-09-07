import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';

/// Estado de un beneficio ya canjeado (`client_rewards.status`) tal como lo
/// lee el cliente. `cancelled` existe desde la migración 196: lo cancela el
/// dashboard (con o sin devolución de puntos) y llega con `cancel_reason`.
enum EstadoBeneficio {
  disponible('available', 'Disponible'),
  utilizado('redeemed', 'Utilizado'),
  vencido('expired', 'Vencido'),
  cancelado('cancelled', 'Cancelado');

  const EstadoBeneficio(this.slug, this.label);
  final String slug;
  final String label;

  /// Verde = se puede usar; blanco apagado = ya se usó; rojo = venció; rojo
  /// apagado = lo cancelaron. El verde es del NEGOCIO ("tenés esto para
  /// usar"), no de la interfaz.
  Color get color => switch (this) {
        EstadoBeneficio.disponible => MonacoColors.monacoGreen,
        EstadoBeneficio.utilizado => Colors.white.withValues(alpha: 0.5),
        EstadoBeneficio.vencido => MonacoColors.destructive,
        EstadoBeneficio.cancelado =>
          MonacoColors.destructive.withValues(alpha: 0.6),
      };

  static EstadoBeneficio porSlug(Object? raw) {
    final s = raw?.toString().trim() ?? '';
    for (final e in values) {
      if (e.slug == s) return e;
    }
    // Un status desconocido no puede leerse como "disponible": si mañana la
    // base agrega uno, el cliente vería un QR que el barbero rechaza.
    return EstadoBeneficio.utilizado;
  }
}

/// Helpers sobre una fila de `get_client_wallet()` (mig 197). Viven acá y no
/// en cada pantalla para que la tira del tab Premios, "Mis premios" y el QR
/// digan exactamente lo mismo sobre el mismo beneficio.
class BeneficioCanjeado {
  BeneficioCanjeado._();

  static final _diaMes = DateFormat('dd/MM');

  /// El estado que el barbero va a ver. `status` lo pasa a `expired` el cron
  /// diario o el escaneo en el local, así que entre la hora del vencimiento y
  /// el cron siguiente la fila llega `available` con la fecha pasada: acá se
  /// lee como vencido para no mostrar un QR que igual van a rechazar.
  static EstadoBeneficio estadoDe(Map<String, dynamic> r, {DateTime? ahora}) {
    final e = EstadoBeneficio.porSlug(r['status']);
    if (e != EstadoBeneficio.disponible) return e;
    final v = vencimiento(r);
    if (v != null && !v.isAfter(ahora ?? DateTime.now())) {
      return EstadoBeneficio.vencido;
    }
    return e;
  }

  /// Qué ES el beneficio, en criollo, a partir de `kind` (mig 196):
  /// `descuento` → "20 % de descuento" / "Servicio gratis" (+ " en Corte" si
  /// aplica a un servicio), `merch` → "Retirá en la barbería", `especial` →
  /// "Beneficio especial".
  ///
  /// Las filas anteriores a la 196 no tienen `kind` (o lo tienen en el
  /// default `descuento` sin porcentaje): ahí manda lo que el premio hace y
  /// `reward_type` sólo desempata — el mapeo viejo traducía tres valores que
  /// no existen en el enum y la pantalla imprimía "spin prize" tal cual.
  static String etiqueta(Map<String, dynamic> r) {
    final kind = (r['kind'] ?? '').toString().trim();
    final servicio = _limpio(r['service_name']);
    final gratis = r['is_free_service'] == true;
    final pct = (r['discount_pct'] as num?)?.toInt() ?? 0;

    switch (kind) {
      case 'merch':
        return 'Retirá en la barbería';
      case 'especial':
        return 'Beneficio especial';
      case 'descuento':
        if (gratis || pct >= 100) {
          return servicio == null ? 'Servicio gratis' : 'Gratis: $servicio';
        }
        if (pct > 0) {
          return servicio == null
              ? '$pct % de descuento'
              : '$pct % de descuento en $servicio';
        }
        break;
    }

    if (gratis) return servicio == null ? 'Servicio gratis' : 'Gratis: $servicio';
    if (pct > 0) {
      return servicio == null
          ? '$pct % de descuento'
          : '$pct % de descuento en $servicio';
    }
    switch (r['reward_type']?.toString() ?? '') {
      case 'points_redemption':
        return 'Canje por puntos';
      case 'return_discount':
        return 'Descuento de bienvenida';
      case 'milestone_free':
        return 'Premio por fidelidad';
      case 'spin_prize':
        return 'Premio de la ruleta';
      case 'manual':
        return 'Premio especial';
      default:
        return 'Premio';
    }
  }

  static bool esMerch(Map<String, dynamic> r) =>
      (r['kind'] ?? '').toString().trim() == 'merch';

  static DateTime? vencimiento(Map<String, dynamic> r) =>
      _fecha(r['expires_at']);

  static DateTime? canjeadoEl(Map<String, dynamic> r) =>
      _fecha(r['created_at']);

  static DateTime? utilizadoEl(Map<String, dynamic> r) =>
      _fecha(r['redeemed_at']);

  static String? motivoCancelacion(Map<String, dynamic> r) =>
      _limpio(r['cancel_reason']);

  static int? puntosGastados(Map<String, dynamic> r) {
    final n = (r['points_spent'] as num?)?.toInt();
    return n == null || n <= 0 ? null : n;
  }

  /// Días enteros que faltan para [at], redondeando para arriba: a las 23:00
  /// de hoy un vencimiento de mañana a las 10:00 es "1 día", no "0". Negativo
  /// = ya venció. `null` si no hay fecha.
  static int? diasParaVencer(DateTime? at, {DateTime? ahora}) {
    if (at == null) return null;
    final now = ahora ?? DateTime.now();
    final diff = at.difference(now);
    if (diff.isNegative) return -1;
    return (diff.inMinutes / (60 * 24)).ceil();
  }

  /// La cuenta regresiva del QR y de las tarjetas: "Vence en 12 días" (verde
  /// si faltan más de 7), "Vence en 3 días" (ámbar), "Vence hoy" (ámbar) o
  /// "Vencido" (rojo). `null` = sin vencimiento.
  static ({String label, Color color})? cuentaRegresiva(
    DateTime? expiresAt, {
    DateTime? ahora,
  }) {
    final dias = diasParaVencer(expiresAt, ahora: ahora);
    if (dias == null) return null;
    if (dias < 0) return (label: 'Vencido', color: MonacoColors.destructive);
    if (dias == 0) return (label: 'Vence hoy', color: MonacoColors.warning);
    final label = dias == 1 ? 'Vence mañana' : 'Vence en $dias días';
    return (
      label: label,
      color: dias <= 7 ? MonacoColors.warning : MonacoColors.monacoGreen,
    );
  }

  /// "Vence el 28/09" para listas donde la fecha exacta sirve más que la
  /// cuenta regresiva.
  static String? venceEl(DateTime? expiresAt) =>
      expiresAt == null ? null : 'Vence el ${_diaMes.format(expiresAt)}';

  static String? _limpio(Object? v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  static DateTime? _fecha(Object? v) {
    final s = v?.toString();
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s)?.toLocal();
  }
}
