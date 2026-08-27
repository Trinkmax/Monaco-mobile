import 'package:flutter/material.dart';

/// Las tres solapas de la pantalla Premios.
///
/// No son un campo de la base: `marcas` son los convenios (`partner_benefits`,
/// otra tabla) y `cortes`/`merch` se **derivan** del premio salvo que el dueño
/// haya cargado el override en `reward_catalog.category` (migración 194).
enum PremioCategoria {
  cortes('cortes', 'Cortes', Icons.content_cut_rounded, Color(0xFF22C55E)),
  merch('merch', 'Merch', Icons.checkroom_rounded, Color(0xFFFFFFFF)),
  marcas('marcas', 'Marcas', Icons.storefront_rounded, Color(0xFF3B82F6));

  const PremioCategoria(this.slug, this.label, this.icono, this.acento);

  final String slug;
  final String label;
  final IconData icono;

  /// Color de la lámina y del ícono de la tarjeta.
  ///
  /// Existe porque **ningún premio de Monaco tiene foto cargada**: sin esto la
  /// grilla entera queda del mismo verde y las seis tarjetas se leen como una
  /// sola mancha (verificado en el simulador). Con un acento por categoría, el
  /// ojo separa "cortes / merch / marcas" antes de leer una palabra — que es lo
  /// que en el diseño hacían las fotos.
  final Color acento;

  static PremioCategoria? porSlug(String? slug) {
    if (slug == null) return null;
    for (final c in values) {
      if (c.slug == slug) return c;
    }
    return null;
  }
}

/// De dónde sale el premio. Cambia todo lo que pasa al tocarlo: el del catálogo
/// **cuesta puntos** y se canjea con una RPC que descuenta saldo; el convenio es
/// **gratis** y sólo emite un código que valida el comercio.
enum PremioOrigen { catalogo, convenio }

/// Un ítem de la grilla de Premios: un premio del catálogo de la barbería o un
/// convenio de un comercio aliado, con la misma forma para poder mostrarlos
/// juntos sin que la pantalla tenga que saber de dónde viene cada uno.
@immutable
class PremioItem {
  final String id;
  final PremioOrigen origen;
  final PremioCategoria categoria;
  final String nombre;

  /// Segunda línea de la tarjeta: la descripción del premio o el texto del
  /// descuento del convenio ("20% off", "2x1 pinta").
  final String? subtitulo;

  /// `null` = gratis (convenios). 0 nunca llega: el catálogo filtra `> 0`.
  final int? puntos;

  final String? imagenUrl;

  /// `null` = sin control de stock. `<= 0` = agotado.
  final int? stock;

  final bool esServicioGratis;
  final int? descuentoPct;
  final DateTime? validoHasta;

  /// Sólo convenios: el comercio que lo da.
  final String? marca;

  const PremioItem({
    required this.id,
    required this.origen,
    required this.categoria,
    required this.nombre,
    this.subtitulo,
    this.puntos,
    this.imagenUrl,
    this.stock,
    this.esServicioGratis = false,
    this.descuentoPct,
    this.validoHasta,
    this.marca,
  });

  bool get esGratis => puntos == null;
  bool get agotado => stock != null && stock! <= 0;

  /// ¿Le alcanza el saldo? Un convenio siempre "alcanza": no cuesta puntos.
  bool alcanza(int saldo) => esGratis || saldo >= (puntos ?? 0);

  /// Cuánto le falta para este premio (0 si ya le alcanza o es gratis).
  int faltan(int saldo) => esGratis ? 0 : (puntos! - saldo).clamp(0, puntos!);

  double progreso(int saldo) {
    final costo = puntos ?? 0;
    if (costo <= 0) return 1;
    return (saldo / costo).clamp(0.0, 1.0);
  }

  /// Ícono de la tarjeta cuando el premio no tiene foto cargada. Hoy **ningún**
  /// premio de Monaco tiene `image_url`, así que este es el caso normal, no el
  /// borde: tiene que quedar bien.
  IconData get icono {
    if (origen == PremioOrigen.convenio) return Icons.local_offer_rounded;
    if (esServicioGratis) return Icons.content_cut_rounded;
    if ((descuentoPct ?? 0) > 0) return Icons.percent_rounded;
    return categoria == PremioCategoria.merch
        ? Icons.redeem_rounded
        : Icons.card_giftcard_rounded;
  }

  // ── Constructores desde la base ─────────────────────────────────────────

  /// Fila de `reward_catalog` (la trae `catalogProvider`, `SELECT *`).
  factory PremioItem.deCatalogo(Map<String, dynamic> row) {
    final esServicioGratis = row['is_free_service'] == true;
    final descuento = (row['discount_pct'] as num?)?.toInt();
    // Override manual del dueño; si no lo cargó, se deriva.
    final categoria = PremioCategoria.porSlug(row['category'] as String?) ??
        ((esServicioGratis || (descuento ?? 0) > 0)
            ? PremioCategoria.cortes
            : PremioCategoria.merch);

    return PremioItem(
      id: row['id']?.toString() ?? '',
      origen: PremioOrigen.catalogo,
      categoria: categoria,
      nombre: (row['name'] as String?)?.trim().isNotEmpty == true
          ? (row['name'] as String).trim()
          : 'Premio',
      subtitulo: _limpio(row['description']),
      puntos: (row['points_cost'] as num?)?.toInt() ?? 0,
      imagenUrl: _limpio(row['image_url']),
      stock: (row['stock'] as num?)?.toInt(),
      esServicioGratis: esServicioGratis,
      descuentoPct: descuento,
      validoHasta: _fecha(row['valid_until']),
    );
  }

  /// Fila de `partner_benefits` con el embed `partner:commercial_partners(...)`.
  factory PremioItem.deConvenio(Map<String, dynamic> row) {
    final partner = row['partner'] is Map
        ? Map<String, dynamic>.from(row['partner'] as Map)
        : const <String, dynamic>{};
    return PremioItem(
      id: row['id']?.toString() ?? '',
      origen: PremioOrigen.convenio,
      categoria: PremioCategoria.marcas,
      nombre: _limpio(partner['business_name']) ??
          _limpio(row['title']) ??
          'Beneficio',
      // El nombre de la tarjeta es el COMERCIO ("Café Roma") y el subtítulo, el
      // beneficio ("20% off"): así se lee la grilla del diseño. Si el comercio
      // no tiene nombre cargado, el título hace de nombre y el descuento sigue
      // abajo.
      subtitulo: _limpio(row['discount_text']) ?? _limpio(row['title']),
      puntos: null,
      imagenUrl: _limpio(row['image_url']) ?? _limpio(partner['logo_url']),
      validoHasta: _fecha(row['valid_until']),
      marca: _limpio(partner['business_name']),
    );
  }

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
