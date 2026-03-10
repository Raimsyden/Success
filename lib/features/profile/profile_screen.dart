import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../app/app_theme.dart';
import '../../core/models/user_model.dart';
import '../../core/models/post_model.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/post_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/auth_service.dart';

// ─── PROVIDERS ────────────────────────────────────────────────────────────
// posts del usuario
final userPostsProvider = FutureProvider.family<List<PostModel>, String>(
  (ref, userId) => PostService().getUserPosts(userId),
);

// proveedor para cargar cualquier perfil de usuario por id
final userProfileProvider = FutureProvider.family<UserModel?, String>(
  (ref, userId) async {
    // usamos el servicio de autenticación porque ya sabe cómo leer el perfil
    return await AuthService().getUserProfile(userId);
  },
);
class ProfileScreen extends ConsumerStatefulWidget {
  final String? userId; // null = perfil propio

  const ProfileScreen({super.key, this.userId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {

  late TabController _tabController;
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ¿Es el perfil del usuario logueado?
  bool get _isOwnProfile {
    final currentUser = ref.read(authNotifierProvider).value;
    // si no se pasó ningún id estamos viendo nuestro propio perfil
    // o si el id coincide con el del usuario logueado
    return widget.userId == null || widget.userId == currentUser?.id;
  }

  @override
  Widget build(BuildContext context) {
    // normalizamos el parámetro recibido: cadena vacía se trata como null
    final viewedUserId = (widget.userId != null && widget.userId!.isEmpty)
        ? null
        : widget.userId;

    final userAsync = viewedUserId == null
        ? ref.watch(currentUserProvider)
        : ref.watch(userProfileProvider(viewedUserId));

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: userAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.peach),
        ),
        error: (e, _) {
          debugPrint('[Profile] error loading user: $e');
          return Center(
            child: Text(
              'Error cargando perfil',
              style: TextStyle(color: AppColors.cream.withOpacity(0.5)),
            ),
          );
        },
        data: (user) {
          debugPrint('[Profile] userId=${viewedUserId ?? '[me]'} user=$user');
          if (user == null) {
            return Center(
              child: Text(
                'Perfil no disponible',
                style: TextStyle(color: AppColors.cream.withOpacity(0.5)),
              ),
            );
          }
          return NestedScrollView(
            headerSliverBuilder: (ctx, _) => [
              _ProfileSliverHeader(
                user: user,
                isOwnProfile: _isOwnProfile,
                isFollowing: _isFollowing,
                onFollowTap: () {
                  setState(() => _isFollowing = !_isFollowing);
                  // mostrar mensaje oportuno
                  final action = _isFollowing ? 'Siguiendo' : 'Dejar de seguir';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$action a @${user.username}')),
                  );
                },
                onEditTap: () => _showEditProfile(user),
                tabController: _tabController,
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                // Pestaña publicaciones
                _PostsGrid(userId: viewedUserId ?? user.id),

                // Pestaña venture/productos
                _VentureTab(user: user),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── MODAL DE EDITAR PERFIL ───────────────────────────────────────────
  void _showEditProfile(UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EditProfileSheet(user: user),
    );
  }
}

// ─── HEADER CON SLIVER ────────────────────────────────────────────────────
class _ProfileSliverHeader extends StatelessWidget {
  final UserModel user;
  final bool isOwnProfile;
  final bool isFollowing;
  final VoidCallback onFollowTap;
  final VoidCallback onEditTap;
  final TabController tabController;

  const _ProfileSliverHeader({
    required this.user,
    required this.isOwnProfile,
    required this.isFollowing,
    required this.onFollowTap,
    required this.onEditTap,
    required this.tabController,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 380,
      pinned: true,
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.cream,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_horiz),
          onPressed: () {},
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: _ProfileInfo(
          user: user,
          isOwnProfile: isOwnProfile,
          isFollowing: isFollowing,
          onFollowTap: onFollowTap,
          onEditTap: onEditTap,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          color: AppColors.background,
          child: TabBar(
            controller: tabController,
            indicatorColor: AppColors.peach,
            indicatorWeight: 2,
            labelColor: AppColors.peach,
            unselectedLabelColor: AppColors.cream.withOpacity(0.4),
            labelStyle: const TextStyle(
              fontFamily: 'DM Sans',
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            tabs: const [
              Tab(text: 'Publicaciones'),
              Tab(text: 'Venture'),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── INFO DEL PERFIL ──────────────────────────────────────────────────────
class _ProfileInfo extends StatelessWidget {
  final UserModel user;
  final bool isOwnProfile;
  final bool isFollowing;
  final VoidCallback onFollowTap;
  final VoidCallback onEditTap;

  const _ProfileInfo({
    required this.user,
    required this.isOwnProfile,
    required this.isFollowing,
    required this.onFollowTap,
    required this.onEditTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 56,
        bottom: 16,
        left: 20,
        right: 20,
      ),
      child: Column(
        children: [

          // Avatar con opción de cambiar foto si es propio
          _ProfileAvatar(user: user, isOwnProfile: isOwnProfile),
          const SizedBox(height: 16),

          // Nombre
          Text(
            user.fullName ?? user.username,
            style: const TextStyle(
              fontFamily: 'Playfair Display',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.cream,
            ),
          ),

          // Username + badge de rol
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '@${user.username}',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.cream.withOpacity(0.4),
                ),
              ),
              if (!user.isClient) ...[
                const SizedBox(width: 6),
                _RolePill(role: user.role),
              ],
            ],
          ),

          // Bio
          if (user.bio != null && user.bio!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              user.bio!,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.cream.withOpacity(0.6),
                height: 1.5,
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Botón editar o seguir
          isOwnProfile
              ? _EditButton(onTap: onEditTap)
              : _FollowButton(
                  isFollowing: isFollowing,
                  onTap: onFollowTap,
                ),

          const SizedBox(height: 20),

          // Estadísticas
          _ProfileStats(),
        ],
      ),
    );
  }
}

// ─── AVATAR DEL PERFIL ────────────────────────────────────────────────────
class _ProfileAvatar extends ConsumerWidget {
  final UserModel user;
  final bool isOwnProfile;

  const _ProfileAvatar({required this.user, required this.isOwnProfile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: isOwnProfile ? () => _changeAvatar(context, ref) : null,
      child: Stack(
        children: [
          Container(
            width: 90, height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.peach, AppColors.mint],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: AppColors.background,
                width: 3,
              ),
            ),
            child: user.avatarUrl != null
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: user.avatarUrl!,
                      fit: BoxFit.cover,
                    ),
                  )

                  // Por aquí el cambio
                : Center(
                    child: Text(
                      user.username[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontFamily: 'DM Sans',
                      ),
                    ),
                  ),
          ),

          // Ícono de editar foto si es perfil propio
          if (isOwnProfile)
            Positioned(
              bottom: 0, right: 0,
              child: Container(
                width: 26, height: 26,
                decoration: BoxDecoration(
                  color: AppColors.peach,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.background,
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _changeAvatar(BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (photo == null) return;

    try {
      final url = await StorageService().uploadAvatar(File(photo.path));
      if (url != null) {
        await ref.read(authNotifierProvider.notifier).updateProfile(
          avatarUrl: url,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error actualizando foto')),
        );
      }
    }
  }
}

// ─── ESTADÍSTICAS ─────────────────────────────────────────────────────────
class _ProfileStats extends StatelessWidget {
  const _ProfileStats();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _StatItem(label: 'Posts', value: '24'),
        _StatDivider(),
        _StatItem(label: 'Seguidores', value: '142'),
        _StatDivider(),
        _StatItem(label: 'Seguidos', value: '89'),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.cream,
            fontFamily: 'Playfair Display',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.cream.withOpacity(0.4),
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1, height: 32,
      color: AppColors.border,
    );
  }
}

// ─── BOTONES DE ACCIÓN ────────────────────────────────────────────────────
class _EditButton extends StatelessWidget {
  final VoidCallback onTap;
  const _EditButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'Editar perfil',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.cream,
            fontFamily: 'DM Sans',
          ),
        ),
      ),
    );
  }
}

class _FollowButton extends StatefulWidget {
  final bool isFollowing;
  final VoidCallback onTap;

  const _FollowButton({required this.isFollowing, required this.onTap});

  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scale = Tween<double>(begin: 1, end: 0.94).animate(
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
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
          decoration: BoxDecoration(
            gradient: widget.isFollowing
                ? null
                : const LinearGradient(
                    colors: [AppColors.peach, AppColors.peachDark],
                  ),
            color: widget.isFollowing ? Colors.transparent : null,
            borderRadius: BorderRadius.circular(24),
            border: widget.isFollowing
                ? Border.all(color: AppColors.border)
                : null,
          ),
          child: Text(
            widget.isFollowing ? 'Siguiendo' : 'Seguir',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: widget.isFollowing
                  ? AppColors.cream
                  : AppColors.background,
              fontFamily: 'DM Sans',
            ),
          ),
        ),
      ),
    );
  }
}

// ─── BADGE DE ROL ─────────────────────────────────────────────────────────
class _RolePill extends StatelessWidget {
  final String role;
  const _RolePill({required this.role});

  @override
  Widget build(BuildContext context) {
    final isEntrepreneur = role == 'entrepreneur';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: isEntrepreneur
            ? AppColors.peach.withOpacity(0.12)
            : AppColors.mint.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isEntrepreneur
              ? AppColors.peach.withOpacity(0.3)
              : AppColors.mint.withOpacity(0.3),
        ),
      ),
      child: Text(
        isEntrepreneur ? '🚀 Emprendedor' : '🏢 Empresa',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isEntrepreneur ? AppColors.peach : AppColors.mint,
        ),
      ),
    );
  }
}

// ─── GRILLA DE POSTS ──────────────────────────────────────────────────────
class _PostsGrid extends ConsumerWidget {
  final String userId;
  const _PostsGrid({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(userPostsProvider(userId));

    return postsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.peach),
      ),
      error: (e, _) => Center(
        child: Text(
          'Error cargando posts',
          style: TextStyle(color: AppColors.cream.withOpacity(0.4)),
        ),
      ),
      data: (posts) {
        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.photo_library_outlined,
                  size: 48,
                  color: AppColors.cream.withOpacity(0.15),
                ),
                const SizedBox(height: 12),
                Text(
                  'Aún no hay publicaciones',
                  style: TextStyle(
                    color: AppColors.cream.withOpacity(0.3),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: posts.length,
          itemBuilder: (ctx, i) => _PostGridItem(post: posts[i]),
        );
      },
    );
  }
}

class _PostGridItem extends StatefulWidget {
  final PostModel post;
  const _PostGridItem({required this.post});

  @override
  State<_PostGridItem> createState() => _PostGridItemState();
}

class _PostGridItemState extends State<_PostGridItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scale = Tween<double>(begin: 1, end: 0.95).animate(
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
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) => _ctrl.reverse(),
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          color: AppColors.backgroundLight,
          child: CachedNetworkImage(
                  imageUrl: widget.post.mediaUrls[0],
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: AppColors.backgroundLight,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── PESTAÑA VENTURE ──────────────────────────────────────────────────────
class _VentureTab extends StatelessWidget {
  final UserModel user;
  const _VentureTab({required this.user});

  @override
  Widget build(BuildContext context) {
    if (!user.canPost) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.storefront_outlined,
              size: 48,
              color: AppColors.cream.withOpacity(0.15),
            ),
            const SizedBox(height: 12),
            Text(
              'Solo emprendedores y empresarios\ntienen venture',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.cream.withOpacity(0.3),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Card del venture
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          colors: [AppColors.peach, AppColors.mint],
                        ),
                      ),
                      child: const Center(
                        child: Text('☕', style: TextStyle(fontSize: 24)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Mi Emprendimiento',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.cream,
                              fontFamily: 'DM Sans',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Configura tu venture →',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.peach.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: AppColors.border, height: 1),
                const SizedBox(height: 16),
                Text(
                  'Productos',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                    color: AppColors.mint,
                  ),
                ),
                const SizedBox(height: 12),

                // Placeholder de productos
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.add_circle_outline_rounded,
                        size: 40,
                        color: AppColors.cream.withOpacity(0.15),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Agrega tu primer producto',
                        style: TextStyle(
                          color: AppColors.cream.withOpacity(0.3),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── MODAL EDITAR PERFIL ──────────────────────────────────────────────────
class _EditProfileSheet extends ConsumerStatefulWidget {
  final UserModel user;
  const _EditProfileSheet({required this.user});

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _bioCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user.fullName);
    _bioCtrl  = TextEditingController(text: widget.user.bio);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(authNotifierProvider.notifier).updateProfile(
        fullName: _nameCtrl.text.trim(),
        bio: _bioCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error guardando cambios')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Título
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Editar perfil',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.cream,
                    fontFamily: 'Playfair Display',
                  ),
                ),
                TextButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                            color: AppColors.peach,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Guardar',
                          style: TextStyle(
                            color: AppColors.peach,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Campo nombre
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: AppColors.cream),
              decoration: const InputDecoration(
                labelText: 'NOMBRE COMPLETO',
                hintText: 'Tu nombre',
              ),
            ),
            const SizedBox(height: 16),

            // Campo bio
            TextField(
              controller: _bioCtrl,
              maxLines: 3,
              maxLength: 150,
              style: const TextStyle(color: AppColors.cream),
              decoration: InputDecoration(
                labelText: 'BIOGRAFÍA',
                hintText: 'Cuéntanos sobre ti...',
                counterStyle: TextStyle(
                  color: AppColors.cream.withOpacity(0.3),
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}