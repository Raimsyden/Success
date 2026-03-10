import 'package:flutter/foundation.dart';
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
// Verifica si hay un usuario logueado (simple y directo)
final authStateProvider = FutureProvider<bool>((ref) async {
  debugPrint('[AuthState] Verificando sesión...');
  
  try {
    final auth = Supabase.instance.client.auth;
    final currentUser = auth.currentUser;
    final isLoggedIn = currentUser != null;
    
    debugPrint('[AuthState] Sesión verificada: ${currentUser?.email ?? 'Sin usuario'} (isLoggedIn=$isLoggedIn)');
    return isLoggedIn;
  } catch (e) {
    debugPrint('[AuthState] Error verificando sesión: $e');
    return false;
  }
});

// ─── PROVIDER DEL USUARIO ACTUAL ──────────────────────────────────────────
// Mantiene el perfil completo del usuario logueado
final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  try {
    final currentUser = Supabase.instance.client.auth.currentUser;

    if (currentUser == null) {
      debugPrint('[CurrentUser] No hay usuario logueado');
      return null;
    }

    debugPrint('[CurrentUser] Obteniendo perfil de ${currentUser.email}...');
    final authService = ref.read(authServiceProvider);
    final profile = await authService.getUserProfile(currentUser.id);
    
    if (profile != null) {
      debugPrint('[CurrentUser] Perfil cargado: ${profile.username}');
    } else {
      debugPrint('[CurrentUser] Perfil es null (el usuario existe pero sin datos completos)');
    }
    
    return profile;
  } catch (e) {
    // En lugar de fallar, devolvemos null para que la UI no se bloquee
    // El usuario está logueado, aunque no podamos cargar su perfil
    debugPrint('[CurrentUser] Error (NO CRÍTICO): $e');
    debugPrint('[CurrentUser] → Continuando sin perfil. Verifica las políticas RLS en Supabase');
    return null;
  }
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