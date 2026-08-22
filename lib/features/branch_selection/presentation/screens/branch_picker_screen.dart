import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/core/auth/auth_provider.dart';
import 'package:monaco_mobile/core/branch/selected_branch_provider.dart';
import 'package:monaco_mobile/features/onboarding/presentation/widgets/onboarding_scaffold.dart';

import '../../models/branch_with_distance.dart';
import '../../providers/branch_selection_provider.dart';
import '../widgets/branch_card.dart';

/// Selector de sucursal. En onboarding (después del OTP) no hay vuelta atrás
/// y elegir lleva a /home; desde Home/Perfil es "Cambiar sucursal" y elegir
/// vuelve a la pantalla anterior.
class BranchPickerScreen extends ConsumerStatefulWidget {
  final bool onboarding;
  const BranchPickerScreen({super.key, required this.onboarding});

  @override
  ConsumerState<BranchPickerScreen> createState() => _BranchPickerScreenState();
}

class _BranchPickerScreenState extends ConsumerState<BranchPickerScreen> {
  String? _choosingId;

  Future<void> _choose(BranchWithDistance b) async {
    if (_choosingId != null) return;
    HapticFeedback.selectionClick();
    setState(() => _choosingId = b.id);
    try {
      await ref
          .read(authProvider.notifier)
          .setSelectedBranch(
            b.id,
            b.name,
            operationMode: b.operationMode,
            slug: b.slug,
          );
      if (!mounted) return;
      if (widget.onboarding) {
        // El redirect del router deja pasar /elegir-sucursal con sesión
        // autenticada, así que el salto a Home lo damos nosotros.
        context.go('/home');
      } else {
        showLiquidToast(
          context,
          'Ahora estás en ${b.name}',
          tone: LiquidToastTone.success,
          icon: Icons.storefront_rounded,
        );
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _choosingId = null);
      showLiquidToast(
        context,
        'No pudimos guardar la sucursal. Probá de nuevo.',
        tone: LiquidToastTone.error,
      );
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(allBranchesProvider);
    ref.invalidate(testModeProvider);
    try {
      await ref.read(branchesProvider.future);
    } catch (_) {}
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final onboarding = widget.onboarding;
    final branches = ref.watch(branchesWithDistanceProvider);
    final locating = ref.watch(locationPendingProvider);
    final currentId = ref.watch(selectedBranchIdProvider);
    final firstName = ref.watch(authProvider.select((s) => s.firstName));

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 8),
      child: OnboardingTitle(
        title: onboarding ? '¿A qué sucursal vas?' : 'Cambiar sucursal',
        subtitle: onboarding
            ? (firstName.isEmpty
                  ? 'La podés cambiar cuando quieras.'
                  : 'Bienvenido, $firstName. La podés cambiar cuando quieras.')
            : 'Los turnos, la fila y las novedades se muestran para la sucursal que elijas.',
      ),
    ).liquidEnter(index: 0);

    return PopScope(
      canPop: !onboarding,
      child: OnboardingScaffold(
        orbs: onboarding,
        showBack: !onboarding,
        onBack: _back,
        scrollable: false,
        padding: EdgeInsets.zero,
        topRight: onboarding ? const MonacoLogo.monogram(width: 30) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            Expanded(
              child: RefreshIndicator(
                color: Colors.white,
                backgroundColor: MonacoColors.surface,
                onRefresh: _refresh,
                child: branches.when(
                  loading: () => const LiquidSkeletonList(
                    count: 3,
                    itemHeight: 132,
                    padding: EdgeInsets.fromLTRB(20, 12, 20, 40),
                  ),
                  error: (e, _) => LiquidErrorState(
                    error: e,
                    onRetry: _refresh,
                    title: 'No pudimos cargar las sucursales',
                  ),
                  data: (list) {
                    if (list.isEmpty) {
                      return LiquidEmptyState(
                        icon: Icons.storefront_outlined,
                        title: 'Sin sucursales disponibles',
                        message:
                            'No encontramos sucursales activas. Probá de nuevo en un momento.',
                        ctaLabel: 'Reintentar',
                        onCta: _refresh,
                      );
                    }
                    return ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: EdgeInsets.fromLTRB(
                        20,
                        12,
                        20,
                        onboarding ? 40 : 40,
                      ),
                      itemCount: list.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        if (i == list.length) {
                          return _FooterHint(
                            locating: locating,
                            hasAnyDistance: list.any(
                              (b) => b.distanceKm != null,
                            ),
                          ).liquidEnter(index: i + 1);
                        }
                        final b = list[i];
                        final busy = _choosingId == b.id;
                        return AnimatedOpacity(
                          key: ValueKey(b.id),
                          duration: LiquidTokens.swap,
                          opacity: _choosingId != null && !busy ? 0.55 : 1,
                          child: BranchCard(
                            branch: b,
                            selected: !onboarding && currentId == b.id,
                            onTap: () => _choose(b),
                          ),
                        ).liquidEnter(index: i + 1, stagger: 70);
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pie de lista: estado de la ubicación (sin bloquear nada) y aclaración.
class _FooterHint extends StatelessWidget {
  final bool locating;
  final bool hasAnyDistance;
  const _FooterHint({required this.locating, required this.hasAnyDistance});

  @override
  Widget build(BuildContext context) {
    final String text;
    final IconData icon;
    if (locating) {
      text = 'Buscando tu ubicación para ordenar por cercanía…';
      icon = Icons.my_location_rounded;
    } else if (hasAnyDistance) {
      text = 'Ordenadas por cercanía. El estado se actualiza en vivo.';
      icon = Icons.near_me_rounded;
    } else {
      text = 'Activá la ubicación para ver cuál te queda más cerca.';
      icon = Icons.location_off_rounded;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.4)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}
