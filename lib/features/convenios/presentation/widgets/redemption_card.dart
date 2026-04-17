import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/features/convenios/providers/my_redemptions_provider.dart';
import 'package:monaco_mobile/features/convenios/providers/redemption_provider.dart';

/// Tarjeta de canje con cuatro estados visuales:
///   - [isOutOfWindow] → beneficio fuera de su ventana de validez (disabled).
///   - existing == null → CTA "Activar mi código" (sin QR aún, no se emite fila).
///   - existing.status == 'issued' → QR + código + copy + share.
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No pudimos activar: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isIssuing = false);
    }
  }

  void _copyCode(String code) {
    HapticFeedback.mediumImpact();
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Código copiado'),
        duration: Duration(seconds: 2),
      ),
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
      return _OutOfWindowCard();
    }

    final asyncExisting =
        ref.watch(existingRedemptionProvider(widget.benefitId));

    return asyncExisting.when(
      loading: () => _shell(
        child: const SizedBox(
          height: 220,
          child: Center(
            child: CircularProgressIndicator(color: MonacoColors.gold),
          ),
        ),
      ),
      error: (e, _) => _shell(
        child: _ErrorBlock(
          message: e.toString(),
          onRetry: () =>
              ref.invalidate(existingRedemptionProvider(widget.benefitId)),
        ),
      ),
      data: (redemption) {
        if (redemption == null) {
          return _shell(child: _IdleBlock(isLoading: _isIssuing, onActivate: _activate));
        }
        if (redemption.isUsed) {
          return _shell(
            child: _UsedBlock(
              code: redemption.code,
              usedAt: redemption.usedAt,
              onCopy: () => _copyCode(redemption.code),
            ),
          );
        }
        return _shell(
          child: _IssuedBlock(
            code: redemption.code,
            onCopy: () => _copyCode(redemption.code),
            onShare: () => _shareCode(redemption.code),
          ),
        );
      },
    );
  }

  Widget _shell({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MonacoColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MonacoColors.borderStrong),
      ),
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
    return Column(
      children: [
        Icon(Icons.confirmation_number_outlined,
            size: 40, color: MonacoColors.gold),
        const SizedBox(height: 12),
        const Text(
          'Activá tu código',
          style: TextStyle(
            color: MonacoColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Generá tu código único para mostrar al comercio. Un solo uso.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: MonacoColors.textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: MonacoColors.primary,
              foregroundColor: MonacoColors.primaryForeground,
              disabledBackgroundColor: MonacoColors.surfaceVariant,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            onPressed: isLoading ? null : onActivate,
            child: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: MonacoColors.primaryForeground,
                    ),
                  )
                : const Text(
                    'Activar mi código',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 0.3,
                    ),
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
        const Text(
          'Mostrá este código al comercio',
          style: TextStyle(
            color: MonacoColors.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 14),
        Semantics(
          label: 'Código QR del beneficio, código $code',
          image: true,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: QrImageView(
              data: code,
              version: QrVersions.auto,
              size: 170,
              gapless: true,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          button: true,
          label: 'Tocá para copiar el código $code',
          child: GestureDetector(
            onTap: onCopy,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: MonacoColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: MonacoColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SelectableText(
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
                  const Icon(Icons.copy_outlined,
                      size: 16, color: MonacoColors.foregroundSubtle),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onShare,
                icon: const Icon(Icons.ios_share_rounded, size: 16),
                label: const Text('Compartir'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MonacoColors.textPrimary,
                  side: const BorderSide(color: MonacoColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onCopy,
                icon: const Icon(Icons.copy_all_outlined, size: 16),
                label: const Text('Copiar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MonacoColors.textPrimary,
                  side: const BorderSide(color: MonacoColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Un solo uso. El comercio valida desde su portal.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: MonacoColors.foregroundSubtle,
            fontSize: 11,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms);
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
    final formatted = usedAt != null
        ? DateFormat("d 'de' MMM y · HH:mm", 'es').format(usedAt!.toLocal())
        : null;

    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: MonacoColors.success.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded,
              color: MonacoColors.success, size: 32),
        ),
        const SizedBox(height: 12),
        const Text(
          'Beneficio canjeado',
          style: TextStyle(
            color: MonacoColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (formatted != null) ...[
          const SizedBox(height: 6),
          Text(
            formatted,
            style: const TextStyle(
              color: MonacoColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
        const SizedBox(height: 16),
        GestureDetector(
          onLongPress: onCopy,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: MonacoColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: MonacoColors.border),
            ),
            child: SelectableText(
              code,
              style: const TextStyle(
                color: MonacoColors.textSecondary,
                fontSize: 15,
                letterSpacing: 3,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Este código ya fue utilizado y no se puede canjear de nuevo.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: MonacoColors.foregroundSubtle,
            fontSize: 11,
            height: 1.4,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _OutOfWindowCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MonacoColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MonacoColors.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.event_busy_rounded,
              size: 36, color: MonacoColors.foregroundSubtle),
          SizedBox(height: 10),
          Text(
            'Este beneficio ya no está vigente',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: MonacoColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Ya no se pueden generar códigos nuevos para este beneficio.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: MonacoColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBlock({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Icon(Icons.error_outline,
              color: MonacoColors.destructive, size: 36),
          const SizedBox(height: 10),
          const Text(
            'No se pudo cargar tu código',
            style: TextStyle(
              color: MonacoColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: MonacoColors.textSecondary,
              fontSize: 12,
            ),
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
