import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

class StorageService {
  final _supabase = Supabase.instance.client;

  static const String _postsBucket = 'posts';
  static const String _avatarsBucket = 'avatars';
  static const String _productsBucket = 'products';

  // Sube imágenes de un post y devuelve sus URLs públicas
  Future<List<String>> uploadPostImages(List<File> files) async {
    final List<String> urls = [];
    final userId = _supabase.auth.currentUser!.id;

    for (final file in files) {
      final url = await _uploadFile(
        file: file,
        bucket: _postsBucket,
        folder: userId,
      );
      if (url != null) urls.add(url);
    }

    return urls;
  }

  // Sube la foto de perfil del usuario
  Future<String?> uploadAvatar(File file) async {
    final userId = _supabase.auth.currentUser!.id;

    return await _uploadFile(
      file: file,
      bucket: _avatarsBucket,
      folder: userId,
      fileName: 'avatar',
    );
  }

  // Sube imágenes de un producto
  Future<List<String>> uploadProductImages(List<File> files) async {
    final List<String> urls = [];
    final userId = _supabase.auth.currentUser!.id;

    for (final file in files) {
      final url = await _uploadFile(
        file: file,
        bucket: _productsBucket,
        folder: userId,
      );
      if (url != null) urls.add(url);
    }

    return urls;
  }

  // Elimina imágenes de Supabase Storage
  Future<void> deleteImages(List<String> urls, String bucket) async {
    if (urls.isEmpty) return;

    final paths = urls.map((url) {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      final bucketIndex = segments.indexOf(bucket);
      return segments.sublist(bucketIndex + 1).join('/');
    }).toList();

    await _supabase.storage.from(bucket).remove(paths);
  }

  // Método privado reutilizable para subir cualquier imagen
  Future<String?> _uploadFile({
    required File file,
    required String bucket,
    required String folder,
    String? fileName,
  }) async {
    try {
      final ext = path.extension(file.path);
      final name = fileName != null
          ? '$fileName$ext'
          : '${DateTime.now().millisecondsSinceEpoch}$ext';

      final filePath = '$folder/$name';

      await _supabase.storage.from(bucket).upload(
        filePath,
        file,
        fileOptions: const FileOptions(
          contentType: 'image/jpeg',
          upsert: true,
        ),
      );

      final publicUrl = _supabase.storage
          .from(bucket)
          .getPublicUrl(filePath);

      return publicUrl;

    } catch (e) {
      print('Error subiendo imagen: $e');
      return null;
    }
  }
}