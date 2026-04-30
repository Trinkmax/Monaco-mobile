import 'package:flutter/material.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';

/// Resultado del diálogo: si se confirmó, devuelve el motivo (puede ser
/// string vacío). Si se canceló (X o "Volver"), devuelve `null`.
class CancelDialogResult {
  final String reason;
  const CancelDialogResult(this.reason);
}

/// Muestra un AlertDialog para confirmar la cancelación de un turno.
/// El motivo es opcional. La acción de confirmar es destructiva.
Future<CancelDialogResult?> showCancelAppointmentDialog(
  BuildContext context, {
  required String appointmentSummary,
}) {
  return showDialog<CancelDialogResult>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _CancelAppointmentDialog(summary: appointmentSummary),
  );
}

class _CancelAppointmentDialog extends StatefulWidget {
  final String summary;
  const _CancelAppointmentDialog({required this.summary});

  @override
  State<_CancelAppointmentDialog> createState() =>
      _CancelAppointmentDialogState();
}

class _CancelAppointmentDialogState extends State<_CancelAppointmentDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: MonacoColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      title: const Text(
        'Cancelar turno',
        style: TextStyle(
          color: MonacoColors.textPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¿Seguro que querés cancelar este turno?',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 14.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.summary,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLength: 140,
            maxLines: 3,
            minLines: 2,
            style: const TextStyle(
              color: MonacoColors.textPrimary,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: 'Motivo (opcional)',
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 14,
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              counterStyle: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 11,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.30)),
              ),
            ),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Volver',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context)
              .pop(CancelDialogResult(_controller.text.trim())),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFE5484D),
            backgroundColor: const Color(0xFFE5484D).withOpacity(0.15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: const Text(
            'Cancelar turno',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
