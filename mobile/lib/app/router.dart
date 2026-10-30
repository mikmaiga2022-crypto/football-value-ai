import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/session.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/home/home_screen.dart';
import '../features/live/live_screen.dart';
import '../features/matches/match_detail_screen.dart';
import '../features/matches/matches_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/value/value_screen.dart';
import 'app_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _homeNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final _matchesNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'matches');
final _valueNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'value');
final _liveNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'live');
final _profileNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'profile');

/// Router unique de l'application.
///
/// Le router n'est **pas** reconstruit quand la session change : un
/// `ChangeNotifier` déclenche seulement la réévaluation des redirections.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _SessionRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/home',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final location = state.matchedLocation;
      final onAuthScreen = location == '/login' || location == '/register';
      final onSplash = location == '/splash';

      switch (session.status) {
        case SessionStatus.unknown:
          return onSplash ? null : '/splash';
        case SessionStatus.unauthenticated:
          return onAuthScreen ? null : '/login';
        case SessionStatus.authenticated:
          return (onAuthScreen || onSplash) ? '/home' : null;
      }
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _homeNavigatorKey,
            routes: [
              GoRoute(
                path: '/home',
                name: 'home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _matchesNavigatorKey,
            routes: [
              GoRoute(
                path: '/matches',
                name: 'matches',
                builder: (context, state) => const MatchesScreen(),
              ),
              GoRoute(
                path: '/matches/:id',
                name: 'match-detail',
                builder: (context, state) => MatchDetailScreen(
                  matchId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _valueNavigatorKey,
            routes: [
              GoRoute(
                path: '/value',
                name: 'value',
                builder: (context, state) => const ValueScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _liveNavigatorKey,
            routes: [
              GoRoute(
                path: '/live',
                name: 'live',
                builder: (context, state) => const LiveScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _profileNavigatorKey,
            routes: [
              GoRoute(
                path: '/profile',
                name: 'profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Traduit les changements de statut de session en notification pour go_router.
class _SessionRefresh extends ChangeNotifier {
  _SessionRefresh(Ref ref) {
    ref.listen<SessionState>(sessionProvider, (previous, next) {
      if (previous?.status != next.status) notifyListeners();
    });
  }
}
