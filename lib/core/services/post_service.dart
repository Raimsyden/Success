import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post_model.dart';
import 'storage_service.dart';

class PostService {
  final _supabase = Supabase.instance.client;
  final _storage = StorageService();

  // ─── OBTENER FEED ──────────────────────────────────────────────────────────
  // Trae las publicaciones ordenadas de más reciente a más antigua
  // con paginación de 15 posts por carga para no sobrecargar la app
  //
  // Ejemplo de uso:
  //   final posts = await postService.getFeed(page: 0); // primera carga
  //   final posts = await postService.getFeed(page: 1); // siguiente página
  Future<List<PostModel>> getFeed({int page = 0, int pageSize = 15}) async {
    final userId = _supabase.auth.currentUser?.id;

    // Calculamos el rango de registros a traer
    // página 0 → registros 0 al 14
    // página 1 → registros 15 al 29
    final from = page * pageSize;
    final to = from + pageSize - 1;

    // Hacemos la consulta a Supabase
    // select('*, users(...)') hace un JOIN automático con la tabla users
    // así traemos el nombre y avatar del autor en una sola consulta
    final response = await _supabase
        .from('posts')
        .select('*, users(username, avatar_url, role)')
        .eq('is_public', true)
        .order('created_at', ascending: false)
        .range(from, to);

    // Convertimos cada JSON en un PostModel
    final posts = (response as List)
        .map((json) => PostModel.fromJson(json))
        .toList();

    // Verificamos cuáles posts ya tienen like del usuario actual
    // para mostrar el botón de like en el estado correcto
    if (userId != null && posts.isNotEmpty) {
      final postIds = posts.map((p) => p.id).toList();

      final likes = await _supabase
          .from('likes')
          .select('post_id')
          .eq('user_id', userId)
          .inFilter('post_id', postIds);

      // Creamos un Set para buscar más rápido
      final likedIds = (likes as List)
          .map((l) => l['post_id'] as String)
          .toSet();

      // Marcamos cada post si el usuario ya le dio like
      return posts.map((post) => post.copyWith(
        isLikedByMe: likedIds.contains(post.id),
      )).toList();
    }

    return posts;
  }

  // ─── CREAR POST ────────────────────────────────────────────────────────────
  // Crea una nueva publicación con texto y/o imágenes
  //
  // Ejemplo de uso:
  //   final post = await postService.createPost(
  //     content: '¡Nuevo producto disponible!',
  //     images: [foto1, foto2],
  //     postType: 'product',
  //   );
  Future<PostModel> createPost({
    String? content,
    required List<File> images,
    required String postType,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    List<String> mediaUrls = [];

    // Paso 1: Si hay imágenes, subirlas primero a Storage
    if (images.isNotEmpty) {
      mediaUrls = await _storage.uploadPostImages(images);
    }

    // Paso 2: Guardar el post en la base de datos con las URLs de las imágenes
    final response = await _supabase
        .from('posts')
        .insert({
          'author_id': userId,
          'content': content,
          'media_urls': mediaUrls,
          'post_type': postType,
          'is_public': true,
        })
        .select('*, users(username, avatar_url, role)')
        .single();

    // Paso 3: Devolver el post creado como PostModel
    return PostModel.fromJson(response);
  }

  // ─── LIKE / UNLIKE ─────────────────────────────────────────────────────────
  // Alterna entre dar y quitar like a un post
  // Devuelve true si ahora tiene like, false si se quitó
  //
  // Ejemplo de uso:
  //   bool tienelike = await postService.toggleLike('id-del-post');
  //   // true  → le diste like
  //   // false → quitaste el like
  Future<bool> toggleLike(String postId) async {
    final userId = _supabase.auth.currentUser!.id;

    // Verificamos si ya existe el like en la base de datos
    final existing = await _supabase
        .from('likes')
        .select()
        .eq('user_id', userId)
        .eq('post_id', postId)
        .maybeSingle();

    if (existing != null) {
      // Ya tiene like → lo quitamos
      await _supabase
          .from('likes')
          .delete()
          .eq('user_id', userId)
          .eq('post_id', postId);
      return false;
    } else {
      // No tiene like → lo agregamos
      await _supabase.from('likes').insert({
        'user_id': userId,
        'post_id': postId,
      });
      return true;
    }
  }

  // ─── ELIMINAR POST ─────────────────────────────────────────────────────────
  // Elimina un post y todas sus imágenes asociadas en Storage
  // Solo el autor puede eliminar su propio post (RLS en Supabase lo garantiza)
  //
  // Ejemplo de uso:
  //   await postService.deletePost('id-del-post', post.mediaUrls);
  Future<void> deletePost(String postId, List<String> mediaUrls) async {
    // Paso 1: Eliminar las imágenes del Storage primero
    if (mediaUrls.isNotEmpty) {
      await _storage.deleteImages(mediaUrls, 'posts');
    }

    // Paso 2: Eliminar el post de la base de datos
    // Los comentarios y likes se eliminan en cascada automáticamente
    await _supabase
        .from('posts')
        .delete()
        .eq('id', postId);
  }

  // ─── POSTS DE UN USUARIO ───────────────────────────────────────────────────
  // Trae todos los posts de un usuario específico para su perfil
  //
  // Ejemplo de uso:
  //   final posts = await postService.getUserPosts('id-del-usuario');
  Future<List<PostModel>> getUserPosts(String userId) async {
    final response = await _supabase
        .from('posts')
        .select('*, users(username, avatar_url, role)')
        .eq('author_id', userId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => PostModel.fromJson(json))
        .toList();
  }
}