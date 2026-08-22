import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:monaco_mobile/core/utils/constants.dart';

/// "Al continuar aceptás los Términos y la Política de privacidad", con los
/// dos links tappables. Abre con `launchUrl` directo (sin `canLaunchUrl`, que
/// en iOS 17+ devuelve false para https si no está declarado el scheme).
class LegalFooter extends StatefulWidget {
  final TextAlign align;
  const LegalFooter({super.key, this.align = TextAlign.center});

  @override
  State<LegalFooter> createState() => _LegalFooterState();
}

class _LegalFooterState extends State<LegalFooter> {
  late final TapGestureRecognizer _terms = TapGestureRecognizer()
    ..onTap = () => _open(AppConstants.termsOfServiceUrl);
  late final TapGestureRecognizer _privacy = TapGestureRecognizer()
    ..onTap = () => _open(AppConstants.privacyPolicyUrl);

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[legal] no se pudo abrir $url: $e');
    }
  }

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      color: Colors.white.withValues(alpha: 0.42),
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1.5,
    );
    final link = base.copyWith(
      color: Colors.white.withValues(alpha: 0.82),
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: Colors.white.withValues(alpha: 0.35),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text.rich(
        TextSpan(
          style: base,
          children: [
            const TextSpan(text: 'Al continuar aceptás los '),
            TextSpan(text: 'Términos', style: link, recognizer: _terms),
            const TextSpan(text: ' y la '),
            TextSpan(
              text: 'Política de privacidad',
              style: link,
              recognizer: _privacy,
            ),
            const TextSpan(text: '.'),
          ],
        ),
        textAlign: widget.align,
      ),
    );
  }
}
