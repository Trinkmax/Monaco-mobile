import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/features/convenios/providers/convenios_provider.dart';
import 'package:monaco_mobile/features/convenios/presentation/widgets/convenio_card.dart';

class ConveniosListScreen extends ConsumerWidget {
  const ConveniosListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncBenefits = ref.watch(conveniosProvider);

    return Scaffold(
      backgroundColor: MonacoColors.background,
      appBar: AppBar(
        backgroundColor: MonacoColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: MonacoColors.foreground, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Convenios',
          style: TextStyle(
            color: MonacoColors.foreground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: MonacoColors.gold,
        backgroundColor: MonacoColors.surface,
        onRefresh: () async => ref.invalidate(conveniosProvider),
        child: asyncBenefits.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: MonacoColors.gold),
          ),
          error: (e, _) => _ErrorState(onRetry: () => ref.invalidate(conveniosProvider)),
          data: (items) {
            if (items.isEmpty) return const _EmptyState();
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final b = items[i];
                return ConvenioListCard(
                  benefit: b,
                  onTap: () => context.push('/convenio/${b['id']}'),
                )
                    .animate()
                    .fadeIn(delay: Duration(milliseconds: 60 * i), duration: 400.ms)
                    .slideY(begin: 0.08, end: 0);
              },
            );
          },
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 100),
      children: [
        Icon(Icons.local_offer_outlined,
            size: 72, color: MonacoColors.gold.withOpacity(0.4)),
        const SizedBox(height: 16),
        const Text(
          'Todavía no hay convenios',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: MonacoColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Muy pronto vas a tener beneficios exclusivos de comercios aliados a tu barbería.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: MonacoColors.textSecondary,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline,
              size: 56, color: MonacoColors.destructive),
          const SizedBox(height: 12),
          const Text(
            'No pudimos cargar los convenios',
            style: TextStyle(color: MonacoColors.textPrimary, fontSize: 15),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            child: const Text('Reintentar',
                style: TextStyle(color: MonacoColors.gold)),
          ),
        ],
      ),
    );
  }
}
