import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' show Position;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/core/location/location_provider.dart';
import 'package:monaco_mobile/core/location/location_service.dart';

import '../../data/booking_models.dart';

/// **Paso 1 del wizard: ¿en qué sucursal?**
///
/// La app no tiene sucursal guardada, así que reservar siempre empieza acá. La
/// otra entrada es el deep-link `?branch=<slug>` cuando ese slug no toma turnos
/// online: ahí el copy cambia para explicar por qué apareció esta pantalla.
class BranchPickerStep extends ConsumerStatefulWidget {
  final List<MobileBranch> branches;
  final bool loading;
  final bool originalNotBookable;
  final ValueChanged<MobileBranch> onPick;

  const BranchPickerStep({
    super.key,
    required this.branches,
    required this.loading,
    required this.originalNotBookable,
    required this.onPick,
  });

  @override
  ConsumerState<BranchPickerStep> createState() => _BranchPickerStepState();
}

class _BranchPickerStepState extends ConsumerState<BranchPickerStep> {
  /// La ubicación se pide **sólo si el cliente la pide**: el prompt del sistema
  /// en medio de una reserva, sin haberlo tocado, se lee como que la app espía.
  /// Con el permiso ya concedido, `userLocationProvider` no vuelve a
  /// preguntar y ordenamos solos.
  bool _quiereCercania = false;

  @override
  Widget build(BuildContext context) {
    final titulo = widget.originalNotBookable
        ? 'Esa sucursal atiende por orden de llegada.'
        : '¿Dónde querés reservar?';
    final sub = widget.originalNotBookable
        ? 'Estas sí toman turnos online:'
        : 'Elegí la sucursal y seguimos con el servicio y el horario.';

    final ubicacion =
        _quiereCercania ? ref.watch(userLocationProvider).valueOrNull : null;
    final buscandoUbicacion =
        _quiereCercania && ref.watch(userLocationProvider).isLoading;

    final items = _ordenar(widget.branches, ubicacion);
    final puedeOrdenar = widget.branches.any((b) => b.hasCoordinates);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        Text(
          titulo,
          style: const TextStyle(
            color: MonacoColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            height: 1.15,
          ),
        ).liquidEnter(index: 0),
        const SizedBox(height: 6),
        Text(
          sub,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
        ).liquidEnter(index: 1),
        if (!widget.loading && items.length > 1 && puedeOrdenar) ...[
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: _CercaniaPill(
              activo: _quiereCercania,
              cargando: buscandoUbicacion,
              sinPermiso: _quiereCercania && !buscandoUbicacion && ubicacion == null,
              onTap: () => setState(() => _quiereCercania = !_quiereCercania),
            ),
          ).liquidEnter(index: 2),
        ],
        const SizedBox(height: 18),
        if (widget.loading) ...[
          for (var i = 0; i < 3; i++) ...[
            const LiquidSkeleton(height: 92),
            const SizedBox(height: 12),
          ],
        ] else if (items.isEmpty)
          LiquidEmptyState(
            icon: Icons.event_busy_rounded,
            title: 'Por ahora no hay turnos online',
            message:
                'Ninguna sucursal está tomando turnos por la app en este momento. Acercate cuando quieras: te atendemos por orden de llegada.',
            scrollable: false,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 32),
          )
        else
          for (var i = 0; i < items.length; i++) ...[
            _BranchTile(
              branch: items[i].branch,
              distanciaKm: items[i].km,
              onTap: () => widget.onPick(items[i].branch),
            ).liquidEnter(index: 3 + i),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  /// Con ubicación: más cerca primero. Sin ubicación: **abiertas primero** y
  /// después por nombre — el orden que llega de la API no significa nada para
  /// el cliente, y una sucursal cerrada arriba de todo es la primera que va a
  /// tocar.
  List<_BranchConDistancia> _ordenar(List<MobileBranch> branches, Position? pos) {
    final service = ref.read(locationServiceProvider);
    final out = [
      for (final b in branches)
        _BranchConDistancia(
          branch: b,
          km: (pos != null && b.hasCoordinates)
              ? service.distanceKm(
                  pos.latitude,
                  pos.longitude,
                  b.latitude!,
                  b.longitude!,
                )
              : null,
        ),
    ];
    out.sort((a, b) {
      if (a.km != null && b.km != null) return a.km!.compareTo(b.km!);
      if (a.km != null) return -1;
      if (b.km != null) return 1;
      if (a.branch.openNow != b.branch.openNow) return a.branch.openNow ? -1 : 1;
      return a.branch.name.toLowerCase().compareTo(b.branch.name.toLowerCase());
    });
    return out;
  }
}

class _BranchConDistancia {
  final MobileBranch branch;
  final double? km;
  const _BranchConDistancia({required this.branch, this.km});
}

// ═══════════════════════════════════════════════════════════════════════════
// PILL "Ordenar por cercanía"
// ═══════════════════════════════════════════════════════════════════════════

class _CercaniaPill extends StatelessWidget {
  final bool activo;
  final bool cargando;
  final bool sinPermiso;
  final VoidCallback onTap;

  const _CercaniaPill({
    required this.activo,
    required this.cargando,
    required this.sinPermiso,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = cargando
        ? 'Buscando dónde estás…'
        : sinPermiso
            ? 'Sin ubicación disponible'
            : activo
                ? 'Ordenadas por cercanía'
                : 'Ordenar por cercanía';
    final destacado = activo && !sinPermiso;

    return LiquidPill(
      onTap: cargando ? null : onTap,
      tint: destacado ? MonacoColors.seleccion : null,
      tintOpacity: destacado ? 0.18 : 0.10,
      padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (cargando)
            const SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(strokeWidth: 1.8, color: Colors.white),
            )
          else
            Icon(
              sinPermiso ? Icons.location_off_rounded : Icons.near_me_rounded,
              size: 14,
              color: Colors.white,
            ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TARJETA DE SUCURSAL
// ═══════════════════════════════════════════════════════════════════════════

class _BranchTile extends StatelessWidget {
  final MobileBranch branch;
  final double? distanciaKm;
  final VoidCallback onTap;

  const _BranchTile({
    required this.branch,
    required this.distanciaKm,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final estadoColor =
        branch.openNow ? MonacoColors.monacoGreen : MonacoColors.foregroundSubtle;
    return Semantics(
      button: true,
      label: 'Reservar en ${branch.name}',
      child: LiquidGlass(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        borderRadius: 22,
        tint: branch.openNow ? MonacoColors.monacoGreen : null,
        tintOpacity: branch.openNow ? 0.07 : 0.06,
        showVignette: false,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.18),
                    Colors.white.withValues(alpha: 0.06),
                  ],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 0.8),
              ),
              child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          branch.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: MonacoColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      if (distanciaKm != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          'a ${LocationService.formatDistance(distanciaKm!)}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      if (branch.isTest) ...[
                        const SizedBox(width: 8),
                        const LiquidStatusPill(
                          label: 'PRUEBA',
                          color: MonacoColors.warning,
                          pulse: false,
                          compact: true,
                        ),
                      ],
                    ],
                  ),
                  if (branch.address != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      branch.address!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if (branch.hoursLabel.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: estadoColor,
                            boxShadow: branch.openNow
                                ? [BoxShadow(color: estadoColor.withValues(alpha: 0.7), blurRadius: 6)]
                                : null,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            branch.hoursLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: estadoColor.withValues(alpha: 0.95),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.35), size: 24),
          ],
        ),
      ),
    );
  }
}
