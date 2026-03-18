import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/features/rewards/providers/rewards_provider.dart';

class QrDisplayScreen extends ConsumerWidget {
  final String clientRewardId;

  const QrDisplayScreen({super.key, required this.clientRewardId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(clientWalletProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: walletAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: MonacoColors.primary),
          ),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: MonacoColors.destructive, size: 48),
                const SizedBox(height: 12),
                const Text(
                  'Error al cargar el premio',
                  style: TextStyle(
                    color: MonacoColors.foregroundSubtle,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 24),
                _buildCloseButton(context),
              ],
            ),
          ),
          data: (rewards) {
            final reward = rewards.cast<Map<String, dynamic>?>().firstWhere(
                  (r) =>
                      r?['client_reward_id']?.toString() == clientRewardId,
                  orElse: () => null,
                );

            if (reward == null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.search_off_rounded,
                        color: MonacoColors.foregroundSubtle, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'Premio no encontrado',
                      style: TextStyle(
                        color: MonacoColors.foregroundSubtle,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildCloseButton(context),
                  ],
                ),
              );
            }

            final rewardName =
                reward['reward_name'] as String? ?? 'Premio';
            final qrCode = reward['qr_code'] as String? ?? '';

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  Text(
                    rewardName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: MonacoColors.foreground,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: QrImageView(
                      data: qrCode,
                      version: QrVersions.auto,
                      size: 240,
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
                  const SizedBox(height: 28),
                  const Text(
                    'Mostrá este código al barbero',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: MonacoColors.foregroundSubtle,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(flex: 3),
                  _buildCloseButton(context),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCloseButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: () => context.pop(),
        style: ElevatedButton.styleFrom(
          backgroundColor: MonacoColors.surface,
          foregroundColor: MonacoColors.foreground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: MonacoColors.border),
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: const Text('Cerrar'),
      ),
    );
  }
}
