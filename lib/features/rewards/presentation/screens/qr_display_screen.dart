import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/features/rewards/providers/rewards_provider.dart';

/// QR de un premio disponible: el barbero lo escanea desde su panel.
class QrDisplayScreen extends ConsumerWidget {
  final String clientRewardId;

  const QrDisplayScreen({super.key, required this.clientRewardId});

  void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/mis-premios');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(clientWalletProvider);

    return LiquidAppBarScaffold(
      title: 'Tu premio',
      showBackButton: true,
      centerTitle: true,
      body: walletAsync.when(
        loading: () => const _Loading(),
        error: (e, _) => LiquidErrorState(
          error: e,
          onRetry: () => ref.invalidate(clientWalletProvider),
        ),
        data: (rewards) {
          final reward = rewards.cast<Map<String, dynamic>?>().firstWhere(
                (r) => r?['client_reward_id']?.toString() == clientRewardId,
                orElse: () => null,
              );

          if (reward == null) {
            return LiquidEmptyState(
              icon: Icons.search_off_rounded,
              title: 'Premio no encontrado',
              message: 'Puede que ya lo hayas usado o que haya vencido.',
              ctaLabel: 'Volver',
              onCta: () => _close(context),
            );
          }

          final rewardName = reward['reward_name'] as String? ?? 'Premio';
          final description =
              (reward['reward_description'] as String?)?.trim();
          final etiquetaTipo = _etiquetaDe(reward);
          final qrCode = reward['qr_code'] as String? ?? '';
          final expiresRaw = reward['expires_at'] as String?;
          final expiresAt =
              expiresRaw != null ? DateTime.tryParse(expiresRaw) : null;

          if (qrCode.isEmpty) {
            return LiquidEmptyState(
              icon: Icons.qr_code_2_rounded,
              title: 'Este premio no tiene código',
              message:
                  'Mostrale el premio al barbero desde Mis premios y lo aplica a mano.',
              ctaLabel: 'Volver',
              onCta: () => _close(context),
            );
          }

          return _QrBody(
            rewardName: rewardName,
            description: description,
            etiquetaTipo: etiquetaTipo,
            qrCode: qrCode,
            expiresAt: expiresAt,
            onClose: () => _close(context),
          );
        },
      ),
    );
  }
}

class _QrBody extends StatelessWidget {
  final String rewardName;
  final String? description;
  final String etiquetaTipo;
  final String qrCode;
  final DateTime? expiresAt;
  final VoidCallback onClose;

  const _QrBody({
    required this.rewardName,
    required this.description,
    required this.etiquetaTipo,
    required this.qrCode,
    required this.expiresAt,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    String? expiresLabel;
    Color expiresColor = MonacoColors.monacoGreen;
    if (expiresAt != null) {
      final local = expiresAt!.toLocal();
      final daysLeft = local.difference(now).inDays;
      expiresLabel =
          'Vence el ${DateFormat("d 'de' MMM", 'es').format(local)}';
      if (local.isBefore(now)) {
        expiresLabel = 'Vencido';
        expiresColor = MonacoColors.destructive;
      } else if (daysLeft <= 3) {
        expiresColor = MonacoColors.warning;
      }
    }

    final qrSize = (MediaQuery.sizeOf(context).width - 48 - 44 - 36)
        .clamp(180.0, 250.0);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            rewardName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: MonacoColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
              height: 1.15,
            ),
          ).liquidEnter(index: 0),
          if (etiquetaTipo.isNotEmpty) ...[
            const SizedBox(height: 10),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.14),
                      Colors.white.withValues(alpha: 0.06),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                    width: 0.6,
                  ),
                ),
                child: Text(
                  etiquetaTipo,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ).liquidEnter(index: 1),
          ],
          if (description != null && description!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              description!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13.5,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ).liquidEnter(index: 1),
          ],
          const SizedBox(height: 24),

          // ── Tarjeta con el QR ──
          LiquidGlass(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            borderRadius: 28,
            tintOpacity: 0.10,
            pressable: false,
            child: Column(
              children: [
                Semantics(
                  label: 'Código QR del premio $rewardName',
                  image: true,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 26,
                          spreadRadius: -6,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: qrCode,
                      version: QrVersions.auto,
                      size: qrSize,
                      gapless: true,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Color(0xFF111111),
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Color(0xFF111111),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Mostrá este código al barbero',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if (expiresLabel != null) ...[
                  const SizedBox(height: 12),
                  LiquidStatusPill(
                    label: expiresLabel,
                    color: expiresColor,
                    pulse: false,
                    compact: true,
                  ),
                ],
              ],
            ),
          ).liquidEnter(index: 2),
          const SizedBox(height: 16),
          Text(
            'Lo escanea desde su panel y el premio se aplica en el momento.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12.5,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ).liquidEnter(index: 3),
          const SizedBox(height: 26),
          LiquidButton(
            onPressed: onClose,
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: const Text(
              'Listo',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ).liquidEnter(index: 4),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      children: const [
        Center(child: LiquidSkeleton.line(width: 220, height: 24)),
        SizedBox(height: 12),
        Center(child: LiquidSkeleton.line(width: 120, height: 14)),
        SizedBox(height: 26),
        LiquidSkeleton(height: 340, radius: 28),
        SizedBox(height: 26),
        LiquidSkeleton(height: 52, radius: 16),
      ],
    );
  }
}

/// Qué ES el premio, en criollo.
///
/// El mapeo anterior traducía `free_service`, `discount` y `product`, que **no
/// existen** en el enum `reward_type` (`spin_prize | return_discount |
/// milestone_free | manual | points_redemption`): la pantalla terminaba
/// imprimiendo "spin prize" y "milestone free" tal cual. Manda lo que el
/// premio hace; el tipo sólo desempata. Misma regla que `MisPremiosScreen`.
String _etiquetaDe(Map<String, dynamic> r) {
  if (r['is_free_service'] == true) return 'Servicio gratis';
  final pct = (r['discount_pct'] as num?)?.toInt() ?? 0;
  if (pct > 0) return '$pct% de descuento';
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
