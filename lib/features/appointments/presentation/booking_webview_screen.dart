import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/core/auth/auth_provider.dart';
import 'package:monaco_mobile/core/auth/secure_storage.dart';

import '../providers/appointments_provider.dart';

/// Pantalla que abre la web de reservas dentro de un WebView. Detecta el
/// callback de confirmación leyendo la URL navegada y, si matchea, refresca
/// el listado de turnos y vuelve a la pantalla anterior.
///
/// URL base: `https://app.monacosmartbarber.com/turnos/{slug}?phone=...&from=app`
/// Confirmación: la web redirige a `.../confirmation` o agrega `?status=success`.
class BookingWebViewScreen extends ConsumerStatefulWidget {
  const BookingWebViewScreen({super.key});

  @override
  ConsumerState<BookingWebViewScreen> createState() =>
      _BookingWebViewScreenState();
}

class _BookingWebViewScreenState extends ConsumerState<BookingWebViewScreen> {
  WebViewController? _controller;
  bool _loading = true;
  bool _confirmed = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _setupController();
  }

  Future<void> _setupController() async {
    final auth = ref.read(authProvider);
    final slug = auth.selectedBranchSlug;
    if (slug == null || slug.trim().isEmpty) {
      setState(() {
        _initError =
            'No pudimos identificar la sucursal. Volvé a seleccionar la sucursal.';
        _loading = false;
      });
      return;
    }

    final phone = await SecureStorageService.getClientPhone() ?? '';
    final uri = Uri.parse('https://app.monacosmartbarber.com/turnos/$slug')
        .replace(queryParameters: {
      if (phone.isNotEmpty) 'phone': phone,
      'from': 'app',
    });

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(MonacoColors.background)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) {
          if (mounted) setState(() => _loading = true);
          _checkConfirmation(url);
        },
        onPageFinished: (url) {
          if (mounted) setState(() => _loading = false);
          _checkConfirmation(url);
        },
        onNavigationRequest: (request) {
          _checkConfirmation(request.url);
          return NavigationDecision.navigate;
        },
        onWebResourceError: (_) {
          // No-op: dejamos que el usuario reintente con el botón refrescar.
        },
      ))
      ..loadRequest(uri);

    if (mounted) {
      setState(() {
        _controller = controller;
      });
    }
  }

  void _checkConfirmation(String url) {
    if (_confirmed) return;
    final lower = url.toLowerCase();
    final isConfirmation = lower.contains('/confirmation') ||
        lower.contains('status=success') ||
        lower.contains('booking=success');
    if (!isConfirmation) return;

    _confirmed = true;

    // Invalidar listado de turnos así al volver ya está fresco.
    ref.invalidate(upcomingAppointmentsProvider);
    ref.invalidate(pastAppointmentsProvider);

    // Damos tiempo a que la web muestre la pantalla de éxito antes de cerrar.
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Turno reservado!'),
          duration: Duration(seconds: 3),
        ),
      );
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/appointments');
      }
    });
  }

  @override
  void dispose() {
    // Limpiar storage de la WebView para no persistir estado entre sesiones
    // (cookies, localStorage del flujo de reservas, etc.).
    final c = _controller;
    if (c != null) {
      try {
        c.clearLocalStorage();
        c.clearCache();
      } catch (_) {}
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LiquidAppBarScaffold(
      title: 'Reservar turno',
      showBackButton: true,
      backgroundColor: MonacoColors.background,
      actions: [
        IconButton(
          onPressed: () => _controller?.reload(),
          icon: Icon(
            Icons.refresh_rounded,
            color: Colors.white.withOpacity(0.85),
          ),
        ),
      ],
      body: _initError != null
          ? _ErrorView(message: _initError!)
          : Stack(
              children: [
                if (_controller != null)
                  Positioned.fill(child: WebViewWidget(controller: _controller!)),
                if (_loading || _controller == null)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Colors.black,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Colors.white.withOpacity(0.7),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
