import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/features/convenios/providers/my_redemptions_provider.dart';
import 'package:monaco_mobile/features/convenios/providers/redemption_provider.dart';

/// Tarjeta de canje con cuatro estados visuales:
///   - [isOutOfWindow] → beneficio fuera de su ventana de validez (disabled).
///   - existing == null → CTA "Activar mi código" (sin QR aún, no se emite fila).
///   - existing.status == 'issued' → QR + código + copiar + compartir.
///   - existing.status == 'used' → Canjeado con fecha, sin QR, código visible.
class RedemptionCard extends ConsumerStatefulWidget {
  final String benefitId;
  final String benefitTitle;
  final String? partnerName;
  final bool isOutOfWindow;

  const RedemptionCard({
    super.key,
    required this.benefitId,
    required this.benefitTitle,
    this.partnerName,
    this.isOutOfWindow = false,
  });

  @override
  ConsumerState<RedemptionCard> createState() => _RedemptionCardState();
}

class _RedemptionCardState extends ConsumerState<RedemptionCard> {
  bool _isIssuing = false;

  Future<void> _activate() async {
    setState(() => _isIssuing = true);
    HapticFeedback.selectionClick();
    try {
      // Dispara la RPC; cuando resuelva, también invalidamos los providers
      // dependientes para que "Mis canjes" y los chips se refresquen.
      await ref.read(redemptionProvider(widget.benefitId).future);
      ref.invalidate(existingRedemptionProvider(widget.benefitId));
      ref.invalidate(myRedemptionsProvider);
      if (mounted) {
        HapticFeedback.mediumImpact();
        showLiquidToast(
          context,
          'Código activado. Mostralo en el comercio.',
          tone: LiquidToastTone.success,
        );
      }
    } catch (e) {
      if (mounted) {
        showLiquidToast(
          context,
          LiquidErrorState.isNetworkError(e)
              ? 'Sin conexión. Revisá tu internet e intentá de nuevo.'
              : 'No pudimos activar tu código. Probá de nuevo.',
          tone: LiquidToastTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isIssuing = false);
    }
  }

  void _copyCode(String code) {
    HapticFeedback.mediumImpact();
    Clipboard.setData(ClipboardData(text: code));
    showLiquidToast(
      context,
      'Código copiado',
      tone: LiquidToastTone.success,
      icon: Icons.copy_rounded,
      duration: const Duration(milliseconds: 1800),
    );
  }

  void _shareCode(String code) {
    final partner = widget.partnerName?.isNotEmpty == true
        ? ' en ${widget.partnerName}'
        : '';
    Share.share(
      'Tengo un beneficio$partner: "${widget.benefitTitle}". Código: $code',
      subject: widget.benefitTitle,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isOutOfWindow) {
      return const _Shell(
        tint: MonacoColors.occupancyClosed,
        child: _OutOfWindowBlock(),
      );
    }

    final asyncExisting =
        ref.watch(existingRedemptionProvider(widget.benefitId));

    return asyncExisting.when(
      // Esqueleto con la misma silueta que la tarjeta de canje, para que la
      // pantalla no "salte" cuando llega el estado real.
      loading: () => const LiquidSkeleton(height: 240, radius: 24),
      error: (e, _) => _Shell(
        child: LiquidErrorState(
          error: e,
          title: 'No pudimos cargar tu código',
          scrollable: false,
          onRetry: () =>
              ref.invalidate(existingRedemptionProvider(widget.benefitId)),
        ),
      ),
      data: (redemption) {
        if (redemption == null) {
          return _Shell(
            tint: MonacoColors.monacoGreen,
            child: _IdleBlock(isLoading: _isIssuing, onActivate: _activate),
          );
        }
        if (redemption.isUsed) {
          return _Shell(
            tint: MonacoColors.monacoGreen,
            child: _UsedBlock(
              code: redemption.code,
              usedAt: redemption.usedAt,
              onCopy: () => _copyCode(redemption.code),
            ),
          );
        }
        return _Shell(
          child: _IssuedBlock(
            code: redemption.code,
            onCopy: () => _copyCode(redemption.code),
            onShare: () => _shareCode(redemption.code),
          ),
        );
      },
    );
  }
}

class _Shell extends StatelessWidget {
  final Widget child;
  final Color? tint;
  const _Shell({required this.child, this.tint});

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      tint: tint,
      tintOpacity: tint == null ? 0.09 : 0.07,
      pressable: false,
      child: child,
    );
  }
}

// ───────────────────── state widgets ─────────────────────

class _IdleBlock extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onActivate;

  const _IdleBlock({required this.isLoading, required this.onActivate});

  @override
  Widget build(BuildContext context) {
    const green = MonacoColors.monacoGreen;
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                green.withValues(alpha: 0.30),
                green.withValues(alpha: 0.10),
              ],
            ),
            border: Border.all(color: green.withValues(alpha: 0.42), width: 0.8),
            boxShadow: [
              BoxShadow(
                color: green.withValues(alpha: 0.3),
                blurRadius: 18,
                spreadRadius: -3,
              ),
            ],
          ),
          child: const Icon(Icons.confirmation_number_rounded,
              size: 28, color: green),
        ),
        const SizedBox(height: 14),
        const Text(
          'Activá tu código',
          style: TextStyle(
            color: MonacoColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Generá tu código único para mostrar al comercio. Es de un solo uso.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 13.5,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: LiquidButton(
            onPressed: isLoading ? null : onActivate,
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt_rounded, size: 18, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        'Activar mi código',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _IssuedBlock extends StatelessWidget {
  final String code;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  const _IssuedBlock({
    required this.code,
    required this.onCopy,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Mostrá este código al comercio',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        Semantics(
          label: 'Código QR del beneficio, código $code',
          image: true,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 22,
                  spreadRadius: -4,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: QrImageView(
              data: code,
              version: QrVersions.auto,
              size: 176,
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
        const SizedBox(height: 16),
        Semantics(
          button: true,
          label: 'Tocá para copiar el código $code',
          child: LiquidPill(
            onTap: onCopy,
            borderRadius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  code,
                  style: const TextStyle(
                    color: MonacoColors.textPrimary,
                    fontSize: 22,
                    letterSpacing: 4,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 10),
                Icon(Icons.copy_rounded,
                    size: 16, color: Colors.white.withValues(alpha: 0.6)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _ActionPill(
                icon: Icons.ios_share_rounded,
                label: 'Compartir',
                onTap: onShare,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionPill(
                icon: Icons.copy_all_rounded,
                label: 'Copiar',
                onTap: onCopy,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Un solo uso. El comercio lo valida desde su portal.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidPill(
      onTap: onTap,
      borderRadius: 14,
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _UsedBlock extends StatelessWidget {
  final String code;
  final DateTime? usedAt;
  final VoidCallback onCopy;

  const _UsedBlock({
    required this.code,
    required this.usedAt,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    const green = MonacoColors.monacoGreen;
    final formatted = usedAt != null
        ? DateFormat("d 'de' MMM y · HH:mm", 'es').format(usedAt!.toLocal())
        : null;

    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                green.withValues(alpha: 0.32),
                green.withValues(alpha: 0.12),
              ],
            ),
            border: Border.all(color: green.withValues(alpha: 0.45), width: 0.8),
            boxShadow: [
              BoxShadow(
                color: green.withValues(alpha: 0.32),
                blurRadius: 18,
                spreadRadius: -3,
              ),
            ],
          ),
          child: const Icon(Icons.check_rounded, color: green, size: 32),
        ),
        const SizedBox(height: 14),
        const Text(
          'Beneficio canjeado',
          style: TextStyle(
            color: MonacoColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        if (formatted != null) ...[
          const SizedBox(height: 6),
          Text(
            formatted,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Semantics(
          button: true,
          label: 'Mantené apretado para copiar el código $code',
          child: GestureDetector(
            onLongPress: onCopy,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white.withValues(alpha: 0.06),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 0.8,
                ),
              ),
              child: Text(
                code,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 15,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Este código ya fue utilizado y no se puede canjear de nuevo.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 11.5,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _OutOfWindowBlock extends StatelessWidget {
  const _OutOfWindowBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.16),
                Colors.white.withValues(alpha: 0.05),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Icon(Icons.event_busy_rounded,
              size: 26, color: Colors.white.withValues(alpha: 0.75)),
        ),
        const SizedBox(height: 12),
        const Text(
          'Este beneficio ya no está vigente',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: MonacoColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Ya no se pueden generar códigos nuevos para este beneficio.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 12.5,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
