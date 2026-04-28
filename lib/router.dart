import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home_screen.dart';
import 'screens/trick_detail_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/submit_trick_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/profile_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    refreshListenable: _AuthNotifier(),
    redirect: (context, state) {
      final loggedIn =
          Supabase.instance.client.auth.currentSession != null;
      final loc = state.matchedLocation;
      final onAuth = loc == '/login' || loc == '/register';

      final isPublic = loc == '/' || loc.startsWith('/trick/');
      if (!loggedIn && !onAuth && !isPublic) return '/login';
      if (loggedIn && onAuth) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
          path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
      GoRoute(
        path: '/trick/:id',
        builder: (_, state) =>
            TrickDetailScreen(trickId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
          path: '/submit',
          builder: (_, __) => const SubmitTrickScreen()),
      GoRoute(path: '/admin', builder: (_, __) => const AdminScreen()),
      GoRoute(
          path: '/profile', builder: (_, __) => const ProfileScreen()),
    ],
  );
}

class _AuthNotifier extends ChangeNotifier {
  late final StreamSubscription _sub;

  _AuthNotifier() {
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
