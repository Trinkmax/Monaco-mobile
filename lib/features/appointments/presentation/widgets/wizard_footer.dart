import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';

import '../../data/fechas.dart';
import '../../providers/booking_provider.dart';

/// Pie fijo del wizard: resumen (servicios + precio + hora con barbero),
/// nombre inline si no lo conocemos, casilla de política (sólo en el paso 2
/// con hora elegida), error visible y los botones Atrás / CTA.
class WizardFooter extends StatelessWidget {
  final BookingWizardState state;
  final bool needsName;
  final bool canProceed;
  final bool showBack;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final ValueChanged<bool> onPolicy;
  final ValueChanged<String> onName;
  final TextEditingController nameController;
  final GlobalKey ctaKey;

  const WizardFooter({
    super.key,
    required this.state,
    required this.needsName,
    required this.canProceed,
    required this.showBack,
    required this.onBack,
    required this.onNext,
    required this.onPolicy,
    required this.onName,
    required this.nameController,
    required this.ctaKey,
  });

  @override
  Widget build(BuildContext context) {
    final esSlot = state.phase == WizardPhase.slot;
    final slot = state.selectedSlot;
    final servicios = state.selectedServices;
    final mostrarResumen = servicios.isNotEmpty;
    final mostrarPolitica = esSlot && slot != null;
    final mostrarNombre = esSlot && slot != null && needsName;
    final n = state.settings?.cancellationMinHours ?? 2;
    final ctaLabel = esSlot ? 'Confirmar turno' : 'Continuar';
    final enabled = canProceed && !state.submitting && (!mostrarNombre || state.nameInputValid);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: LiquidTokens.blurHeavy, sigmaY: LiquidTokens.blurHeavy),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF151515).withValues(alpha: 0.92),
                const Color(0xFF0B0B0B).withValues(alpha: 0.97),
              ],
            ),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.14), width: 0.8),
            ),
            boxShadow: LiquidTokens.dockLift(),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (mostrarResumen) ...[
                    _Resumen(state: state),
                    const SizedBox(height: 10),
                  ],
                  AnimatedSize(
                    duration: LiquidTokens.swap,
                    curve: LiquidTokens.curveSwap,
                    alignment: Alignment.topCenter,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (mostrarNombre) ...[
                          LiquidTextField(
                            controller: nameController,
                            label: '¿A NOMBRE DE QUIÉN VA?',
                            hint: 'Nombre y apellido',
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [],
                            maxLength: 60,
                            onChanged: onName,
                            prefix: Icon(Icons.person_outline_rounded,
                                size: 18, color: Colors.white.withValues(alpha: 0.6)),
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (mostrarPolitica) ...[
                          _Politica(
                            accepted: state.policyAccepted,
                            horas: n,
                            onChanged: onPolicy,
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (state.error != null) ...[
                          _ErrorBanner(text: state.error!),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      if (showBack) ...[
                        LiquidPill(
                          onTap: state.submitting ? null : onBack,
                          borderRadius: 16,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: Colors.white),
                              SizedBox(width: 6),
                              Text(
                                'Atrás',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Semantics(
                          button: true,
                          enabled: enabled,
                          label: ctaLabel,
                          child: Opacity(
                            opacity: enabled ? 1 : 0.55,
                            child: LiquidButton(
                              key: ctaKey,
                              onPressed: enabled ? onNext : null,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                              child: state.submitting
                                  ? const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        Text(
                                          'Confirmando…',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          ctaLabel,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.1,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Icon(
                                          esSlot ? Icons.check_rounded : Icons.arrow_forward_rounded,
                                          size: 18,
                                          color: Colors.white,
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Resumen extends StatelessWidget {
  final BookingWizardState state;
  const _Resumen({required this.state});

  @override
  Widget build(BuildContext context) {
    final servicios = state.selectedServices;
    final slot = state.selectedSlot;
    final names = servicios.map((s) => s.name).join(' + ');
    final detalle = slot != null
        ? '${slot.time} con ${slot.staffName}'
        : '${Fechas.duracion(state.totalDuration)} en total';
    return Row(
      children: [
        if (slot != null)
          LiquidAvatar(imageUrl: slot.staffAvatarUrl, name: slot.staffName, size: 36)
        else
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.08),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 0.8),
            ),
            child: Icon(Icons.content_cut_rounded, size: 16, color: Colors.white.withValues(alpha: 0.85)),
          ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                names,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: MonacoColors.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                detalle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          Fechas.moneda(state.totalPrice),
          style: const TextStyle(
            color: MonacoColors.monacoGreen,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _Politica extends StatelessWidget {
  final bool accepted;
  final int horas;
  final ValueChanged<bool> onChanged;

  const _Politica({required this.accepted, required this.horas, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const accent = MonacoColors.monacoGreen;
    return Semantics(
      checked: accepted,
      label: 'Política de cancelación',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!accepted),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white.withValues(alpha: accepted ? 0.07 : 0.05),
            border: Border.all(
              color: accepted ? accent.withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.12),
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: LiquidTokens.swap,
                curve: LiquidTokens.curveSwap,
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  color: accepted ? accent : Colors.transparent,
                  border: Border.all(
                    color: accepted ? accent : Colors.white.withValues(alpha: 0.4),
                    width: accepted ? 0 : 1.2,
                  ),
                  boxShadow:
                      accepted ? [BoxShadow(color: accent.withValues(alpha: 0.45), blurRadius: 10)] : null,
                ),
                child: accepted ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12.5,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                    children: [
                      const TextSpan(text: 'Entiendo que puedo cancelar hasta '),
                      TextSpan(
                        text: '${Fechas.horas(horas)} antes',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                      const TextSpan(text: ' del turno. Te mandamos la confirmación por WhatsApp.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String text;
  const _ErrorBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: MonacoColors.destructive.withValues(alpha: 0.14),
        border: Border.all(color: MonacoColors.destructive.withValues(alpha: 0.45), width: 0.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, size: 16, color: MonacoColors.destructive),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: MonacoColors.textPrimary,
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
