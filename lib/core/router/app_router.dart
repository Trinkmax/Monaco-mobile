import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/widgets/glass/liquid.dart';
import '../auth/auth_provider.dart';
import '../../features/onboarding/presentation/screens/splash_screen.dart';
import '../../features/onboarding/presentation/screens/welcome_screen.dart';
import '../../features/onboarding/presentation/screens/login_screen.dart';
import '../../features/onboarding/presentation/screens/biometric_gate_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/occupancy/presentation/screens/occupancy_screen.dart';
import '../../features/occupancy/presentation/screens/branch_detail_screen.dart';
import '../../features/points/presentation/screens/points_screen.dart';
import '../../features/rewards/presentation/screens/rewards_screen.dart';
import '../../features/rewards/presentation/screens/qr_display_screen.dart';
import '../../features/reviews/presentation/screens/reviews_screen.dart';
import '../../features/reviews/presentation/screens/review_flow_screen.dart';
import '../../features/billboard/presentation/screens/billboard_screen.dart';
import '../../features/catalog/presentation/screens/catalog_screen.dart';
import '../../features/convenios/presentation/screens/convenios_list_screen.dart';
import '../../features/convenios/presentation/screens/convenio_detail_screen.dart';
import '../../features/convenios/presentation/screens/my_redemptions_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/pin_setup_screen.dart';
import '../../features/visits/presentation/screens/visits_screen.dart';
import '../../features/branch_selection/presentation/screens/branch_selection_screen.dart';
import '../../features/org_selection/presentation/screens/org_selection_screen.dart';
import '../../features/appointments/presentation/my_appointments_screen.dart';
import '../../features/appointments/presentation/booking_webview_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// ChangeNotifier que hace refresh del router cuando cambia el auth state,
/// sin recrear el GoRouter en cada cambio (evita resetear a initialLocation).
class _AuthRouterRefresh extends ChangeNotifier {
  _AuthRouterRefresh(Ref ref) {
    _sub = ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
  }
  late final ProviderSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final path = state.matchedLocation;
      final isAuth = authState.status == AuthStatus.authenticated;
      final needsBio = authState.status == AuthStatus.needsBiometric;
      final isUnauthenticated = authState.status == AuthStatus.unauthenticated;
      final isInitial = authState.status == AuthStatus.initial;
      final hasOrg = authState.hasOrg;

      // Allow splash always
      if (path == '/splash') return null;

      // Still loading
      if (isInitial) return '/splash';

      // Needs biometric verification
      if (needsBio && path != '/biometric') return '/biometric';

      // Flujo no autenticado: welcome → select-org → login
      if (isUnauthenticated) {
        final allowed = path.startsWith('/welcome') ||
            path.startsWith('/login') ||
            path == '/select-org';
        if (!allowed) return '/welcome';
        // No permitir login sin haber elegido org antes (evita mismatch con app_metadata)
        if (path.startsWith('/login') && !hasOrg) return '/select-org';
        return null;
      }

      // Authenticated pero sin org seleccionada (sesión vieja) → selección de org
      if (isAuth && !hasOrg && path != '/select-org') {
        return '/select-org';
      }

      // Authenticated con org, redirect away from auth/selection screens
      if (isAuth && hasOrg &&
          (path.startsWith('/welcome') || path.startsWith('/login') ||
           path == '/biometric' || path == '/splash' ||
           path == '/select-org' || path == '/select-branch')) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/biometric', builder: (_, __) => const BiometricGateScreen()),
      GoRoute(path: '/select-org', builder: (_, __) => const OrgSelectionScreen()),
      GoRoute(path: '/select-branch', builder: (_, __) => const BranchSelectionScreen()),

      // Main app with bottom nav
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (_, __) => const NoTransitionPage(child: HomeScreen()),
          ),
          GoRoute(
            path: '/occupancy',
            pageBuilder: (_, __) => const NoTransitionPage(child: OccupancyScreen()),
          ),
          GoRoute(
            path: '/rewards',
            pageBuilder: (_, __) => const NoTransitionPage(child: RewardsScreen()),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (_, __) => const NoTransitionPage(child: ProfileScreen()),
          ),
        ],
      ),

      // Detail screens (outside shell)
      GoRoute(
        path: '/branch/:id',
        builder: (_, state) => BranchDetailScreen(branchId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/points',
        builder: (_, __) => const PointsScreen(),
      ),
      GoRoute(
        path: '/catalog',
        builder: (_, __) => const CatalogScreen(),
      ),
      GoRoute(
        path: '/reviews',
        builder: (_, __) => const ReviewsScreen(),
      ),
      GoRoute(
        path: '/review/:token',
        builder: (_, state) => ReviewFlowScreen(token: state.pathParameters['token']!),
      ),
      GoRoute(
        path: '/reward-qr/:id',
        builder: (_, state) => QrDisplayScreen(clientRewardId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/billboard',
        builder: (_, __) => const BillboardScreen(),
      ),
      GoRoute(
        path: '/convenios',
        builder: (_, __) => const ConveniosListScreen(),
      ),
      GoRoute(
        path: '/convenio/:id',
        builder: (_, state) =>
            ConvenioDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/mis-canjes',
        builder: (_, __) => const MyRedemptionsScreen(),
      ),
      GoRoute(
        path: '/pin-setup',
        builder: (_, __) => const PinSetupScreen(),
      ),
      GoRoute(
        path: '/visits',
        builder: (_, __) => const VisitsScreen(),
      ),
      GoRoute(
        path: '/appointments',
        builder: (_, __) => const MyAppointmentsScreen(),
      ),
      GoRoute(
        path: '/appointments/book',
        builder: (_, __) => const BookingWebViewScreen(),
      ),
    ],
  );
});

/// Shell principal — dock flotante estilo iOS 26, con backgroundColor
/// transparente y `extendBody` para que el contenido pase por detrás.
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

  static int _indexFromLocation(String location) {
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/occupancy')) return 1;
    if (location.startsWith('/rewards')) return 2;
    if (location.startsWith('/profile')) return 3;
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
        onSelect: (index) {
          switch (index) {
            case 0:
              context.go('/home');
            case 1:
              context.go('/occupancy');
            case 2:
              context.go('/rewards');
            case 3:
              context.go('/profile');
          }
        },
      ),
    );
  }
}
