import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'core/constants/supabase_constants.dart';
import 'app/app_theme.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'core/providers/auth_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/feed/feed_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/products/products_screen.dart';
import 'features/messages/messages_screen.dart';

// ─── PANTALLA DE CARGA ─────────────────────────────────────────────────────
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RichText(
              text: const TextSpan(children: [
                TextSpan(
                  text: 'Suc',
                  style: TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 42,
                    fontWeight: FontWeight.w700,
                    color: AppColors.cream,
                  ),
                ),
                TextSpan(
                  text: 'cess',
                  style: TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 42,
                    fontWeight: FontWeight.w700,
                    color: AppColors.peach,
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(
              color: AppColors.peach,
              strokeWidth: 2.5,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── ROUTER COMO PROVIDER ─────────────────────────────────────────────────
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final authAsync = ref.watch(authStateProvider);
      final currentPath = state.matchedLocation;

      return authAsync.when(
        // Mientras verifica → quedarse en splash
        loading: () {
          debugPrint('[Router] loading → splash');
          return currentPath == '/splash' ? null : '/splash';
        },
        // Error inesperado → ir a login
        error: (_, __) {
          debugPrint('[Router] error → login');
          return '/login';
        },
        data: (isLoggedIn) {
          final isAuthPage = currentPath == '/login' ||
              currentPath == '/register' ||
              currentPath == '/splash';

          debugPrint('[Router] isLoggedIn=$isLoggedIn, path=$currentPath');

          // Logueado y en pantalla de auth → ir al feed
          if (isLoggedIn && isAuthPage) return '/feed';

          // Sin sesión y en pantalla protegida → ir al login
          if (!isLoggedIn && !isAuthPage) return '/login';

          // Todo OK, no redirigir
          return null;
        },
      );
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const _SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/feed',
        builder: (_, __) => const FeedScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, __) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/profile/:userId',
        builder: (_, state) => ProfileScreen(
          userId: state.pathParameters['userId'],
        ),
      ),
      GoRoute(
        path: '/products/:ventureId',
        builder: (_, state) => ProductsScreen(
          ventureId: state.pathParameters['ventureId']!,
          ventureName: state.uri.queryParameters['name'] ?? 'Productos',
        ),
      ),
      GoRoute(
        path: '/messages',
        builder: (_, __) => const MessagesScreen(),
      ),
    ],
  );
});

// ─── PUNTO DE ENTRADA ──────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  timeago.setLocaleMessages('es', timeago.EsMessages());

  await Supabase.initialize(
    url: SupabaseConstants.url,
    anonKey: SupabaseConstants.anonKey,
  );

  runApp(const ProviderScope(child: SuccessApp()));
}

// ─── WIDGET RAÍZ ──────────────────────────────────────────────────────────
class SuccessApp extends ConsumerWidget {
  const SuccessApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Success',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es'),
        Locale('en'),
      ],
      theme: AppTheme.theme,
      darkTheme: null,
      themeMode: ThemeMode.light,
    );
  }
}