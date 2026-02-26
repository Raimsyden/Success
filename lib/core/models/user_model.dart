class UserModel {
  final String id;
  final String email;
  final String username;
  final String? fullName;      // El ? significa que puede ser nulo
  final String? avatarUrl;
  final String? bio;
  final String role;           // 'client', 'entrepreneur', 'business'
  final bool isVerified;
  final String language;       // 'es' o 'en'
  final DateTime createdAt;

  // Constructor: define los datos que necesita un UserModel para existir
  UserModel({
    required this.id,
    required this.email,
    required this.username,
    this.fullName,             
    this.avatarUrl,
    this.bio,
    required this.role,
    required this.isVerified,
    required this.language,
    required this.createdAt,
  });

  // fromJson: convierte el JSON de Supabase en un objeto UserModel
  // Se llama así: UserModel.fromJson(respuestaDeSupabase)
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      email: json['email'],
      username: json['username'],
      fullName: json['full_name'],
      avatarUrl: json['avatar_url'],
      bio: json['bio'],
      role: json['role'] ?? 'client',         // Si no tiene rol, es cliente
      isVerified: json['is_verified'] ?? false,
      language: json['language'] ?? 'es',
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  // toJson: convierte el objeto de vuelta a JSON para enviar a Supabase
  // Se usa cuando quieres guardar o actualizar datos
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'bio': bio,
      'role': role,
      'is_verified': isVerified,
      'language': language,
    };
  }

  // copyWith: crea una copia del usuario cambiando solo algunos campos
  // Muy útil para actualizar el perfil sin recrear todo el objeto
  UserModel copyWith({
    String? fullName,
    String? avatarUrl,
    String? bio,
    String? language,
  }) {
    return UserModel(
      id: id,
      email: email,
      username: username,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      role: role,
      isVerified: isVerified,
      language: language ?? this.language,
      createdAt: createdAt,
    );
  }

  // Helpers útiles para la UI
  bool get isEntrepreneur => role == 'entrepreneur';
  bool get isBusiness => role == 'business';
  bool get isClient => role == 'client';
  bool get canPost => role == 'entrepreneur' || role == 'business';
}