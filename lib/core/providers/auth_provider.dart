import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

// ─── PROVIDER DEL SERVICIO ─────────────────────────────────────────────────
// Crea una sola instancia de AuthService para toda la app
// Así no creamos múltiples instancias innecesarias
//
// Ejemplo de uso en cualquier pantalla:
//   final authService = ref.read(authServiceProvider);
//   await authService.signOut();
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// ─── PROVIDER DEL ESTADO DE AUTENTICACIÓN ─────────────────────────────────
// Escucha en tiempo real si el usuario está logueado o no
// Es un StreamProvider porque Supabase nos da un Stream de cambios
//
// Posibles valores:
//   AsyncData(session) → hay sesión activa
//   AsyncData(null)    → no hay sesión
//   AsyncLoading()     → verificando...
//   AsyncError()       → algo salió mal
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

// ─── PROVIDER DEL USUARIO ACTUAL ──────────────────────────────────────────
// Mantiene el perfil completo del usuario logueado
// Se actualiza automáticamente cuando el estado de auth cambia
//
// Ejemplo de uso en cualquier widget:
//   final userAsync = ref.watch(currentUserProvider);
//   userAsync.when(
//     data: (user) => Text('Hola ${user?.username}'),
//     loading: () => CircularProgressIndicator(),
//     error: (e, _) => Text('Error'),
//   );
final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  // Escuchamos el estado de auth para reaccionar a cambios
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (state) async {
      // Si hay sesión activa, traemos el perfil completo
      if (state.session != null) {
        final authService = ref.read(authServiceProvider);
        return await authService.getUserProfile(
          state.session!.user.id,
        );
      }
      // Si no hay sesión, devolvemos null
      return null;
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

// ─── NOTIFIER DEL USUARIO ─────────────────────────────────────────────────
// Maneja las acciones del usuario: login, registro, logout
// y actualiza el estado global automáticamente
//
// Ejemplo de uso en la pantalla de login:
//   final authNotifier = ref.read(authNotifierProvider.notifier);
//   await authNotifier.signIn(email: '...', password: '...');
class AuthNotifier extends AsyncNotifier<UserModel?> {
  late AuthService _authService;

  @override
  Future<UserModel?> build() async {
    _authService = ref.read(authServiceProvider);

    // Al construirse, verificamos si ya hay sesión activa
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      return await _authService.getUserProfile(currentUser.id);
    }
    return null;
  }

  // Login
  // Ejemplo: await ref.read(authNotifierProvider.notifier).signIn(...)
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return await _authService.signIn(
        email: email,
        password: password,
      );
    });
  }

  // Registro
  Future<void> signUp({
    required String email,
    required String password,
    required String username,
    required String role,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return await _authService.signUp(
        email: email,
        password: password,
        username: username,
        role: role,
      );
    });
  }

  // Logout
  Future<void> signOut() async {
    state = const AsyncLoading();
    await _authService.signOut();
    state = const AsyncData(null);
  }

  // Actualizar perfil
  Future<void> updateProfile({
    String? fullName,
    String? bio,
    String? avatarUrl,
    String? language,
  }) async {
    state = await AsyncValue.guard(() async {
      return await _authService.updateProfile(
        fullName: fullName,
        bio: bio,
        avatarUrl: avatarUrl,
        language: language,
      );
    });
  }
}

// Provider del AuthNotifier
// Este es el que usarás en la mayoría de pantallas
final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, UserModel?>(AuthNotifier.new);