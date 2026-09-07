import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/features/loyalty/data/loyalty_models.dart';
import 'package:monaco_mobile/features/loyalty/data/referido.dart';
import 'package:monaco_mobile/features/loyalty/providers/loyalty_provider.dart';
import 'package:monaco_mobile/features/loyalty/providers/referral_provider.dart';

final _pts = NumberFormat.decimalPattern('es_AR');
final _diaMes = DateFormat('dd/MM');

/// Prefijo del QR de referido. Es lo que escanea la tablet del barbero al
/// cobrar el primer corte del amigo (`apply_referral_for_visit`).
const _prefijoQr = 'MNC-REF:';

/// **Invitá a un amigo** (`/invitar`): el QR y el código personal del cliente,
/// qué gana cada uno (valores del server), cómo funciona y el estado de sus
/// invitaciones. Con `referral.enabled = false` la pantalla lo dice y no
/// muestra código: la promo la prende y apaga el dueño desde el dashboard.
class InvitarScreen extends ConsumerWidget {
  const InvitarScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    invalidarLoyalty(ref);
    invalidarReferidos(ref);
    await Future.wait([
      ref.read(loyaltyProvider.future).then((_) {}, onError: (_) {}),
      ref.read(referralCodeProvider.future).then((_) {}, onError: (_) {}),
      ref.read(misReferidosProvider.future).then((_) {}, onError: (_) {}),
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loyalty = ref.watch(loyaltyProvider);

    return LiquidAppBarScaffold(
      title: 'Invitá a un amigo',
      showBackButton: true,
      body: loyalty.when(
        loading: () => const _Cargando(),
        error: (e, _) => LiquidErrorState(
          error: e,
          onRetry: () => _refresh(ref),
        ),
        data: (summary) {
          if (!summary.referral.enabled) {
            return const LiquidEmptyState(
              icon: Icons.person_add_disabled_rounded,
              title: 'El programa de invitaciones no está activo',
              message:
                  'Cuando la barbería lo active vas a tener acá tu código y tu QR para invitar amigos y sumar puntos.',
            );
          }
          return RefreshIndicator(
            color: Colors.white,
            backgroundColor: MonacoColors.surface,
            onRefresh: () => _refresh(ref),
            child: _Cuerpo(referral: summary.referral),
          );
        },
      ),
    );
  }
}

class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
      children: const [
        LiquidSkeleton(height: 110, radius: 22),
        SizedBox(height: 16),
        LiquidSkeleton(height: 360, radius: 28),
        SizedBox(height: 26),
        LiquidSkeleton.line(width: 150, height: 18),
        SizedBox(height: 14),
        LiquidSkeleton(height: 190, radius: 22),
      ],
    );
  }
}

class _Cuerpo extends ConsumerWidget {
  final LoyaltyReferralInfo referral;
  const _Cuerpo({required this.referral});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(referralCodeProvider);
    final referidos = ref.watch(misReferidosProvider);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
      children: [
        _Header(referral: referral).liquidEnter(index: 0),
        const SizedBox(height: 16),
        code.when(
          loading: () => const LiquidSkeleton(height: 360, radius: 28),
          error: (e, _) => LiquidErrorState(
            error: e,
            scrollable: false,
            onRetry: () => ref.invalidate(referralCodeProvider),
          ),
          data: (c) => c == null
              ? LiquidErrorState(
                  scrollable: false,
                  title: 'No pudimos generar tu código',
                  message: 'Probá de nuevo en unos segundos.',
                  onRetry: () => ref.invalidate(referralCodeProvider),
                )
              : _TarjetaCodigo(code: c, referral: referral),
        ).liquidEnter(index: 1),
        const SizedBox(height: 26),
        const LiquidSectionTitle(
          title: 'Cómo funciona',
          subtitle: 'Tres pasos, sin formularios',
        ).liquidEnter(index: 2),
        const SizedBox(height: 12),
        _Pasos(referral: referral).liquidEnter(index: 3),
        const SizedBox(height: 26),
        LiquidSectionTitle(
          title: 'Mis invitaciones',
          subtitle: referral.completedCount == 0
              ? 'Las que van entrando aparecen acá'
              : referral.completedCount == 1
                  ? '1 amigo ya se cortó'
                  : '${referral.completedCount} amigos ya se cortaron',
        ).liquidEnter(index: 4),
        const SizedBox(height: 12),
        _Invitaciones(
          referidos: referidos,
          onRetry: () => ref.invalidate(misReferidosProvider),
        ).liquidEnter(index: 5),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HEADER — qué gana cada uno (valores del server)
// ═══════════════════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  final LoyaltyReferralInfo referral;
  const _Header({required this.referral});

  /// "20 % OFF en su primer corte + 100 pts". Cada parte sólo si el dueño la
  /// cargó con valor: un "0 % OFF" es peor que no decir nada.
  static String ganaTuAmigo(LoyaltyReferralInfo r) {
    final partes = <String>[
      if (r.discountPct > 0) '${r.discountPct} % OFF en su primer corte',
      if (r.referredPoints > 0) '${_pts.format(r.referredPoints)} pts',
    ];
    return partes.isEmpty ? 'un regalo de bienvenida' : partes.join(' + ');
  }

  @override
  Widget build(BuildContext context) {
    final r = referral;
    // Vidrio neutro, como `_Pasos`: es el resumen de la promo, no un estado
    // del negocio. El verde de esta pantalla es "Completada · +150 pts".
    return LiquidGlass(
      pressable: false,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Linea(
            icon: Icons.card_giftcard_rounded,
            titulo: 'Tu amigo recibe',
            valor: ganaTuAmigo(r),
          ),
          const SizedBox(height: 12),
          _Linea(
            icon: Icons.stars_rounded,
            titulo: 'Vos sumás',
            valor: r.referrerPoints > 0
                ? '${_pts.format(r.referrerPoints)} pts cuando se corte'
                : 'puntos cuando se corte',
          ),
        ],
      ),
    );
  }
}

class _Linea extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String valor;
  const _Linea({required this.icon, required this.titulo, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.18),
                Colors.white.withValues(alpha: 0.06),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 0.8,
            ),
          ),
          child: Icon(icon, size: 17, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo.toUpperCase(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                valor,
                style: const TextStyle(
                  color: MonacoColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// QR + CÓDIGO + COPIAR / COMPARTIR
// ═══════════════════════════════════════════════════════════════════════════

class _TarjetaCodigo extends StatelessWidget {
  final String code;
  final LoyaltyReferralInfo referral;
  const _TarjetaCodigo({required this.code, required this.referral});

  /// El texto que viaja por WhatsApp. Lleva el código —no el QR— porque es lo
  /// que el amigo puede decir en el mostrador si no tiene el mensaje a mano.
  static String textoParaCompartir(String code, LoyaltyReferralInfo r) {
    final gana = r.discountPct > 0
        ? 'tenés ${r.discountPct} % OFF'
        : r.referredPoints > 0
            ? 'sumás ${_pts.format(r.referredPoints)} pts'
            : 'tenés un regalo de bienvenida';
    return 'Te invito a Monaco Barber Studio: mostrá este código en tu primer corte y $gana. Código: $code';
  }

  Future<void> _copiar(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: code));
    HapticFeedback.lightImpact();
    if (!context.mounted) return;
    showLiquidToast(
      context,
      'Código copiado.',
      tone: LiquidToastTone.success,
      icon: Icons.content_copy_rounded,
    );
  }

  Future<void> _compartir(BuildContext context) async {
    HapticFeedback.selectionClick();
    try {
      await Share.share(textoParaCompartir(code, referral));
    } catch (e) {
      debugPrint('[referral] share falló: $e');
      if (!context.mounted) return;
      showLiquidToast(
        context,
        'No pudimos abrir el menú de compartir. Copiá el código y mandalo a mano.',
        tone: LiquidToastTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final qrSize = (MediaQuery.sizeOf(context).width - 40 - 44 - 36)
        .clamp(170.0, 230.0);

    return LiquidGlass(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      borderRadius: 28,
      tintOpacity: 0.10,
      pressable: false,
      child: Column(
        children: [
          Semantics(
            label: 'Código QR de invitación, código $code',
            image: true,
            child: Container(
              padding: const EdgeInsets.all(16),
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
                data: '$_prefijoQr$code',
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
          Text(
            'TU CÓDIGO',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 6),
          Semantics(
            button: true,
            label: 'Tu código $code. Copiar',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _copiar(context),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    code,
                    style: const TextStyle(
                      color: MonacoColors.textPrimary,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                      height: 1.1,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.content_copy_rounded,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: LiquidButton(
                  primary: false,
                  onPressed: () => _copiar(context),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.content_copy_rounded, size: 17, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Copiar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LiquidButton(
                  tint: MonacoColors.seleccion,
                  onPressed: () => _compartir(context),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.ios_share_rounded, size: 17, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Compartir',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PASOS
// ═══════════════════════════════════════════════════════════════════════════

class _Pasos extends StatelessWidget {
  final LoyaltyReferralInfo referral;
  const _Pasos({required this.referral});

  @override
  Widget build(BuildContext context) {
    final r = referral;
    final pasos = <(IconData, String, String)>[
      (
        Icons.ios_share_rounded,
        'Compartí tu código',
        'Mandale el código o el QR a un amigo que todavía no se cortó en Monaco.',
      ),
      (
        Icons.qr_code_scanner_rounded,
        'Lo muestra en su primer corte',
        r.discountPct > 0
            ? 'Al pagar, el barbero lo escanea y le aplica el ${r.discountPct} % OFF en el momento.'
            : 'Al pagar, el barbero lo escanea y le acredita su regalo en el momento.',
      ),
      (
        Icons.stars_rounded,
        'Los dos suman puntos',
        r.referrerPoints > 0
            ? 'Vos recibís ${_pts.format(r.referrerPoints)} pts apenas termina ese corte.'
            : 'Vos recibís puntos apenas termina ese corte.',
      ),
    ];

    return LiquidGlass(
      pressable: false,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Column(
        children: [
          for (var i = 0; i < pasos.length; i++) ...[
            if (i > 0)
              Container(height: 0.5, color: Colors.white.withValues(alpha: 0.07)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.18),
                          Colors.white.withValues(alpha: 0.06),
                        ],
                      ),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 0.8),
                    ),
                    child: Icon(pasos[i].$1, size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${i + 1}. ${pasos[i].$2}',
                          style: const TextStyle(
                            color: MonacoColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          pasos[i].$3,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MIS INVITACIONES
// ═══════════════════════════════════════════════════════════════════════════

class _Invitaciones extends StatelessWidget {
  final AsyncValue<List<Referido>> referidos;
  final VoidCallback onRetry;
  const _Invitaciones({required this.referidos, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return referidos.when(
      loading: () => const LiquidSkeleton(height: 150, radius: 22),
      error: (e, _) => LiquidErrorState(
        error: e,
        scrollable: false,
        title: 'No pudimos cargar tus invitaciones',
        onRetry: onRetry,
      ),
      data: (lista) {
        if (lista.isEmpty) {
          return const LiquidEmptyState(
            icon: Icons.group_add_rounded,
            title: 'Todavía no invitaste a nadie',
            message:
                'Compartí tu código: cuando un amigo lo use en su primer corte, aparece acá.',
            scrollable: false,
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          );
        }
        return LiquidSectionCard(
          children: [for (final r in lista) _FilaReferido(referido: r)],
        );
      },
    );
  }
}

class _FilaReferido extends StatelessWidget {
  final Referido referido;
  const _FilaReferido({required this.referido});

  @override
  Widget build(BuildContext context) {
    final r = referido;
    final nombre = r.friendFirstName;
    // La mayúscula sólo cuando el fallback va solo: "Te invitó Un amigo"
    // tenía mayúscula en medio de la frase.
    final quien = r.iAmReferrer
        ? (nombre ?? 'Un amigo')
        : 'Te invitó ${nombre ?? 'un amigo'}';

    final (String estado, Color color) = r.completada
        ? (
            r.points > 0
                ? 'Completada · +${_pts.format(r.points)} pts'
                : 'Completada',
            MonacoColors.monacoGreen,
          )
        : r.pendiente
            ? ('Pendiente', MonacoColors.warning)
            : ('Cancelada', Colors.white.withValues(alpha: 0.45));

    final fecha = r.completedAt ?? r.createdAt;
    final cuando = fecha == null
        ? null
        : r.completada
            ? 'Se cortó el ${_diaMes.format(fecha)}'
            : r.pendiente
                ? 'Invitado el ${_diaMes.format(fecha)} · todavía no se cortó'
                : 'Invitado el ${_diaMes.format(fecha)}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
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
                  color.withValues(alpha: 0.24),
                  color.withValues(alpha: 0.08),
                ],
              ),
              border: Border.all(color: color.withValues(alpha: 0.32), width: 0.8),
            ),
            child: Icon(
              r.completada
                  ? Icons.check_rounded
                  : r.pendiente
                      ? Icons.hourglass_top_rounded
                      : Icons.close_rounded,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quien,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MonacoColors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  estado,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (cuando != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    cuando,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
