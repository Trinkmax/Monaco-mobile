import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/pin_setup_screen.dart';
import '../../features/branch_selection/presentation/screens/branch_selection_screen.dart';
import '../../features/org_selection/presentation/screens/org_selection_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) {
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

      // Not authenticated, redirect to welcome/login
      if (isUnauthenticated && !path.startsWith('/welcome') && !path.startsWith('/login')) {
        return '/welcome';
      }

      // Authenticated pero sin org seleccionada → selección de org
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
        path: '/pin-setup',
        builder: (_, __) => const PinSetupScreen(),
      ),
    ],
  );
});

/// Main shell with bottom navigation
class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

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
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0x1FFFFFFF), width: 0.5)),
        ),
        child: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (index) {
            switch (index) {
              case 0: context.go('/home');
              case 1: context.go('/occupancy');
              case 2: context.go('/rewards');
              case 3: context.go('/profile');
            }
          },
          backgroundColor: const Color(0xFF242424),
          indicatorColor: const Color(0x26FFFFFF),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
            NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Sucursales'),
            NavigationDestination(icon: Icon(Icons.card_giftcard_outlined), selectedIcon: Icon(Icons.card_giftcard), label: 'Premios'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
          ],
        ),
      ),
    );
  }
}
