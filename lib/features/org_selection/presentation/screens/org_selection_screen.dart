import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/core/auth/auth_provider.dart';
import 'package:monaco_mobile/features/org_selection/providers/org_selection_provider.dart';
import '../widgets/org_selection_card.dart';

class OrgSelectionScreen extends ConsumerWidget {
  const OrgSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgs = ref.watch(nearbyOrgsProvider);

    return Scaffold(
      backgroundColor: MonacoColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Text(
                'Elegí tu\nbarbería',
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
                'Seleccioná la barbería donde querés atenderte',
                style: TextStyle(
                  color: MonacoColors.textSecondary,
                  fontSize: 15,
                ),
              ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
              const SizedBox(height: 28),

              // Lista de organizaciones
              Expanded(
                child: orgs.when(
                  data: (list) {
                    if (list.isEmpty) {
                      return const Center(
                        child: Text(
                          'No hay barberías disponibles',
                          style: TextStyle(color: MonacoColors.textSecondary),
                        ),
                      );
                    }

                    // Si hay una sola org, auto-seleccionar
                    if (list.length == 1) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _selectOrg(context, ref, list.first);
                      });
                    }

                    return RefreshIndicator(
                      color: MonacoColors.gold,
                      backgroundColor: MonacoColors.surface,
                      onRefresh: () async {
                        ref.invalidate(nearbyOrgsProvider);
                      },
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final org = list[i];
                          return OrgSelectionCard(
                            org: org,
                            onTap: () => _selectOrg(context, ref, org),
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
                          'Buscando barberías cercanas...',
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
                          'Error al cargar barberías',
                          style: TextStyle(
                            color: MonacoColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => ref.invalidate(nearbyOrgsProvider),
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

  void _selectOrg(BuildContext context, WidgetRef ref, org) {
    ref.read(authProvider.notifier).setSelectedOrg(org.id, org.name);
    context.go('/home');
  }
}
