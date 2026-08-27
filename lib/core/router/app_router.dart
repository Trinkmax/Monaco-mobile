import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/widgets/glass/liquid.dart';
import '../auth/auth_provider.dart';
import '../../features/onboarding/presentation/screens/splash_screen.dart';
import '../../features/onboarding/presentation/screens/welcome_screen.dart';
import '../../features/onboarding/presentation/screens/login_phone_screen.dart';
import '../../features/onboarding/presentation/screens/login_code_screen.dart';
import '../../features/onboarding/presentation/screens/login_name_screen.dart';
import '../../features/onboarding/presentation/screens/biometric_gate_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/occupancy/presentation/screens/occupancy_screen.dart';
import '../../features/occupancy/presentation/screens/branch_detail_screen.dart';
import '../../features/points/presentation/screens/points_screen.dart';
import '../../features/rewards/presentation/screens/premios_screen.dart';
import '../../features/rewards/presentation/screens/mis_premios_screen.dart';
import '../../features/rewards/presentation/screens/qr_display_screen.dart';
import '../../features/reviews/presentation/screens/reviews_screen.dart';
import '../../features/reviews/presentation/screens/review_flow_screen.dart';
import '../../features/billboard/presentation/screens/billboard_screen.dart';
import '../../features/convenios/presentation/screens/convenios_list_screen.dart';
import '../../features/convenios/presentation/screens/convenio_detail_screen.dart';
import '../../features/convenios/presentation/screens/my_redemptions_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/pin_setup_screen.dart';
import '../../features/profile/presentation/screens/pin_verify_screen.dart';
import '../../features/visits/presentation/screens/visits_screen.dart';
import '../../features/appointments/presentation/my_appointments_screen.dart';
import '../../features/appointments/presentation/booking_wizard_screen.dart';
import '../../features/appointments/presentation/appointment_detail_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/notifications/presentation/screens/notification_preferences_screen.dart';

/// Navigator raíz — lo usa también `PushHandler` para navegar desde una
/// notificación sin contexto de widget.
final rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// ChangeNotifier que hace refresh del router cuando cambia el auth state,
/// sin recrear el GoRouter en cada cambio (evita resetear a initialLocation).
class _AuthRouterRefresh extends ChangeNotifier {
  _AuthRouterRefresh(Ref ref) {
    _sub = ref.listen<AuthState>(authProvider, (_, _) => notifyListeners());
  }
  late final ProviderSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

/// Rutas del flujo de login (teléfono → código → nombre).
const _loginPaths = {'/login', '/login/codigo', '/login/nombre'};

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final path = state.matchedLocation;
      final status = auth.status;

      if (path == '/splash') return null;
      if (status == AuthStatus.initial) return '/splash';

      final isWelcome = path == '/welcome';
      final isLogin = _loginPaths.contains(path);
      final isGate = path == '/biometric' || path == '/pin';

      switch (status) {
        case AuthStatus.unauthenticated:
          if (isWelcome || isLogin) return null;
          return '/welcome';
        case AuthStatus.needsBiometric:
          if (isGate) return null;
          return '/biometric';
        case AuthStatus.authenticated:
          if (isWelcome || isLogin || isGate || path == '/splash') return '/home';
          return null;
        case AuthStatus.initial:
          return '/splash';
      }
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPhoneScreen()),
      GoRoute(path: '/login/codigo', builder: (_, _) => const LoginCodeScreen()),
      GoRoute(path: '/login/nombre', builder: (_, _) => const LoginNameScreen()),
      GoRoute(path: '/biometric', builder: (_, _) => const BiometricGateScreen()),
      GoRoute(path: '/pin', builder: (_, _) => const PinVerifyScreen()),
      // ── App principal con dock flotante ──────────────────────────────
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (_, _) => const NoTransitionPage(child: HomeScreen()),
          ),
          GoRoute(
            path: '/turnos',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: MyAppointmentsScreen()),
          ),
          GoRoute(
            path: '/occupancy',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: OccupancyScreen()),
          ),
          GoRoute(
            path: '/rewards',
            pageBuilder: (_, _) => const NoTransitionPage(child: PremiosScreen()),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (_, _) => const NoTransitionPage(child: ProfileScreen()),
          ),
        ],
      ),

      // ── Turnos (fuera del shell, pantalla completa) ──────────────────
      GoRoute(
        path: '/turnos/reservar',
        builder: (_, state) => BookingWizardScreen(
          branchSlug: state.uri.queryParameters['branch'],
        ),
      ),
      GoRoute(
        path: '/turnos/:id',
        builder: (_, state) =>
            AppointmentDetailScreen(appointmentId: state.pathParameters['id']!),
      ),

      // ── Notificaciones ───────────────────────────────────────────────
      GoRoute(path: '/notificaciones', builder: (_, _) => const NotificationsScreen()),
      GoRoute(
        path: '/notificaciones/preferencias',
        builder: (_, _) => const NotificationPreferencesScreen(),
      ),

      // ── Detalle (fuera del shell) ────────────────────────────────────
      GoRoute(
        path: '/branch/:id',
        builder: (_, state) =>
            BranchDetailScreen(branchId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/points', builder: (_, _) => const PointsScreen()),
      GoRoute(path: '/mis-premios', builder: (_, _) => const MisPremiosScreen()),
      GoRoute(path: '/reviews', builder: (_, _) => const ReviewsScreen()),
      GoRoute(
        path: '/review/:token',
        builder: (_, state) =>
            ReviewFlowScreen(token: state.pathParameters['token']!),
      ),
      GoRoute(
        path: '/reward-qr/:id',
        builder: (_, state) =>
            QrDisplayScreen(clientRewardId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/billboard', builder: (_, _) => const BillboardScreen()),
      GoRoute(path: '/convenios', builder: (_, _) => const ConveniosListScreen()),
      GoRoute(
        path: '/convenio/:id',
        builder: (_, state) =>
            ConvenioDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(path: '/mis-canjes', builder: (_, _) => const MyRedemptionsScreen()),
      GoRoute(path: '/pin-setup', builder: (_, _) => const PinSetupScreen()),
      GoRoute(path: '/visits', builder: (_, _) => const VisitsScreen()),
    ],
  );
});

/// Shell principal — dock flotante, `backgroundColor` transparente y
/// `extendBody` para que el contenido pase por detrás.
class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _items = [
    LiquidDockItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: 'Inicio',
    ),
    LiquidDockItem(
      icon: Icons.event_available_outlined,
      selectedIcon: Icons.event_available_rounded,
      label: 'Turnos',
    ),
    LiquidDockItem(
      icon: Icons.storefront_outlined,
      selectedIcon: Icons.storefront_rounded,
      label: 'Sucursales',
    ),
    LiquidDockItem(
      icon: Icons.card_giftcard_outlined,
      selectedIcon: Icons.card_giftcard_rounded,
      label: 'Premios',
    ),
    LiquidDockItem(
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: 'Perfil',
    ),
  ];

  static const _paths = ['/home', '/turnos', '/occupancy', '/rewards', '/profile'];

  static int _indexFromLocation(String location) {
    for (var i = 0; i < _paths.length; i++) {
      if (location == _paths[i] || location.startsWith('${_paths[i]}/')) {
        return i;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _indexFromLocation(location);

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: child,
      bottomNavigationBar: LiquidDock(
        items: _items,
        currentIndex: currentIndex,
        onSelect: (index) => context.go(_paths[index]),
      ),
    );
  }
}
