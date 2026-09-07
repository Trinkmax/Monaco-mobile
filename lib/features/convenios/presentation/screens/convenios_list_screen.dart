import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:monaco_mobile/core/auth/auth_provider.dart';
import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/features/convenios/presentation/widgets/convenio_card.dart';
import 'package:monaco_mobile/features/convenios/providers/convenios_provider.dart';
import 'package:monaco_mobile/features/convenios/providers/my_redemptions_provider.dart';

/// Lista completa de convenios (beneficios de comercios aliados).
class ConveniosListScreen extends ConsumerWidget {
  const ConveniosListScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(conveniosProvider);
    ref.invalidate(myRedemptionsProvider);
    await ref.read(conveniosProvider.future).then((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncBenefits = ref.watch(conveniosProvider);
    // "Mis canjes" es personal: sin cuenta el router la bloquea y el botón
    // rebotaría al Home sin decir nada. Se esconde en vez de mentir.
    final invitado = ref.watch(authProvider.select((a) => a.isGuest));

    return LiquidAppBarScaffold(
      title: 'Convenios',
      showBackButton: true,
      actions: [
        if (!invitado)
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: LiquidPill(
              onTap: () => context.push('/mis-canjes'),
              padding: const EdgeInsets.fromLTRB(12, 7, 10, 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.confirmation_number_outlined,
                    size: 15,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Mis canjes',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
      body: RefreshIndicator(
        color: Colors.white,
        backgroundColor: MonacoColors.surface,
        onRefresh: () => _refresh(ref),
        child: asyncBenefits.when(
          loading: () => const LiquidSkeletonList(
            count: 5,
            itemHeight: 112,
            padding: EdgeInsets.fromLTRB(20, 12, 20, 48),
          ),
          error: (e, _) =>
              LiquidErrorState(error: e, onRetry: () => _refresh(ref)),
          data: (items) {
            if (items.isEmpty) {
              return const LiquidEmptyState(
                icon: Icons.local_offer_outlined,
                title: 'Todavía no hay convenios',
                message:
                    'Muy pronto vas a tener beneficios exclusivos de comercios aliados a tu barbería.',
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
              itemCount: items.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: LiquidSectionTitle(
                      title: 'Beneficios para vos',
                      subtitle: items.length == 1
                          ? '1 convenio vigente'
                          : '${items.length} convenios vigentes',
                    ),
                  ).liquidEnter(index: 0);
                }
                final b = items[i - 1];
                return ConvenioListCard(
                  benefit: b,
                  onTap: () => context.push('/convenio/${b['id']}'),
                ).liquidEnter(index: i);
              },
            );
          },
        ),
      ),
    );
  }
}
