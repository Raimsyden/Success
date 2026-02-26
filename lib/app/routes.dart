import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/providers/auth_provider.dart';

class _PlaceholderScreen extends StatelessWidget {
  final String name;
  const _PlaceholderScreen(this.name);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: Center(
        child: Text(
          name,
          style: const TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}

GoRouter createRouter(WidgetRef ref) {
  return GoRouter(
    initialLocation: '/login',

    redirect: (context, state) {
      final authState = ref.read(authStateProvider);

      final isLoggedIn = authState.whenOrNull(
        data: (auth) => auth.session != null,
      ) ?? false;

      final isGoingToLogin = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (isLoggedIn && isGoingToLogin) return '/feed';
      if (!isLoggedIn && !isGoingToLogin) return '/login';

      return null;
    },

    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const _PlaceholderScreen('Login'),
      ),
      GoRoute(
        path: '/register',
        builder: (_, __) => const _PlaceholderScreen('Registro'),
      ),
      GoRoute(
        path: '/feed',
        builder: (_, __) => const _PlaceholderScreen('Feed'),
      ),
      GoRoute(
        path: '/profile/:userId',
        builder: (_, state) => _PlaceholderScreen(
          'Perfil: ${state.pathParameters['userId']}',
        ),
      ),
      GoRoute(
        path: '/products',
        builder: (_, __) => const _PlaceholderScreen('Productos'),
      ),
      GoRoute(
        path: '/messages',
        builder: (_, __) => const _PlaceholderScreen('Mensajes'),
      ),
    ],
  );
}