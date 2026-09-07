import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/features/rewards/data/beneficio_canjeado.dart';
import 'package:monaco_mobile/features/rewards/providers/rewards_provider.dart';

final _pts = NumberFormat.decimalPattern('es_AR');
final _diaMes = DateFormat('dd/MM');

/// **Mis premios** — la billetera completa: lo que está listo para usar y el
/// historial (usados, vencidos y cancelados).
///
/// Es la pantalla que antes ocupaba el tab `/rewards`. Ahora el tab lo ocupa la
/// tienda (`PremiosScreen`), que muestra arriba una tira con los premios listos;
/// esta es el "ver todos" de esa tira y el lugar donde queda el historial.
class MisPremiosScreen extends ConsumerStatefulWidget {
  const MisPremiosScreen({super.key});

  @override
  ConsumerState<MisPremiosScreen> createState() => _MisPremiosScreenState();
}

class _MisPremiosScreenState extends ConsumerState<MisPremiosScreen> {
  /// `null` = el cliente todavía no eligió solapa: se abre la que TIENE
  /// contenido. "Premios que ya usaste" (Premios) aterrizaba siempre en
  /// "Para usar", vacía por construcción en ese camino.
  int? _tab;

  Future<void> _refresh() async {
    ref.invalidate(clientWalletProvider);
    await ref.read(clientWalletProvider.future).then((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(clientWalletProvider);
    final rewards = walletAsync.valueOrNull;
    final tab = _tab ??
        ((rewards != null &&
                rewards.isNotEmpty &&
                !rewards.any((r) =>
                    BeneficioCanjeado.estadoDe(r) ==
                    EstadoBeneficio.disponible))
            ? 1
            : 0);

    return LiquidAppBarScaffold(
      title: 'Mis premios',
      showBackButton: true,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: LiquidSegmentedTabs(
              labels: const ['Para usar', 'Historial'],
              selectedIndex: tab,
              onChange: (i) => setState(() => _tab = i),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: RefreshIndicator(
              color: Colors.white,
              backgroundColor: MonacoColors.surface,
              onRefresh: _refresh,
              child: walletAsync.when(
                loading: () => const LiquidSkeletonList(
                  count: 4,
                  itemHeight: 132,
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 48),
                ),
                error: (e, _) => LiquidErrorState(error: e, onRetry: _refresh),
                data: (rewards) {
                  final disponibles = rewards
                      .where((r) =>
                          BeneficioCanjeado.estadoDe(r) ==
                          EstadoBeneficio.disponible)
                      .toList();
                  final historial = rewards
                      .where((r) =>
                          BeneficioCanjeado.estadoDe(r) !=
                          EstadoBeneficio.disponible)
                      .toList();

                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: tab == 0
                        ? _Lista(
                            key: const ValueKey('disponibles'),
                            rewards: disponibles,
                            emptyIcon: Icons.card_giftcard_rounded,
                            emptyTitle: 'Todavía no tenés premios',
                            emptyMessage:
                                'Sumá puntos con cada visita y canjealos por premios del catálogo.',
                            emptyCtaLabel: 'Ver premios',
                            onEmptyCta: () => context.go('/rewards'),
                          )
                        : _Lista(
                            key: const ValueKey('historial'),
                            rewards: historial,
                            emptyIcon: Icons.history_rounded,
                            emptyTitle: 'Sin historial todavía',
                            emptyMessage:
                                'Acá van a quedar los premios que ya usaste, los que vencieron y los que se cancelaron.',
                          ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Lista extends StatelessWidget {
  final List<Map<String, dynamic>> rewards;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;
  final String? emptyCtaLabel;
  final VoidCallback? onEmptyCta;

  const _Lista({
    super.key,
    required this.rewards,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyMessage,
    this.emptyCtaLabel,
    this.onEmptyCta,
  });

  @override
  Widget build(BuildContext context) {
    if (rewards.isEmpty) {
      return LiquidEmptyState(
        icon: emptyIcon,
        title: emptyTitle,
        message: emptyMessage,
        ctaLabel: emptyCtaLabel,
        onCta: onEmptyCta,
        padding: const EdgeInsets.fromLTRB(32, 56, 32, 48),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 48),
      itemCount: rewards.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) =>
          _RewardCard(reward: rewards[i]).liquidEnter(index: i),
    );
  }
}

/// Una fila de `get_client_wallet`: nombre, qué es (por `kind`), estado con
/// color, cuándo vence / cuándo se usó / por qué se canceló, y el QR si está
/// disponible.
class _RewardCard extends StatelessWidget {
  final Map<String, dynamic> reward;

  const _RewardCard({required this.reward});

  static IconData _icono(Map<String, dynamic> r) {
    switch ((r['kind'] ?? '').toString()) {
      case 'merch':
        return Icons.redeem_rounded;
      case 'especial':
        return Icons.auto_awesome_rounded;
      default:
        return r['is_free_service'] == true
            ? Icons.content_cut_rounded
            : Icons.percent_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = reward;
    final name = r['reward_name'] as String? ?? 'Premio';
    final description = (r['reward_description'] as String?)?.trim();
    final estado = BeneficioCanjeado.estadoDe(r);
    final clientRewardId = r['client_reward_id']?.toString() ?? '';
    final accent = estado.color;
    final disponible = estado == EstadoBeneficio.disponible;
    final gastados = BeneficioCanjeado.puntosGastados(r);
    final motivo = BeneficioCanjeado.motivoCancelacion(r);

    // La segunda línea de contexto depende del estado: lo que importa de un
    // premio disponible es cuándo vence; de uno usado, cuándo; de uno
    // cancelado, por qué.
    String? cuando;
    switch (estado) {
      case EstadoBeneficio.disponible:
        cuando = BeneficioCanjeado.cuentaRegresiva(
          BeneficioCanjeado.vencimiento(r),
        )?.label;
      case EstadoBeneficio.utilizado:
        final el = BeneficioCanjeado.utilizadoEl(r);
        cuando = el == null ? null : 'Usado el ${_diaMes.format(el)}';
      case EstadoBeneficio.vencido:
        final el = BeneficioCanjeado.vencimiento(r);
        cuando = el == null ? null : 'Venció el ${_diaMes.format(el)}';
      case EstadoBeneficio.cancelado:
        cuando = null;
    }

    return Semantics(
      label: '$name, ${estado.label}',
      child: LiquidGlass(
        padding: const EdgeInsets.all(16),
        borderRadius: 20,
        tint: disponible ? MonacoColors.monacoGreen : null,
        tintOpacity: disponible ? 0.07 : 0.04,
        pressable: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accent.withValues(alpha: 0.26),
                        accent.withValues(alpha: 0.08),
                      ],
                    ),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.34),
                      width: 0.8,
                    ),
                  ),
                  child: Icon(_icono(r), size: 18, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: MonacoColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (description != null && description.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                LiquidStatusPill(
                  label: estado.label,
                  color: accent,
                  pulse: disponible,
                  compact: true,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _MetaChip(
                  icon: Icons.sell_outlined,
                  label: BeneficioCanjeado.etiqueta(r),
                ),
                if (cuando != null)
                  _MetaChip(icon: Icons.schedule_rounded, label: cuando),
                if (gastados != null)
                  _MetaChip(
                    icon: Icons.stars_rounded,
                    label: '${_pts.format(gastados)} pts',
                  ),
              ],
            ),
            if (estado == EstadoBeneficio.cancelado) ...[
              const SizedBox(height: 10),
              Text(
                motivo == null
                    ? 'Cancelado por la barbería.'
                    : 'Cancelado por la barbería: $motivo',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
            ],
            if (disponible) ...[
              const SizedBox(height: 14),
              LiquidButton(
                onPressed: () => context.push('/reward-qr/$clientRewardId'),
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.qr_code_rounded, size: 18, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Mostrar código',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.14),
            Colors.white.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 0.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white.withValues(alpha: 0.7)),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
