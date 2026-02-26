class ProductModel {
  final String id;
  final String ventureId;        // A qué emprendimiento pertenece
  final String name;
  final String? description;
  final double price;
  final String currency;         // 'COP', 'USD', 'EUR'
  final int stock;
  final List<String> images;     // Hasta 5 imágenes del producto
  final String? category;
  final bool isAvailable;        // El dueño puede pausar el producto
  final DateTime createdAt;

  // Datos del venture que vienen del JOIN
  final String? ventureName;
  final String? ventureLogoUrl;

  ProductModel({
    required this.id,
    required this.ventureId,
    required this.name,
    this.description,
    required this.price,
    required this.currency,
    required this.stock,
    required this.images,
    this.category,
    required this.isAvailable,
    required this.createdAt,
    this.ventureName,
    this.ventureLogoUrl,
  });

  // Convierte el JSON de Supabase en un ProductModel
  // Supabase nos devuelve el venture anidado así:
  // { "id": "...", "name": "...", "ventures": { "name": "Café Don Juan" } }
  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final venture = json['ventures'] as Map<String, dynamic>?;

    return ProductModel(
      id: json['id'],
      ventureId: json['venture_id'],
      name: json['name'],
      description: json['description'],
      price: (json['price'] as num).toDouble(),
      currency: json['currency'] ?? 'COP',
      stock: json['stock'] ?? 0,
      images: List<String>.from(json['images'] ?? []),
      category: json['category'],
      isAvailable: json['is_available'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      ventureName: venture?['name'],
      ventureLogoUrl: venture?['logo_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'venture_id': ventureId,
      'name': name,
      'description': description,
      'price': price,
      'currency': currency,
      'stock': stock,
      'images': images,
      'category': category,
      'is_available': isAvailable,
    };
  }

  // copyWith: útil cuando el dueño actualiza precio o stock
  // Ejemplo:
  //   producto.copyWith(stock: producto.stock - 1)  ← cuando alguien compra
  ProductModel copyWith({
    String? name,
    String? description,
    double? price,
    int? stock,
    bool? isAvailable,
  }) {
    return ProductModel(
      id: id,
      ventureId: ventureId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      currency: currency,
      stock: stock ?? this.stock,
      images: images,
      category: category,
      isAvailable: isAvailable ?? this.isAvailable,
      createdAt: createdAt,
      ventureName: ventureName,
      ventureLogoUrl: ventureLogoUrl,
    );
  }

  // Helpers para la UI
  bool get hasImages => images.isNotEmpty;
  bool get hasStock => stock > 0;
  bool get isOnSale => isAvailable && hasStock;

  // Formatea el precio según la moneda
  // Ejemplo: formatPrice() → '$12.500 COP'
  String get formattedPrice {
    final formatted = price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return '\$$formatted $currency';
  }

  // Texto de disponibilidad para mostrar en la UI
  String get availabilityText {
    if (!isAvailable) return 'No disponible';
    if (!hasStock) return 'Agotado';
    return 'Disponible · $stock en stock';
  }
}