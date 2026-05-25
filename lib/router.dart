import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home_screen.dart';
import 'screens/tips_screen.dart';
import 'screens/trick_detail_screen.dart';
import 'screens/training_studio_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/submit_trick_screen.dart';
import 'screens/submit_tip_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/profile_screen.dart';
import 'video/bunny_video_provider.dart';
import 'video/local_video_provider.dart';
import 'widgets/main_shell.dart';

class AppRouter {
  static final _authNotifier = _AuthNotifier();

  static final GoRouter router = GoRouter(
    initialLocation: '/',
    refreshListenable: _authNotifier,
    redirect: (context, state) {
      final loggedIn = Supabase.instance.client.auth.currentSession != null;
      final loc = state.matchedLocation;

      if (_authNotifier.isRecovery) {
        return loc == '/reset-password' ? null : '/reset-password';
      }

      final onAuth = loc == '/login' || loc == '/register';
      final isPublic = loc == '/' || loc.startsWith('/trick/') || loc == '/tips';
      if (!loggedIn && !onAuth && !isPublic) return '/login';
      if (loggedIn && onAuth) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/reset-password', builder: (_, __) => const ResetPasswordScreen()),
      GoRoute(
        path: '/trick/:id',
        builder: (_, state) =>
            TrickDetailScreen(trickId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(path: '/submit', builder: (_, __) => const SubmitTrickScreen()),
      GoRoute(
        path: '/trick/:id/training-studio',
        builder: (_, state) => TrainingStudioScreen(
          trickId: int.parse(state.pathParameters['id']!),
          provider: const BunnyVideoProvider(baseUrl: ''),
        ),
      ),
      if (kDebugMode)
        GoRoute(
          path: '/dev/training-studio',
          builder: (_, __) => TrainingStudioScreen(
            trickId: 0,
            provider: LocalVideoProvider.defaultForPlatform(),
            title: 'Training Studio (Dev)',
          ),
        ),
      GoRoute(path: '/tips/submit', builder: (_, __) => const SubmitTipScreen()),
      GoRoute(path: '/admin', builder: (_, __) => const AdminScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/tips', builder: (_, __) => const TipsScreen()),
            ],
          ),
        ],
      ),
    ],
  );
}

class _AuthNotifier extends ChangeNotifier {
  late final StreamSubscription _sub;
  bool _isRecovery = false;

  bool get isRecovery => _isRecovery;

  _AuthNotifier() {
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        if (data.event == AuthChangeEvent.passwordRecovery) {
          _isRecovery = true;
        } else if (_isRecovery) {
          _isRecovery = false;
        }
        notifyListeners();
      },
      onError: (_) {
        _isRecovery = false;
        notifyListeners();
      },
    );
  }

  void clearRecovery() {
    _isRecovery = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
