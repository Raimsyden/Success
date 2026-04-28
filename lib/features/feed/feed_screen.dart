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
import 'package:supabase_flutter/supabase_flutter.dart';
// import '../../core/services/rls_test_service.dart'; Eliminado
import 'create_post_screen.dart';
import 'comments_screen.dart';  
import '../messages/messages_screen.dart';

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
          _NavIconButton(
            icon: Icons.chat_bubble_outline_rounded,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MessagesScreen(),
                ),
              );
            },
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
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CommentsScreen(post: post),
                ),
              );
            },
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
// ─── TAB EXPLORAR ─────────────────────────────────────────────────────────
final allVenturesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await Supabase.instance.client
      .from('ventures')
      .select('*, users!owner_id(username, avatar_url, role)')
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(response);
});

class _ExploreContent extends ConsumerWidget {
  const _ExploreContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venturesAsync = ref.watch(allVenturesProvider);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
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
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              'EMPRENDIMIENTOS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: AppColors.mint,
              ),
            ),
          ),
        ),
        venturesAsync.when(
          loading: () => const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(
                    color: AppColors.peach, strokeWidth: 2),
              ),
            ),
          ),
          error: (e, _) => SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Error cargando emprendimientos',
                  style: TextStyle(color: AppColors.cream.withOpacity(0.4)),
                ),
              ),
            ),
          ),
          data: (ventures) {
            if (ventures.isEmpty) {
              return SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.storefront_outlined,
                            size: 48,
                            color: AppColors.cream.withOpacity(0.15)),
                        const SizedBox(height: 12),
                        Text(
                          'Aún no hay emprendimientos',
                          style: TextStyle(
                              color: AppColors.cream.withOpacity(0.3)),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final v = ventures[i];
                  final owner = v['users'] as Map<String, dynamic>?;
                  return Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        leading: Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(
                              colors: [AppColors.peach, AppColors.mint],
                            ),
                          ),
                          child: v['logo_url'] != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: CachedNetworkImage(
                                    imageUrl: v['logo_url'],
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    (v['name'] as String)[0].toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                        ),
                        title: Text(
                          v['name'] ?? '',
                          style: const TextStyle(
                            color: AppColors.cream,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'DM Sans',
                          ),
                        ),
                        subtitle: owner != null
                            ? Text(
                                '@${owner['username']}',
                                style: TextStyle(
                                  color: AppColors.cream.withOpacity(0.4),
                                  fontSize: 12,
                                ),
                              )
                            : null,
                        trailing: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: AppColors.mint,
                        ),
                        onTap: () => context.go(
                          '/products/${v['id']}',
                          extra: {'name': v['name']},
                        ),
                      ),
                      Divider(
                          color: AppColors.border,
                          height: 1,
                          indent: 16,
                          endIndent: 16),
                    ],
                  );
                },
                childCount: ventures.length,
              ),
            );
          },
        ),
      ],
    );
  }
}
// ─── TAB TIENDA ────────────────────────────────────────────────────────────
// ─── TAB TIENDA ────────────────────────────────────────────────────────────
final myVenturesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return [];
  final response = await Supabase.instance.client
      .from('ventures')
      .select()
      .eq('owner_id', userId)
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(response);
});

class _ShopContent extends ConsumerWidget {
  const _ShopContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venturesAsync = ref.watch(myVenturesProvider);

    return venturesAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.peach, strokeWidth: 2),
      ),
      error: (e, _) => Center(
        child: Text('Error',
            style: TextStyle(color: AppColors.cream.withOpacity(0.4))),
      ),
      data: (ventures) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Mis Negocios',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.cream,
                    fontFamily: 'Playfair Display',
                  ),
                ),
                TextButton.icon(
                  onPressed: () {}, // TODO: crear venture
                  icon: const Icon(Icons.add, color: AppColors.peach, size: 18),
                  label: const Text(
                    'Nuevo',
                    style: TextStyle(color: AppColors.peach, fontFamily: 'DM Sans'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (ventures.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(Icons.storefront_outlined,
                          size: 56,
                          color: AppColors.cream.withOpacity(0.15)),
                      const SizedBox(height: 16),
                      Text(
                        'Aún no tienes negocios',
                        style: TextStyle(
                          color: AppColors.cream.withOpacity(0.4),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.9,
                ),
                itemCount: ventures.length,
                itemBuilder: (_, i) {
                  final v = ventures[i];
                  return GestureDetector(
                    onTap: () => context.go(
                      '/products/${v['id']}',
                      extra: {'name': v['name']},
                    ),
                    child: Container(
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
                                gradient: const LinearGradient(
                                  colors: [AppColors.peach, AppColors.mint],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(16),
                                ),
                              ),
                              child: v['logo_url'] != null
                                  ? ClipRRect(
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(16),
                                        topRight: Radius.circular(16),
                                      ),
                                      child: CachedNetworkImage(
                                        imageUrl: v['logo_url'],
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                      ),
                                    )
                                  : Center(
                                      child: Text(
                                        (v['name'] as String)[0].toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 36,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          fontFamily: 'Playfair Display',
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    v['name'] ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.cream,
                                      fontFamily: 'DM Sans',
                                    ),
                                  ),
                                  Text(
                                    v['description'] ?? 'Sin descripción',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.cream.withOpacity(0.4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
// ─── TAB PERFIL ────────────────────────────────────────────────────────────
final myPostsCountProvider = FutureProvider<int>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return 0;
  final response = await Supabase.instance.client
      .from('posts')
      .select('id')
      .eq('author_id', userId)
      .eq('is_public', true);
  return (response as List).length;
});

class _ProfileContent extends ConsumerWidget {
  final UserModel user;
  const _ProfileContent({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsCount = ref.watch(myPostsCountProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Avatar(
            url: user.avatarUrl,
            letter: user.username.isNotEmpty
                ? user.username[0].toUpperCase()
                : 'U',
            size: 80,
          ),
          const SizedBox(height: 16),
          Text(
            user.fullName ?? user.username,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.cream,
              fontFamily: 'Playfair Display',
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
          if (user.bio != null && user.bio!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              user.bio!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.cream.withOpacity(0.7),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatItem(
                label: 'Posts',
                value: postsCount.when(
                  data: (n) => '$n',
                  loading: () => '...',
                  error: (_, __) => '0',
                ),  
              ),
              _StatItem(label: 'Seguidores', value: '0'),
              _StatItem(label: 'Siguiendo', value: '0'),
            ],
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => context.go('/profile/${user.id}'),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Ver perfil completo',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.cream,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'DM Sans',
                ),
              ),
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
