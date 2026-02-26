import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/constants/supabase_constants.dart';
import 'app/routes.dart';

// ─── PUNTO DE ENTRADA ──────────────────────────────────────────────────────
// El async es necesario porque Supabase necesita
// inicializarse antes de que la app arranque
void main() async {

  // Garantiza que Flutter esté listo antes de inicializar plugins
  // Siempre debe ser la primera línea si usas async en main()
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializamos Supabase con nuestras credenciales
  // A partir de aquí podemos usar Supabase en cualquier parte de la app
  await Supabase.initialize(
    url: SupabaseConstants.url,
    anonKey: SupabaseConstants.anonKey,
  );

  // ProviderScope es el contenedor de Riverpod
  // DEBE envolver toda la app para que los providers funcionen
  runApp(
    const ProviderScope(
      child: SuccessApp(),
    ),
  );
}

// ─── WIDGET RAÍZ DE LA APP ────────────────────────────────────────────────
// ConsumerWidget nos permite acceder a los providers de Riverpod
class SuccessApp extends ConsumerWidget {
  const SuccessApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Creamos el router aquí para que tenga acceso a ref
    // y pueda leer el estado de autenticación
    final router = createRouter(ref);

    return MaterialApp.router(
      // Nombre de la app
      title: 'Success',

      // Oculta el banner rojo de "DEBUG" en la esquina
      debugShowCheckedModeBanner: false,

      // ─── INTERNACIONALIZACIÓN ────────────────────────────────────────────
      // Permite que la app soporte múltiples idiomas
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Idiomas soportados: Español e Inglés
      supportedLocales: const [
        Locale('es'),
        Locale('en'),
      ],

      // ─── TEMA VISUAL ─────────────────────────────────────────────────────
      theme: ThemeData(
        // Color principal de la app: azul similar al de Facebook/LinkedIn
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1877F2),
          brightness: Brightness.light,
        ),
        // Material Design 3: el más moderno de Flutter
        useMaterial3: true,

        // Fuente principal
        fontFamily: 'Roboto',

        // Estilo del AppBar
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0.5,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),

        // Estilo de los botones principales
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1877F2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),

        // Fondo general de la app
        scaffoldBackgroundColor: const Color(0xFFF0F2F5),
      ),

      // Tema oscuro (respeta la preferencia del sistema)
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1877F2),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),

      // Usa el tema del sistema (claro u oscuro)
      themeMode: ThemeMode.system,

      // ─── NAVEGACIÓN ──────────────────────────────────────────────────────
      // RouterConfig conecta GoRouter con MaterialApp
      routerConfig: router,
    );
  }
}