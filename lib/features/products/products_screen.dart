import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../app/app_theme.dart';
import '../../core/models/product_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── PROVIDER DE PRODUCTOS ────────────────────────────────────────────────
// FutureProvider.family porque necesita el ventureId como parámetro
final productsProvider =
    FutureProvider.family<List<ProductModel>, String>((ref, ventureId) async {
  final response = await Supabase.instance.client
      .from('products')
      .select('*, ventures(name, logo_url)')
      .eq('venture_id', ventureId)
      .eq('is_available', true)
      .order('created_at', ascending: false);

  return (response as List)
      .map((json) => ProductModel.fromJson(json))
      .toList();
});

// ─── PANTALLA PRINCIPAL ───────────────────────────────────────────────────
class ProductsScreen extends ConsumerStatefulWidget {
  final String ventureId;
  final String ventureName;

  const ProductsScreen({
    super.key,
    required this.ventureId,
    required this.ventureName,
  });

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen>
    with SingleTickerProviderStateMixin {

  String? _selectedCategory;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut),
    );
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider(widget.ventureId));

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: productsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.peach),
          ),
          error: (e, _) => _ErrorView(
            onRetry: () => ref.refresh(productsProvider(widget.ventureId)),
          ),
          data: (products) {
            if (products.isEmpty) return const _EmptyView();

            // Categorías únicas de los productos
            final categories = products
                .map((p) => p.category)
                .whereType<String>()
                .toSet()
                .toList();

            // Filtramos por categoría seleccionada
            final filtered = _selectedCategory == null
                ? products
                : products
                    .where((p) => p.category == _selectedCategory)
                    .toList();

            return Column(
              children: [
                // Filtros de categoría
                if (categories.isNotEmpty)
                  _CategoryFilter(
                    categories: categories,
                    selected: _selectedCategory,
                    onSelect: (cat) =>
                        setState(() => _selectedCategory = cat),
                  ),

                // Grilla de productos
                Expanded(
                  child: _ProductsGrid(
                    products: filtered,
                    onProductTap: (product) =>
                        _openProductDetail(context, product),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.cream,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.ventureName,
            style: const TextStyle(
              fontFamily: 'Playfair Display',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.cream,
            ),
          ),
          Text(
            'Catálogo de productos',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.cream.withOpacity(0.4),
              fontFamily: 'DM Sans',
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded),
          onPressed: () {},
        ),
      ],
    );
  }

  void _openProductDetail(BuildContext context, ProductModel product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductDetailSheet(product: product),
    );
  }
}

// ─── FILTROS DE CATEGORÍA ─────────────────────────────────────────────────
class _CategoryFilter extends StatelessWidget {
  final List<String> categories;
  final String? selected;
  final ValueChanged<String?> onSelect;

  const _CategoryFilter({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      color: AppColors.background,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Chip "Todos"
          _CategoryChip(
            label: 'Todos',
            isSelected: selected == null,
            onTap: () => onSelect(null),
          ),
          const SizedBox(width: 8),

          // Chips de cada categoría
          ...categories.map((cat) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _CategoryChip(
              label: cat,
              isSelected: selected == cat,
              onTap: () => onSelect(cat),
            ),
          )),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.peach.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.peach.withOpacity(0.5)
                : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? AppColors.peach : AppColors.cream.withOpacity(0.5),
            fontFamily: 'DM Sans',
          ),
        ),
      ),
    );
  }
}

// ─── GRILLA DE PRODUCTOS ──────────────────────────────────────────────────
class _ProductsGrid extends StatelessWidget {
  final List<ProductModel> products;
  final ValueChanged<ProductModel> onProductTap;

  const _ProductsGrid({
    required this.products,
    required this.onProductTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.72,
      ),
      itemCount: products.length,
      itemBuilder: (ctx, i) => _ProductCard(
        product: products[i],
        onTap: () => onProductTap(products[i]),
      ),
    );
  }
}

// ─── TARJETA DE PRODUCTO ──────────────────────────────────────────────────
class _ProductCard extends StatefulWidget {
  final ProductModel product;
  final VoidCallback onTap;

  const _ProductCard({required this.product, required this.onTap});

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard>
    with SingleTickerProviderStateMixin {

  late AnimationController _hoverCtrl;
  late Animation<double> _hoverScale;

  @override
  void initState() {
    super.initState();
    _hoverCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _hoverScale = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _hoverCtrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _hoverCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;

    return MouseRegion(
      onEnter: (_) => _hoverCtrl.forward(),
      onExit: (_) => _hoverCtrl.reverse(),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => _hoverCtrl.forward(),
        onTapUp: (_) => _hoverCtrl.reverse(),
        onTapCancel: () => _hoverCtrl.reverse(),
        child: ScaleTransition(
          scale: _hoverScale,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Imagen del producto
                Expanded(
                  flex: 3,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                    child: product.hasImages
                        ? CachedNetworkImage(
                            imageUrl: product.images[0],
                            fit: BoxFit.cover,
                            width: double.infinity,
                            placeholder: (_, _) => Container(
                              color: AppColors.backgroundLight,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.mint,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          )
                        : Container(
                            color: AppColors.backgroundLight,
                            child: Center(
                              child: Icon(
                                Icons.image_outlined,
                                color: AppColors.mint.withOpacity(0.3),
                                size: 36,
                              ),
                            ),
                          ),
                  ),
                ),

                // Info del producto
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // Nombre
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.cream,
                            height: 1.3,
                          ),
                        ),
                        const Spacer(),

                        // Precio
                        Text(
                          product.formattedPrice,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.peach,
                            fontFamily: 'DM Sans',
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Disponibilidad
                        Row(
                          children: [
                            Container(
                              width: 6, height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: product.isOnSale
                                    ? AppColors.mint
                                    : Colors.redAccent,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              product.isOnSale ? 'Disponible' : 'Agotado',
                              style: TextStyle(
                                fontSize: 10,
                                color: product.isOnSale
                                    ? AppColors.mint
                                    : Colors.redAccent,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── DETALLE DEL PRODUCTO ─────────────────────────────────────────────────
class _ProductDetailSheet extends StatefulWidget {
  final ProductModel product;
  const _ProductDetailSheet({required this.product});

  @override
  State<_ProductDetailSheet> createState() => _ProductDetailSheetState();
}

class _ProductDetailSheetState extends State<_ProductDetailSheet>
    with SingleTickerProviderStateMixin {

  int _currentImage = 0;
  late AnimationController _animCtrl;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOutCubic,
    ));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;

    return SlideTransition(
      position: _slideAnim,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: const BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [

            // Handle
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Galería de imágenes
                    if (product.hasImages)
                      _ImageGallery(
                        images: product.images,
                        currentIndex: _currentImage,
                        onIndexChange: (i) =>
                            setState(() => _currentImage = i),
                      ),

                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          // Categoría
                          if (product.category != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4,
                              ),
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: AppColors.mint.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.mint.withOpacity(0.2),
                                ),
                              ),
                              child: Text(
                                product.category!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.mint,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),

                          // Nombre y precio
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  product.name,
                                  style: const TextStyle(
                                    fontFamily: 'Playfair Display',
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.cream,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                product.formattedPrice,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.peach,
                                  fontFamily: 'DM Sans',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Disponibilidad y stock
                          Row(
                            children: [
                              Container(
                                width: 8, height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: product.isOnSale
                                      ? AppColors.mint
                                      : Colors.redAccent,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                product.availabilityText,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: product.isOnSale
                                      ? AppColors.mint
                                      : Colors.redAccent,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Descripción
                          if (product.description != null) ...[
                            Text(
                              'Descripción',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5,
                                color: AppColors.mint,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              product.description!,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.cream.withOpacity(0.7),
                                height: 1.6,
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Vendedor
                          if (product.ventureName != null) ...[
                            Divider(color: AppColors.border, height: 1),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Container(
                                  width: 40, height: 40,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: const LinearGradient(
                                      colors: [
                                        AppColors.peach,
                                        AppColors.mint,
                                      ],
                                    ),
                                  ),
                                  child: const Center(
                                    child: Text('🏪',
                                        style: TextStyle(fontSize: 18)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.ventureName!,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.cream,
                                      ),
                                    ),
                                    Text(
                                      'Ver más productos →',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.peach
                                            .withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Botón de contactar vendedor
            _ContactButton(product: product),
          ],
        ),
      ),
    );
  }
}

// ─── GALERÍA DE IMÁGENES ──────────────────────────────────────────────────
class _ImageGallery extends StatelessWidget {
  final List<String> images;
  final int currentIndex;
  final ValueChanged<int> onIndexChange;

  const _ImageGallery({
    required this.images,
    required this.currentIndex,
    required this.onIndexChange,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Imagen principal
        SizedBox(
          height: 300,
          child: PageView.builder(
            onPageChanged: onIndexChange,
            itemCount: images.length,
            itemBuilder: (_, i) => CachedNetworkImage(
              imageUrl: images[i],
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(
                color: AppColors.backgroundLight,
              ),
            ),
          ),
        ),

        // Indicadores de página
        if (images.length > 1)
          Positioned(
            bottom: 12,
            left: 0, right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                images.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: currentIndex == i ? 20 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: currentIndex == i
                        ? AppColors.peach
                        : Colors.white.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── BOTÓN CONTACTAR VENDEDOR ─────────────────────────────────────────────
class _ContactButton extends StatefulWidget {
  final ProductModel product;
  const _ContactButton({required this.product});

  @override
  State<_ContactButton> createState() => _ContactButtonState();
}

class _ContactButtonState extends State<_ContactButton>
    with SingleTickerProviderStateMixin {

  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scale = Tween<double>(begin: 1, end: 0.96).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20, 12, 20,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: GestureDetector(
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) {
          _ctrl.reverse();
          // TODO: navegar al chat con el vendedor
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Contactando a ${widget.product.ventureName ?? "vendedor"}...',
              ),
              backgroundColor: AppColors.backgroundLight,
            ),
          );
        },
        onTapCancel: () => _ctrl.reverse(),
        child: ScaleTransition(
          scale: _scale,
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: widget.product.isOnSale
                  ? const LinearGradient(
                      colors: [AppColors.peach, AppColors.peachDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: widget.product.isOnSale
                  ? null
                  : AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(16),
              boxShadow: widget.product.isOnSale
                  ? [
                      BoxShadow(
                        color: AppColors.peach.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: widget.product.isOnSale
                      ? AppColors.background
                      : AppColors.cream.withOpacity(0.3),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  widget.product.isOnSale
                      ? 'Contactar vendedor'
                      : 'Producto agotado',
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: widget.product.isOnSale
                        ? AppColors.background
                        : AppColors.cream.withOpacity(0.3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── VISTAS AUXILIARES ────────────────────────────────────────────────────
class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.storefront_outlined,
            size: 56,
            color: AppColors.cream.withOpacity(0.12),
          ),
          const SizedBox(height: 16),
          Text(
            'Sin productos aún',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.cream.withOpacity(0.3),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Este emprendimiento aún no\nha publicado productos',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.cream.withOpacity(0.2),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off_rounded,
            size: 48,
            color: AppColors.cream.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'Error cargando productos',
            style: TextStyle(
              color: AppColors.cream.withOpacity(0.4),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onRetry,
            child: const Text(
              'Reintentar',
              style: TextStyle(color: AppColors.peach),
            ),
          ),
        ],
      ),
    );
  }
}