import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// import 'core/constants/supabase_constants.dart';
import 'app/app_theme.dart';
// import 'package:timeago/timeago.dart' as timeago;
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
  final notifier = _AuthNotifierListenable(ref);
  
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authAsync = ref.read(authStateProvider);
      final currentPath = state.matchedLocation;

      return authAsync.when(
        loading: () => currentPath == '/splash' ? null : '/splash',
        error: (_, _) => '/login',
        data: (isLoggedIn) {
          final isAuthPage = currentPath == '/login' ||
              currentPath == '/register' ||
              currentPath == '/splash';

          debugPrint('[Router] isLoggedIn=$isLoggedIn, path=$currentPath');

          if (isLoggedIn && isAuthPage) return '/feed';
          if (!isLoggedIn && currentPath == '/splash') return '/login';
          if (!isLoggedIn && !isAuthPage) return '/login';
          return null;
        },
      );
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const _SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/feed', builder: (_, _) => const FeedScreen()),
      GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
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
      GoRoute(path: '/messages', builder: (_, _) => const MessagesScreen()),
    ],
  );
});

// Listenable que escucha cambios en authStateProvider
class _AuthNotifierListenable extends ChangeNotifier {
  _AuthNotifierListenable(this._ref) {
    _ref.listen(authStateProvider, (_, _) => notifyListeners());
  }
  final Ref _ref;
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

// ─── FUNCIÓN PRINCIPAL ────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializa Supabase antes de ejecutar la app
  try { 
    await Supabase.initialize(
    url: 'https://uqcxvbapbvfgyvsyfhfz.supabase.co',
    anonKey: 'sb_publishable_qP7XBwMaoTn3FGnkPJQgvQ_czH_TjMA',
    
  );
    debugPrint('[Main] Supabase inicializado correctamente');
  } catch (e) {
    debugPrint('[Main] Error inicializando Supabase: $e');
  }

  runApp(
    const ProviderScope(
      child: SuccessApp(),
    ),
  );
}