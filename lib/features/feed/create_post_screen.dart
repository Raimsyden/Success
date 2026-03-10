import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../app/app_theme.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/post_service.dart';
import 'feed_screen.dart' show Avatar;

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen>
    with SingleTickerProviderStateMixin {

  final _contentController = TextEditingController();
  final _picker            = ImagePicker();
  final _postService       = PostService();

  final List<File> _selectedImages = [];
  String _postType  = 'update';
  bool _isPublishing = false;

  // Animación de entrada
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
    _contentController.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // ¿El usuario puede publicar?
  bool get _canPublish =>
      _contentController.text.trim().isNotEmpty ||
      _selectedImages.isNotEmpty;

  // ─── SELECCIONAR IMÁGENES DE GALERÍA ──────────────────────────────────
  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage(
      imageQuality: 80,
      limit: 10 - _selectedImages.length,
    );
    if (picked.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(picked.map((x) => File(x.path)));
      });
    }
  }

  // ─── TOMAR FOTO CON CÁMARA ─────────────────────────────────────────────
  Future<void> _openCamera() async {
    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (photo != null) {
      setState(() => _selectedImages.add(File(photo.path)));
    }
  }

  // ─── PUBLICAR ─────────────────────────────────────────────────────────
  Future<void> _publish() async {
    if (!_canPublish) return;

    setState(() => _isPublishing = true);

    try {
      await _postService.createPost(
        content: _contentController.text.trim().isEmpty
            ? null
            : _contentController.text.trim(),
        images: _selectedImages,
        postType: _postType,
      );

      if (mounted) Navigator.pop(context);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al publicar: ${e.toString()}'),
            backgroundColor: Colors.redAccent.withOpacity(0.9),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  // ─── SELECTOR DE TIPO DE POST ─────────────────────────────────────────
  void _showPostTypeSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PostTypeSheet(
        selected: _postType,
        onSelect: (type) {
          setState(() => _postType = type);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SlideTransition(
        position: _slideAnim,
        child: SafeArea(
          child: Column(
            children: [

              // ─── BARRA SUPERIOR ─────────────────────────────────────
              _buildTopBar(),
              Divider(height: 1, color: AppColors.border),

              // ─── CONTENIDO SCROLLEABLE ──────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [

                      // Usuario + selector de tipo
                      _buildUserRow(userAsync),

                      // Campo de texto
                      _buildTextField(),

                      // Preview de imágenes seleccionadas
                      if (_selectedImages.isNotEmpty)
                        _buildImagePreview(),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // ─── BARRA INFERIOR DE ACCIONES ─────────────────────────
              Divider(height: 1, color: AppColors.border),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── WIDGETS PRIVADOS ─────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          // Botón cancelar
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancelar',
              style: TextStyle(
                color: AppColors.textMuted,
                fontFamily: 'DM Sans',
                fontSize: 15,
              ),
            ),
          ),

          // Título
          const Expanded(
            child: Center(
              child: Text(
                'Nueva publicación',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.cream,
                  fontFamily: 'DM Sans',
                ),
              ),
            ),
          ),

          // Botón publicar
          _PublishButton(
            canPublish: _canPublish,
            isLoading: _isPublishing,
            onTap: _publish,
          ),
        ],
      ),
    );
  }

  Widget _buildUserRow(AsyncValue userAsync) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          userAsync.when(
            data: (user) => Avatar(
              url: user?.avatarUrl,
              letter: user?.username.substring(0, 1).toUpperCase() ?? 'U',
              size: 44,
            ),
            loading: () => Container(
              width: 44, height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.backgroundLight,
              ),
            ),
            error: (_, _) => const SizedBox(),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              userAsync.when(
                data: (user) => Text(
                  user?.username ?? 'Usuario',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.cream,
                  ),
                ),
                loading: () => const SizedBox(),
                error: (_, _) => const SizedBox(),
              ),
              const SizedBox(height: 4),

              // Selector de tipo de post
              GestureDetector(
                onTap: _showPostTypeSelector,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getPostTypeIcon(),
                        size: 12,
                        color: AppColors.mint,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getPostTypeLabel(),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.mint,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_drop_down,
                        size: 14,
                        color: AppColors.mint,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TextField(
        controller: _contentController,
        maxLines: null,
        autofocus: true,
        onChanged: (_) => setState(() {}),
        style: TextStyle(
          fontSize: 17,
          color: AppColors.cream.withOpacity(0.9),
          height: 1.5,
          fontFamily: 'DM Sans',
        ),
        decoration: InputDecoration(
          hintText: '¿Qué está pasando en tu emprendimiento?',
          hintStyle: TextStyle(
            color: AppColors.cream.withOpacity(0.2),
            fontSize: 17,
            fontFamily: 'DM Sans',
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Column(
      children: [
        const SizedBox(height: 16),

        // Una sola imagen
        if (_selectedImages.length == 1)
          Stack(
            children: [
              ClipRRect(
                child: Image.file(
                  _selectedImages[0],
                  width: double.infinity,
                  height: 260,
                  fit: BoxFit.cover,
                ),
              ),
              _removeImageButton(0),
            ],
          )

        // Múltiples imágenes en scroll horizontal
        else
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _selectedImages.length,
              itemBuilder: (ctx, i) => Stack(
                children: [
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        _selectedImages[i],
                        width: 130,
                        height: 130,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  _removeImageButton(i, offset: 4),
                ],
              ),
            ),
          ),

        // Contador de imágenes
        Padding(
          padding: const EdgeInsets.only(top: 8, right: 16),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${_selectedImages.length}/10 imágenes',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.cream.withOpacity(0.3),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Botón X para eliminar una imagen del preview
  Widget _removeImageButton(int index, {double offset = 8}) {
    return Positioned(
      top: offset,
      right: index == 0 && _selectedImages.length == 1 ? offset : offset + 8,
      child: GestureDetector(
        onTap: () => setState(() => _selectedImages.removeAt(index)),
        child: Container(
          width: 26, height: 26,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: const Icon(Icons.close, color: Colors.white, size: 14),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      color: AppColors.background,
      padding: EdgeInsets.only(
        left: 8, right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Text(
              'Añadir a tu publicación:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const Spacer(),
          _BottomAction(
            icon: Icons.photo_library_outlined,
            color: AppColors.mint,
            tooltip: 'Galería',
            onTap: _pickImages,
            enabled: _selectedImages.length < 10,
          ),
          _BottomAction(
            icon: Icons.camera_alt_outlined,
            color: AppColors.mint,
            tooltip: 'Cámara',
            onTap: _openCamera,
            enabled: _selectedImages.length < 10,
          ),
          _BottomAction(
            icon: Icons.sell_outlined,
            color: AppColors.peach,
            tooltip: 'Producto',
            onTap: () => setState(() => _postType = 'product'),
          ),
          _BottomAction(
            icon: Icons.location_on_outlined,
            color: Colors.redAccent,
            tooltip: 'Ubicación',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  IconData _getPostTypeIcon() {
    switch (_postType) {
      case 'product': return Icons.sell_outlined;
      case 'announcement': return Icons.campaign_outlined;
      default: return Icons.public_outlined;
    }
  }

  String _getPostTypeLabel() {
    switch (_postType) {
      case 'product': return 'Producto';
      case 'announcement': return 'Anuncio';
      default: return 'Público';
    }
  }
}

// ─── BOTÓN PUBLICAR ───────────────────────────────────────────────────────
class _PublishButton extends StatefulWidget {
  final bool canPublish;
  final bool isLoading;
  final VoidCallback onTap;

  const _PublishButton({
    required this.canPublish,
    required this.isLoading,
    required this.onTap,
  });

  @override
  State<_PublishButton> createState() => _PublishButtonState();
}

class _PublishButtonState extends State<_PublishButton>
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
    _scale = Tween<double>(begin: 1, end: 0.92).animate(
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
    return GestureDetector(
      onTapDown: (_) {
        if (widget.canPublish) _ctrl.forward();
      },
      onTapUp: (_) {
        _ctrl.reverse();
        if (widget.canPublish) widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            gradient: widget.canPublish
                ? const LinearGradient(
                    colors: [AppColors.peach, AppColors.peachDark],
                  )
                : null,
            color: widget.canPublish
                ? null
                : AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(24),
          ),
          child: widget.isLoading
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  'Publicar',
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: widget.canPublish
                        ? AppColors.background
                        : AppColors.cream.withOpacity(0.3),
                  ),
                ),
        ),
      ),
    );
  }
}

// ─── BOTÓN DE ACCIÓN INFERIOR ─────────────────────────────────────────────
class _BottomAction extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  final bool enabled;

  const _BottomAction({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
    this.enabled = true,
  });

  @override
  State<_BottomAction> createState() => _BottomActionState();
}

class _BottomActionState extends State<_BottomAction>
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
    _scale = Tween<double>(begin: 1, end: 0.8).animate(
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
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTapDown: (_) {
          if (widget.enabled) _ctrl.forward();
        },
        onTapUp: (_) {
          _ctrl.reverse();
          if (widget.enabled) widget.onTap();
        },
        onTapCancel: () => _ctrl.reverse(),
        child: ScaleTransition(
          scale: _scale,
          child: Container(
            width: 40, height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: widget.enabled
                  ? widget.color.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              widget.icon,
              color: widget.enabled
                  ? widget.color
                  : widget.color.withOpacity(0.2),
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── SELECTOR DE TIPO DE POST ─────────────────────────────────────────────
class _PostTypeSheet extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;

  const _PostTypeSheet({
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final types = [
      (value: 'update', icon: Icons.public_outlined,
       label: 'Actualización', desc: 'Comparte una novedad'),
      (value: 'product', icon: Icons.sell_outlined,
       label: 'Producto', desc: 'Muestra algo que vendes'),
      (value: 'announcement', icon: Icons.campaign_outlined,
       label: 'Anuncio', desc: 'Comunica algo importante'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 8, left: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'TIPO DE PUBLICACIÓN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: AppColors.mint,
                ),
              ),
            ),
          ),
          ...types.map((type) => ListTile(
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: selected == type.value
                    ? AppColors.peach.withOpacity(0.1)
                    : AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                type.icon,
                color: selected == type.value
                    ? AppColors.peach
                    : AppColors.mint,
                size: 20,
              ),
            ),
            title: Text(
              type.label,
              style: TextStyle(
                color: selected == type.value
                    ? AppColors.peach
                    : AppColors.cream,
                fontWeight: selected == type.value
                    ? FontWeight.w600
                    : FontWeight.normal,
                fontFamily: 'DM Sans',
              ),
            ),
            subtitle: Text(
              type.desc,
              style: TextStyle(
                color: AppColors.cream.withOpacity(0.35),
                fontSize: 12,
                fontFamily: 'DM Sans',
              ),
            ),
            trailing: selected == type.value
                ? Container(
                    width: 22, height: 22,
                    decoration: const BoxDecoration(
                      color: AppColors.peach,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 14,
                      color: AppColors.background,
                    ),
                  )
                : null,
            onTap: () => onSelect(type.value),
          )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}