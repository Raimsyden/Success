import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../app/app_theme.dart';
import '../../core/models/post_model.dart';
import '../../core/models/user_model.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/post_service.dart';
import '../../core/services/rls_test_service.dart';
import 'create_post_screen.dart';

// ─── PROVIDER DEL FEED ────────────────────────────────────────────────────
final feedProvider = AsyncNotifierProvider<FeedNotifier, List<PostModel>>(
  FeedNotifier.new,
);

class FeedNotifier extends AsyncNotifier<List<PostModel>> {
  final _service = PostService();
  int _page = 0;
  bool _hasMore = true;

  @override
  Future<List<PostModel>> build() async {
    _page = 0;
    _hasMore = true;
    return await _service.getFeed(page: 0);
  }

  // Carga más posts al llegar al final del feed
  Future<void> loadMore() async {
    if (!_hasMore || state.isLoading) return;
    _page++;
    final more = await _service.getFeed(page: _page);
    if (more.isEmpty) {
      _hasMore = false;
      return;
    }
    state = AsyncData([...state.value!, ...more]);
  }

  // Refresca el feed desde el inicio
  Future<void> refresh() async {
    _page = 0;
    _hasMore = true;
    state = const AsyncLoading();
    state = AsyncData(await _service.getFeed(page: 0));
  }

  // Actualiza el like de un post localmente sin recargar todo el feed
  void updatePostLike(String postId, bool isLiked) {
    final posts = state.value;
    if (posts == null) return;

    state = AsyncData(posts.map((post) {
      if (post.id == postId) {
        return post.copyWith(
          isLikedByMe: isLiked,
          likesCount: isLiked
              ? post.likesCount + 1
              : post.likesCount - 1,
        );
      }
      return post;
    }).toList());
  }
}

// ─── PANTALLA PRINCIPAL ───────────────────────────────────────────────────
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  int _selectedTab = 0; // 0=feed, 1=explore, 2=create, 3=shop, 4=profile

  @override
  Widget build(BuildContext context) {
      final feedAsync = ref.watch(feedProvider);
      final userAsync = ref.watch(currentUserProvider);
        debugPrint('[FeedScreen] building, userAsync=${userAsync.runtimeType}');
        userAsync.whenData((u) => debugPrint('[FeedScreen] user=${u?.username}'));

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: Column(
        children: [
          // Navbar superior - mostrar aunque falle el usuario
          _FeedNavbar(userAsync: userAsync),

          // Feed scrolleable - Cambiar según la pestaña seleccionada
          // No depende de userAsync para funcionar
          Expanded(
            child: _buildContent(_selectedTab, feedAsync, userAsync, ref),
          ),
        ],
      ),

      // Navbar inferior
      bottomNavigationBar: _BottomNav(
        selectedIndex: _selectedTab,
        onTabChanged: (index) {
          setState(() => _selectedTab = index);
          // Si hace clic en crear post, abrir modal
          if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CreatePostScreen(),
              ),
            ).then((_) => ref.refresh(feedProvider));
          }
        },
      ),

      // Button para ejecutar RLS tests en desarrollo
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: Colors.orange.withOpacity(0.8),
        onPressed: _showRLSTestModal,
        tooltip: 'RLS Debug Tests',
        child: const Icon(Icons.bug_report),
      ),
    );
  }

  // Mostrar modal para ejecutar tests de RLS
  void _showRLSTestModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _RLSTestPanel(),
    );
  }

  // Construir el contenido según la pestaña seleccionada
  Widget _buildContent(
    int tab,
    AsyncValue<List<PostModel>> feedAsync,
    AsyncValue<UserModel?> userAsync,
    WidgetRef ref,
  ) {
    return switch (tab) {
      0 => _buildFeedTab(feedAsync, userAsync, ref),
      1 => _buildExploreTab(ref),
      2 => Container(), // No mostrar nada, abre modal
      3 => _buildShopTab(),
      4 => _buildProfileTab(userAsync),
      _ => _buildFeedTab(feedAsync, userAsync, ref),
    };
  }

  // TAB 0: Feed
  Widget _buildFeedTab(
    AsyncValue<List<PostModel>> feedAsync,
    AsyncValue<UserModel?> userAsync,
    WidgetRef ref,
  ) {
    return feedAsync.when(
      loading: () => const _FeedLoading(),
      error: (e, _) => _FeedError(
        onRetry: () => ref.refresh(feedProvider),
      ),
      data: (posts) => RefreshIndicator(
        color: AppColors.peach,
        backgroundColor: AppColors.backgroundCard,
        onRefresh: () => ref.read(feedProvider.notifier).refresh(),
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: posts.length + 2,
          itemBuilder: (ctx, i) {
            if (i == 0) {
              return _CreatePostBar(
                userAsync: userAsync,
                onTap: () {
                  setState(() => _selectedTab = 2);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreatePostScreen(),
                    ),
                  ).then((_) => ref.refresh(feedProvider));
                },
              );
            }
            if (i == posts.length + 1) {
              return _LoadMoreTrigger(
                onVisible: () =>
                    ref.read(feedProvider.notifier).loadMore(),
              );
            }
            final post = posts[i - 1];
            return PostCard(
              post: post,
              onLike: () {
                ref
                    .read(feedProvider.notifier)
                    .updatePostLike(post.id, !post.isLikedByMe);
                PostService().toggleLike(post.id);
              },
            );
          },
        ),
      ),
    );
  }

  // TAB 1: Explorar
  Widget _buildExploreTab(WidgetRef ref) {
    return _ExploreContent();
  }

  // TAB 3: Shop/Tienda
  Widget _buildShopTab() {
    return _ShopContent();
  }

  // TAB 4: Perfil
  Widget _buildProfileTab(AsyncValue<UserModel?> userAsync) {
    return userAsync.when(
      data: (user) => user != null
          ? _ProfileContent(user: user)
          : const Center(
              child: Text('No hay usuario logueado'),
            ),
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.peach),
      ),
      error: (e, _) => Center(
        child: Text('Error cargando perfil: $e'),
      ),
    );
  }
}

// ─── NAVBAR SUPERIOR ──────────────────────────────────────────────────────
class _FeedNavbar extends StatelessWidget {
  final AsyncValue userAsync;

  const _FeedNavbar({required this.userAsync});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 12,
        left: 20,
        right: 12,
      ),
      child: Row(
        children: [
          // Logo
          RichText(
            text: const TextSpan(children: [
              TextSpan(
                text: 'Suc',
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.cream,
                ),
              ),
              TextSpan(
                text: 'cess',
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.peach,
                ),
              ),
            ]),
          ),

          const Spacer(),

          // Iconos de acción
          _NavIconButton(icon: Icons.search_rounded, onTap: () {}),
          _NavIconButton(icon: Icons.notifications_outlined, onTap: () {}),
          _NavIconButton(
            icon: Icons.chat_bubble_outline_rounded,
            onTap: () {},
          ),
          // avatar para ir al perfil propio
          userAsync.when(
            data: (user) => user == null
                ? const SizedBox.shrink()
                : GestureDetector(
                    onTap: () {
                      debugPrint('[Feed] navbar avatar tapped');
                      context.go('/profile/${user.id}');
                    },
                    child: Avatar(
                      url: user.avatarUrl,
                      letter: user.username.isNotEmpty
                          ? user.username[0].toUpperCase()
                          : 'U',
                      size: 32,
                    ),
                  ),
            loading: () => const _AvatarPlaceholder(size: 32),
            error: (_, _) => const _AvatarPlaceholder(size: 32),
          ),
        ],
      ),
    );
  }
}

class _NavIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NavIconButton({required this.icon, required this.onTap});

  @override
  State<_NavIconButton> createState() => _NavIconButtonState();
}

class _NavIconButtonState extends State<_NavIconButton>
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
    _scale = Tween<double>(begin: 1, end: 0.85).animate(
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
        child: Container(
          width: 40, height: 40,
          margin: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(widget.icon, color: AppColors.cream, size: 20),
        ),
      ),
    );
  }
}

// ─── BARRA DE CREAR POST ──────────────────────────────────────────────────
class _CreatePostBar extends StatelessWidget {
  final AsyncValue userAsync;
  final VoidCallback onTap;

  const _CreatePostBar({required this.userAsync, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        debugPrint('[Feed] create bar tapped');
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Avatar del usuario (tappable para ir a perfil)
            userAsync.when(
              data: (user) => GestureDetector(
                onTap: user == null
                    ? null
                    : () {
                        debugPrint('[Feed] create bar avatar tapped');
                        context.go('/profile/${user.id}');
                      },
                child: Avatar(
                  url: user?.avatarUrl,
                  letter: user?.username.substring(0, 1).toUpperCase() ?? 'U',
                  size: 38,
                ),
              ),
              loading: () => const _AvatarPlaceholder(size: 38),
              error: (_, _) => const _AvatarPlaceholder(size: 38),
            ),
            const SizedBox(width: 12),

            // Placeholder de texto
            Expanded(
              child: Text(
                '¿Qué está pasando?',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.cream.withOpacity(0.3),
                  fontFamily: 'DM Sans',
                ),
              ),
            ),

            // Botón de foto
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: AppColors.mint.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.photo_library_outlined,
                color: AppColors.mint,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── TARJETA DE POST ──────────────────────────────────────────────────────
class PostCard extends StatefulWidget {
  final PostModel post;
  final VoidCallback? onLike;

  const PostCard({super.key, required this.post, this.onLike});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard>
    with SingleTickerProviderStateMixin {

  // Animación de escala al hacer hover sobre el post
  late AnimationController _hoverCtrl;
  late Animation<double> _hoverScale;

  @override
  void initState() {
    super.initState();
    _hoverCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _hoverScale = Tween<double>(begin: 1.0, end: 1.025).animate(
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
    return MouseRegion(
      // En desktop/web: agrandar al pasar el mouse
      onEnter: (_) => _hoverCtrl.forward(),
      onExit: (_) => _hoverCtrl.reverse(),
      child: ScaleTransition(
        scale: _hoverScale,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabecera del post
              _PostHeader(post: widget.post),

              // Texto del post
              if (widget.post.hasText)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    widget.post.content!,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: AppColors.cream.withOpacity(0.85),
                    ),
                  ),
                ),

              // Grid de imágenes
              if (widget.post.hasImages)
                _PostImagesGrid(urls: widget.post.mediaUrls),

              // Contadores
              _PostStats(post: widget.post),

              // Separador
              Divider(
                height: 1,
                color: AppColors.border,
                indent: 16,
                endIndent: 16,
              ),

              // Botones de acción
              _PostActions(
                post: widget.post,
                onLike: widget.onLike,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── CABECERA DEL POST ────────────────────────────────────────────────────
class _PostHeader extends StatelessWidget {
  final PostModel post;
  const _PostHeader({required this.post});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              debugPrint('[Feed] post author avatar tapped id=${post.authorId}');
              context.go('/profile/${post.authorId}');
            },
            child: Avatar(
              url: post.authorAvatarUrl,
              letter: (post.authorUsername ?? 'U')[0].toUpperCase(),
              size: 42,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nombre + badge
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        debugPrint('[Feed] post username tapped id=${post.authorId}');
                        context.go('/profile/${post.authorId}');
                      },
                      child: Text(
                        post.authorUsername ?? 'Usuario',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.cream,
                        ),
                      ),
                    ),
                    if (post.authorRole != null &&
                        post.authorRole != 'client') ...[
                      const SizedBox(width: 6),
                      _RoleBadge(role: post.authorRole!),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                // Tiempo relativo
                Text(
                  timeago.format(post.createdAt, locale: 'es'),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.cream.withOpacity(0.35),
                  ),
                ),
              ],
            ),
          ),

          // Menú de opciones
          _PostMenuButton(post: post),
        ],
      ),
    );
  }
}

// ─── BADGE DE ROL ─────────────────────────────────────────────────────────
class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final isEntrepreneur = role == 'entrepreneur';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
        isEntrepreneur ? 'Emprendedor' : 'Empresa',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isEntrepreneur ? AppColors.peach : AppColors.mint,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─── MENÚ DEL POST ────────────────────────────────────────────────────────
class _PostMenuButton extends StatelessWidget {
  final PostModel post;
  const _PostMenuButton({required this.post});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: AppColors.backgroundCard,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => _PostMenuSheet(post: post),
        );
      },
      icon: Icon(
        Icons.more_horiz,
        color: AppColors.cream.withOpacity(0.3),
      ),
    );
  }
}

class _PostMenuSheet extends StatelessWidget {
  final PostModel post;
  const _PostMenuSheet({required this.post});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          _SheetItem(
            icon: Icons.bookmark_border_rounded,
            label: 'Guardar publicación',
            onTap: () => Navigator.pop(context),
          ),
          _SheetItem(
            icon: Icons.person_add_outlined,
            label: 'Seguir a ${post.authorUsername}',
            onTap: () => Navigator.pop(context),
          ),
          _SheetItem(
            icon: Icons.flag_outlined,
            label: 'Reportar publicación',
            color: Colors.redAccent,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SheetItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _SheetItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.mint, size: 22),
      title: Text(
        label,
        style: TextStyle(
          color: color ?? AppColors.cream,
          fontSize: 14,
          fontFamily: 'DM Sans',
        ),
      ),
      onTap: onTap,
    );
  }
}

// ─── GRID DE IMÁGENES ─────────────────────────────────────────────────────
class _PostImagesGrid extends StatelessWidget {
  final List<String> urls;
  const _PostImagesGrid({required this.urls});

  @override
  Widget build(BuildContext context) {
    return switch (urls.length) {
      1 => _singleImage(urls[0]),
      2 => _doubleImage(),
      3 => _tripleImage(),
      _ => _quadImage(),
    };
  }

  Widget _img(String url, {double? height}) {
    return CachedNetworkImage(
      imageUrl: url,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        height: height,
        color: AppColors.backgroundLight,
        child: const Center(
          child: CircularProgressIndicator(
            color: AppColors.mint,
            strokeWidth: 2,
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        height: height,
        color: AppColors.backgroundLight,
        child: const Icon(Icons.broken_image, color: AppColors.mint),
      ),
    );
  }

  Widget _singleImage(String url) => ClipRRect(
    borderRadius: const BorderRadius.only(
      bottomLeft: Radius.circular(0),
      bottomRight: Radius.circular(0),
    ),
    child: _img(url, height: 240),
  );

  Widget _doubleImage() => SizedBox(
    height: 200,
    child: Row(children: [
      Expanded(child: _img(urls[0])),
      const SizedBox(width: 2),
      Expanded(child: _img(urls[1])),
    ]),
  );

  Widget _tripleImage() => SizedBox(
    height: 200,
    child: Row(children: [
      Expanded(flex: 2, child: _img(urls[0])),
      const SizedBox(width: 2),
      Expanded(child: Column(children: [
        Expanded(child: _img(urls[1])),
        const SizedBox(height: 2),
        Expanded(child: _img(urls[2])),
      ])),
    ]),
  );

  Widget _quadImage() {
    final extra = urls.length - 4;
    return SizedBox(
      height: 220,
      child: Column(children: [
        Expanded(child: Row(children: [
          Expanded(child: _img(urls[0])),
          const SizedBox(width: 2),
          Expanded(child: _img(urls[1])),
        ])),
        const SizedBox(height: 2),
        Expanded(child: Row(children: [
          Expanded(child: _img(urls[2])),
          const SizedBox(width: 2),
          Expanded(child: Stack(fit: StackFit.expand, children: [
            _img(urls[3]),
            if (extra > 0)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Text(
                    '+$extra',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ])),
        ])),
      ]),
    );
  }
}

// ─── ESTADÍSTICAS DEL POST ────────────────────────────────────────────────
class _PostStats extends StatelessWidget {
  final PostModel post;
  const _PostStats({required this.post});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          if (post.likesCount > 0) ...[
            Container(
              width: 20, height: 20,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.peach, AppColors.peachDark],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite,
                color: Colors.white,
                size: 11,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${post.likesCount}',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.cream.withOpacity(0.4),
              ),
            ),
          ],
          const Spacer(),
          if (post.commentsCount > 0)
            Text(
              '${post.commentsCount} comentarios',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.cream.withOpacity(0.4),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── BOTONES DE ACCIÓN ────────────────────────────────────────────────────
class _PostActions extends StatelessWidget {
  final PostModel post;
  final VoidCallback? onLike;

  const _PostActions({required this.post, this.onLike});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          _ActionButton(
            icon: post.isLikedByMe
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            label: 'Me gusta',
            isActive: post.isLikedByMe,
            activeColor: AppColors.peach,
            onTap: onLike,
          ),
          _ActionButton(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Comentar',
            onTap: () {},
          ),
          _ActionButton(
            icon: Icons.ios_share_rounded,
            label: 'Compartir',
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color? activeColor;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.isActive = false,
    this.activeColor,
    this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton>
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
    _scale = Tween<double>(begin: 1, end: 1.15).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isActive
        ? (widget.activeColor ?? AppColors.peach)
        : AppColors.cream.withOpacity(0.4);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          _ctrl.forward().then((_) => _ctrl.reverse());
          widget.onTap?.call();
        },
        child: ScaleTransition(
          scale: _scale,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: color, size: 18),
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 13,
                    color: color,
                    fontWeight: widget.isActive
                        ? FontWeight.w600
                        : FontWeight.normal,
                    fontFamily: 'DM Sans',
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

// ─── NAVEGACIÓN INFERIOR ──────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTabChanged;

  const _BottomNav({
    required this.selectedIndex,
    required this.onTabChanged,
  });

  final List<({IconData icon, String label})> _tabs = const [
    (icon: Icons.home_rounded, label: 'Inicio'),
    (icon: Icons.search_rounded, label: 'Explorar'),
    (icon: Icons.add_circle_rounded, label: 'Publicar'),
    (icon: Icons.storefront_rounded, label: 'Tienda'),
    (icon: Icons.person_rounded, label: 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 8,
        top: 8,
      ),
      child: Row(
        children: List.generate(_tabs.length, (i) {
          final tab = _tabs[i];
          final isSelected = selectedIndex == i;

          return Expanded(
            child: GestureDetector(
              onTap: () => onTabChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedScale(
                      scale: isSelected ? 1.15 : 1.0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        tab.icon,
                        size: 24,
                        color: isSelected
                            ? AppColors.peach
                            : AppColors.cream.withOpacity(0.3),
                      ),
                    ),
                    if (isSelected)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: AppColors.peach,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── WIDGETS AUXILIARES ───────────────────────────────────────────────────
class Avatar extends StatelessWidget {
  final String? url;
  final String letter;
  final double size;

  const Avatar({super.key, this.url, required this.letter, required this.size});

  @override
  Widget build(BuildContext context) {
    if (url != null) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: url!,
          width: size, height: size,
          fit: BoxFit.cover,
          errorWidget: (context, url, error) => _letterAvatar(),
        ),
      );
    }
    return _letterAvatar();
  }

  Widget _letterAvatar() {
    return Container(
      width: size, height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppColors.peach, AppColors.mint],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.w700,
            color: AppColors.background,
            fontFamily: 'DM Sans',
          ),
        ),
      ),
    );
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  final double size;
  const _AvatarPlaceholder({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.backgroundLight,
      ),
    );
  }
}

class _FeedLoading extends StatelessWidget {
  const _FeedLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: AppColors.peach,
            strokeWidth: 2.5,
          ),
          const SizedBox(height: 16),
          Text(
            'Cargando feed...',
            style: TextStyle(
              color: AppColors.cream.withOpacity(0.4),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedError extends StatelessWidget {
  final VoidCallback onRetry;
  const _FeedError({required this.onRetry});

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
            'No se pudo cargar el feed',
            style: TextStyle(
              color: AppColors.cream.withOpacity(0.5),
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

class _LoadMoreTrigger extends StatefulWidget {
  final VoidCallback onVisible;
  const _LoadMoreTrigger({required this.onVisible});

  @override
  State<_LoadMoreTrigger> createState() => _LoadMoreTriggerState();
}

class _LoadMoreTriggerState extends State<_LoadMoreTrigger> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onVisible();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: CircularProgressIndicator(
          color: AppColors.peach.withOpacity(0.5),
          strokeWidth: 2,
        ),
      ),
    );
  }
}

// ─── TAB EXPLORAR ─────────────────────────────────────────────────────────
class _ExploreContent extends StatelessWidget {
  const _ExploreContent();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Buscador
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(Icons.search_rounded,
                    color: AppColors.cream.withOpacity(0.3), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar emprendedores, negocios...',
                      hintStyle: TextStyle(
                          color: AppColors.cream.withOpacity(0.3)),
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(color: AppColors.cream),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Tendencias
          Text(
            'Tendencias',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.cream,
            ),
          ),
          const SizedBox(height: 12),

          // Lista de tendencias (placeholder)
          Column(
            children: List.generate(
              5,
              (i) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tendencia #${i + 1}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.cream,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(i + 1) * 234} posts',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.cream.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                    Icon(Icons.chevron_right,
                        color: AppColors.cream.withOpacity(0.3)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── TAB TIENDA ────────────────────────────────────────────────────────────
class _ShopContent extends StatelessWidget {
  const _ShopContent();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mis Negocios',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.cream,
            ),
          ),
          const SizedBox(height: 16),

          // Grid de negocios (placeholder)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: 4,
            itemBuilder: (context, i) {
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.backgroundLight,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                        ),
                        child: Icon(
                          Icons.storefront_rounded,
                          color: AppColors.mint.withOpacity(0.5),
                          size: 40,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Negocio ${i + 1}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.cream,
                              ),
                            ),
                            Text(
                              '12 productos',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.cream.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── TAB PERFIL ────────────────────────────────────────────────────────────
class _ProfileContent extends StatelessWidget {
  final UserModel user;
  const _ProfileContent({required this.user});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar
          Avatar(
            url: user.avatarUrl,
            letter: user.username.isNotEmpty
                ? user.username[0].toUpperCase()
                : 'U',
            size: 80,
          ),
          const SizedBox(height: 16),

          // Nombre y usuario
          Text(
            user.fullName ?? user.username,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.cream,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '@${user.username}',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.cream.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),

          // Bio
          if (user.bio != null && user.bio!.isNotEmpty)
            Text(
              user.bio!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.cream.withOpacity(0.7),
              ),
            ),
          const SizedBox(height: 20),

          // Estadísticas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatItem(label: 'Seguidores', value: '234'),
              _StatItem(label: 'Siguiendo', value: '567'),
              _StatItem(label: 'Posts', value: '23'),
            ],
          ),
          const SizedBox(height: 24),

          // Botón editar perfil
          GestureDetector(
            onTap: () {
              // Navegar a editar perfil
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.peach,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Editar Perfil',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.background,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Mis posts
          Text(
            'Mis Publicaciones',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.cream,
            ),
          ),
          const SizedBox(height: 12),

          // Placeholder para posts
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.image_not_supported_outlined,
                  color: AppColors.cream.withOpacity(0.2),
                  size: 40,
                ),
                const SizedBox(height: 12),
                Text(
                  'No hay publicaciones',
                  style: TextStyle(
                    color: AppColors.cream.withOpacity(0.5),
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
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.peach,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.cream.withOpacity(0.5),
          ),
        ),
      ],
    );
  }
}

// ─── RLS TEST PANEL ─────────────────────────────────────────────────────
class _RLSTestPanel extends ConsumerStatefulWidget {
  @override
  ConsumerState<_RLSTestPanel> createState() => _RLSTestPanelState();
}

class _RLSTestPanelState extends ConsumerState<_RLSTestPanel> {
  bool _isRunning = false;
  Map<String, dynamic>? _results;
  String _logs = '';

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'RLS Test Suite',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(color: Colors.grey),
            const SizedBox(height: 16),

            // Botón para ejecutar tests
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isRunning ? null : _runTests,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.peach,
                  disabledBackgroundColor: Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isRunning
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Run All RLS Tests',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Resultados
            if (_results != null) ...[
              Text(
                'Results:',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              _buildResultsWidget(_results!),
              const SizedBox(height: 16),
            ],

            // Logs
            if (_logs.isNotEmpty) ...[
              Text(
                'Debug Logs:',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey),
                ),
                child: Text(
                  _logs,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultsWidget(Map<String, dynamic> results) {
    final allPassed = results['all_passed'] as bool;
    final testResults = results['results'] as Map<String, dynamic>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status global
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: allPassed ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: allPassed ? Colors.green : Colors.red,
            ),
          ),
          child: Row(
            children: [
              Icon(
                allPassed ? Icons.check_circle : Icons.error,
                color: allPassed ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 12),
              Text(
                allPassed ? 'All tests PASSED ✓' : 'Some tests FAILED ✗',
                style: TextStyle(
                  color: allPassed ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Resultados individuales
        ...testResults.entries.map((entry) {
          final testName = entry.key;
          final result = entry.value as Map<String, dynamic>;
          final success = result['success'] as bool;
          final details = result['details'] as String?;
          final error = result['error'] as String?;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: success ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: success ? Colors.green : Colors.orange,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        success ? Icons.check : Icons.warning,
                        color: success ? Colors.green : Colors.orange,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        testName.replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(
                          color: success ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  if (details != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      details,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Error: $error',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 11,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _runTests() async {
    setState(() {
      _isRunning = true;
      _logs = 'Ejecutando tests...\n';
    });

    try {
      final service = RLSTestService();
      final results = await service.runAllTests();

      setState(() {
        _results = results;
        _logs += '\n✓ Tests completados exitosamente';
      });
    } catch (e) {
      setState(() {
        _logs += '\n✗ Error durante tests: $e';
      });
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }
}