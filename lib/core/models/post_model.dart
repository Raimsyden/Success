class PostModel {
  final String id;
  final String authorId;
  final String? content;           // El texto del post (puede ir sin texto)
  final List<String> mediaUrls;    // Lista de URLs de imágenes
  final String postType;           // 'update', 'product' o 'announcement'
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final bool isPublic;
  final DateTime createdAt;

  // Datos del autor que vienen del JOIN con la tabla users
  final String? authorUsername;
  final String? authorAvatarUrl;
  final String? authorRole;        // Para mostrar el badge correcto

  // Estado local del dispositivo: ¿yo le di like?
  final bool isLikedByMe;

  PostModel({
    required this.id,
    required this.authorId,
    this.content,
    required this.mediaUrls,
    required this.postType,
    required this.likesCount,
    required this.commentsCount,
    required this.sharesCount,
    required this.isPublic,
    required this.createdAt,
    this.authorUsername,
    this.authorAvatarUrl,
    this.authorRole,
    this.isLikedByMe = false,      // Por defecto no le has dado like
  });

  // Convierte el JSON de Supabase en un PostModel
  // Supabase nos devuelve el autor anidado así:
  // { "id": "...", "content": "...", "users": { "username": "..." } }
  factory PostModel.fromJson(Map<String, dynamic> json) {
    // Extraemos el objeto 'users' que viene del JOIN
    final author = json['users'] as Map<String, dynamic>?;

    return PostModel(
      id: json['id'],
      authorId: json['author_id'],
      content: json['content'],
      mediaUrls: List<String>.from(json['media_urls'] ?? []),
      postType: json['post_type'] ?? 'update',
      likesCount: json['likes_count'] ?? 0,
      commentsCount: json['comments_count'] ?? 0,
      sharesCount: json['shares_count'] ?? 0,
      isPublic: json['is_public'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      authorUsername: author?['username'],
      authorAvatarUrl: author?['avatar_url'],
      authorRole: author?['role'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'author_id': authorId,
      'content': content,
      'media_urls': mediaUrls,
      'post_type': postType,
      'is_public': isPublic,
    };
  }

  // copyWith: útil para actualizar el like sin recargar todo el feed
  // Ejemplo de uso:
  //   post.copyWith(likesCount: post.likesCount + 1, isLikedByMe: true)
  PostModel copyWith({
    int? likesCount,
    int? commentsCount,
    bool? isLikedByMe,
  }) {
    return PostModel(
      id: id,
      authorId: authorId,
      content: content,
      mediaUrls: mediaUrls,
      postType: postType,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      sharesCount: sharesCount,
      isPublic: isPublic,
      createdAt: createdAt,
      authorUsername: authorUsername,
      authorAvatarUrl: authorAvatarUrl,
      authorRole: authorRole,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
    );
  }

  // Helpers para la UI — evitan escribir lógica en los widgets
  bool get hasImages => mediaUrls.isNotEmpty;
  bool get hasText => content != null && content!.isNotEmpty;
  bool get isProduct => postType == 'product';
  bool get isAnnouncement => postType == 'announcement';

  // Devuelve el color del badge según el rol del autor
  // Uso: Color badgeColor = post.authorBadgeColor
  String get authorBadgeColor {
    switch (authorRole) {
      case 'business':
        return 'blue';
      case 'entrepreneur':
        return 'orange';
      default:
        return 'none';
    }
  }
}