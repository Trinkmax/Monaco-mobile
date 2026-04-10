import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/core/auth/auth_provider.dart';
import 'package:monaco_mobile/features/branch_selection/providers/branch_selection_provider.dart';
import '../widgets/branch_selection_card.dart';

class BranchSelectionScreen extends ConsumerWidget {
  const BranchSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branches = ref.watch(nearbyBranchesProvider);
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: MonacoColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Botón volver a selección de org
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () {
                    ref.read(authProvider.notifier).clearSelectedOrg();
                    context.go('/select-org');
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_back_ios,
                          size: 16, color: MonacoColors.gold),
                      const SizedBox(width: 4),
                      Text(
                        authState.selectedOrgName ?? 'Cambiar barbería',
                        style: const TextStyle(
                          color: MonacoColors.gold,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Seleccioná tu\nsucursal',
                style: TextStyle(
                  color: MonacoColors.textPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              )
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .slideX(begin: -0.05, end: 0, duration: 500.ms),
              const SizedBox(height: 8),
              Text(
                'Elegí la sucursal donde querés atenderte',
                style: TextStyle(
                  color: MonacoColors.textSecondary,
                  fontSize: 15,
                ),
              ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
              const SizedBox(height: 28),

              // Lista de sucursales
              Expanded(
                child: branches.when(
                  data: (list) {
                    if (list.isEmpty) {
                      return const Center(
                        child: Text(
                          'No hay sucursales disponibles',
                          style: TextStyle(color: MonacoColors.textSecondary),
                        ),
                      );
                    }

                    // Si hay una sola sucursal, auto-seleccionar
                    if (list.length == 1) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _selectBranch(context, ref, list.first.id, list.first.name);
                      });
                    }

                    return RefreshIndicator(
                      color: MonacoColors.gold,
                      backgroundColor: MonacoColors.surface,
                      onRefresh: () async {
                        ref.invalidate(nearbyBranchesProvider);
                      },
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final branch = list[i];
                          return BranchSelectionCard(
                            branch: branch,
                            onTap: () => _selectBranch(
                              context,
                              ref,
                              branch.id,
                              branch.name,
                            ),
                          )
                              .animate()
                              .fadeIn(
                                delay: Duration(milliseconds: 100 * i),
                                duration: 400.ms,
                              )
                              .slideY(
                                begin: 0.1,
                                end: 0,
                                delay: Duration(milliseconds: 100 * i),
                                duration: 400.ms,
                              );
                        },
                      ),
                    );
                  },
                  loading: () => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          color: MonacoColors.gold,
                          strokeWidth: 2,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Buscando sucursales cercanas...',
                          style: TextStyle(
                            color: MonacoColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  error: (e, _) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: MonacoColors.destructive,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Error al cargar sucursales',
                          style: TextStyle(
                            color: MonacoColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => ref.invalidate(nearbyBranchesProvider),
                          child: const Text(
                            'Reintentar',
                            style: TextStyle(color: MonacoColors.gold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectBranch(
    BuildContext context,
    WidgetRef ref,
    String branchId,
    String branchName,
  ) {
    ref.read(authProvider.notifier).setSelectedBranch(branchId, branchName);
    context.go('/home');
  }
}
