import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

class AuthService {
  // Acceso al cliente de Supabase
  // Este cliente es el que hace las llamadas reales a tu base de datos
  final _supabase = Supabase.instance.client;

  // ─── REGISTRO ──────────────────────────────────────────────────────────────
  // Crea una cuenta nueva en Supabase Auth Y guarda el perfil en la tabla users
  // Ejemplo de uso:
  //   await authService.signUp(
  //     email: 'juan@gmail.com',
  //     password: 'MiClave123',
  //     username: 'juanemprendedor',
  //     role: 'entrepreneur',
  //   );
  Future<UserModel?> signUp({
    required String email,
    required String password,
    required String username,
    required String role,
  }) async {
    // Paso 1: Crear la cuenta en Supabase Auth
    // Usamos `userMetadata` (API actual) en lugar de `data`.
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'username': username,
        'role': role,
      },
    );

    // A veces la respuesta contiene el usuario en `response.user`,
    // otras veces (confirmación por email) el usuario queda en
    // `auth.currentUser`. Comprobamos ambos.
    final createdUser = response.user ?? _supabase.auth.currentUser;

    // Paso 2: Si se creó el usuario, intentamos guardar el perfil en la tabla users
    if (createdUser != null) {
      try {
        await _supabase.from('users').insert({
          'id': createdUser.id, // Mismo ID que Supabase Auth
          'email': email,
          'username': username,
          'role': role,
          'language': 'es',
        });
      } catch (e, st) {
        // Si la tabla no existe u ocurre otro error de PostgREST, lo registramos
        debugPrint('Error al insertar perfil de usuario: $e');
        debugPrintStack(stackTrace: st);
        // No interrumpimos el registro; la cuenta de auth ya fue creada.
        // Devolveremos null en lugar de intentar leer un perfil inexistente.
      }

      // Paso 3: Traer el perfil recién creado y devolverlo como UserModel
      // Si la inserción falló, esta llamada también puede lanzar; la capturamos
      try {
        return await getUserProfile(createdUser.id);
      } catch (e, st) {
        debugPrint('Error al leer perfil tras registro: $e');
        debugPrintStack(stackTrace: st);
        return null;
      }
    }

    return null;
  }

  // ─── LOGIN ─────────────────────────────────────────────────────────────────
  // Inicia sesión con email y contraseña
  // Supabase guarda el token JWT automáticamente en el dispositivo
  // Ejemplo de uso:
  //   final user = await authService.signIn(
  //     email: 'juan@gmail.com',
  //     password: 'MiClave123',
  //   );
  Future<UserModel?> signIn({
    required String email,
    required String password,
  }) async {
    debugPrint('signIn: iniciando con email=$email');
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      debugPrint('signIn: respuesta obtenida, usuario=${response.user?.id}');

      // Si el login fue exitoso, traemos el perfil completo de la tabla users
      if (response.user != null) {
        debugPrint('signIn: obteniendo perfil para ${response.user!.id}');
        return await getUserProfile(response.user!.id);
      }
      
      debugPrint('signIn: respuesta.user es null');
      return null;
    } catch (e, st) {
      debugPrint('signIn: error capturado: $e');
      debugPrintStack(stackTrace: st);
      rethrow;
    }
  }

  // ─── LOGOUT ────────────────────────────────────────────────────────────────
  // Cierra la sesión e invalida el token JWT
  // Después de esto, el usuario debe loguearse de nuevo
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // ─── RECUPERAR CONTRASEÑA ──────────────────────────────────────────────────
  // Envía un correo con un enlace para resetear la contraseña
  // Ejemplo de uso:
  //   await authService.resetPassword('juan@gmail.com');
  Future<void> resetPassword(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  // ─── PERFIL DEL USUARIO ────────────────────────────────────────────────────
  // Trae el perfil completo de un usuario desde la tabla users
  // Se usa internamente después del login y registro
  Future<UserModel?> getUserProfile(String userId) async {
    // maybesingle no lanza excepción si no existe el registro, devuelve null
    final response = await _supabase
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (response == null) return null;
    return UserModel.fromJson(response);
  }

  // ─── ESTADO ACTUAL ─────────────────────────────────────────────────────────
  // Devuelve el usuario que está logueado ahora mismo
  // Si nadie está logueado, devuelve null
  // Ejemplo de uso:
  //   if (authService.currentUser != null) {
  //     // mostrar home
  //   } else {
  //     // mostrar login
  //   }
  User? get currentUser => _supabase.auth.currentUser;

  // ─── STREAM DE AUTENTICACIÓN ───────────────────────────────────────────────
  // Escucha en tiempo real si el usuario inicia o cierra sesión
  // La app reacciona automáticamente sin que el usuario haga nada
  //
  // Ejemplo visual:
  //   Usuario abre la app → Stream emite 'logueado' → va al feed
  //   Usuario cierra sesión → Stream emite 'deslogueado' → va al login
  Stream<AuthState> get authStateChanges =>
      _supabase.auth.onAuthStateChange;

  // ─── VERIFICAR USERNAME DISPONIBLE ────────────────────────────────────────
  // Verifica si un username ya está tomado antes de registrarse
  // Ejemplo de uso:
  //   bool disponible = await authService.isUsernameAvailable('juanperez');
  Future<bool> isUsernameAvailable(String username) async {
    try {
      final response = await _supabase
          .from('users')
          .select('username')
          .eq('username', username)
          .maybeSingle();  // maybeSingle() devuelve null si no encuentra nada

      return response == null;  // Si no hay resultado, el username está libre
    } catch (e) {
      // En caso de error (tabla inexistente, permisos, etc) lo propagamos
      debugPrint('Error verificando disponibilidad de usuario: $e');
      rethrow;
    }
  }

  // ─── ACTUALIZAR PERFIL ─────────────────────────────────────────────────────
  // Actualiza los datos del perfil del usuario actual
  // Ejemplo de uso:
  //   await authService.updateProfile(bio: 'Emprendedor cafetero ☕');
  Future<UserModel?> updateProfile({
    String? fullName,
    String? bio,
    String? avatarUrl,
    String? language,
  }) async {
    final userId = currentUser?.id;
    if (userId == null) return null;

    // Solo enviamos los campos que no son nulos
    final updates = <String, dynamic>{};
    if (fullName != null) updates['full_name'] = fullName;
    if (bio != null) updates['bio'] = bio;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (language != null) updates['language'] = language;

    await _supabase
        .from('users')
        .update(updates)
        .eq('id', userId);

    return await getUserProfile(userId);
  }
}