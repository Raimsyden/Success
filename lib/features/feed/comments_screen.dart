import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../app/app_theme.dart';
import '../../../core/models/post_model.dart';
import '../../../core/providers/auth_provider.dart';
import 'feed_screen.dart' show Avatar;

// ─── MODELO ───────────────────────────────────────────────────────────────
class CommentModel {
  final String id;
  final String postId;
  final String authorId;
  final String content;
  final DateTime createdAt;
  final String? authorUsername;
  final String? authorAvatarUrl;

  const CommentModel({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.content,
    required this.createdAt,
    this.authorUsername,
    this.authorAvatarUrl,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    final author = json['users'] as Map<String, dynamic>?;
    return CommentModel(
      id: json['id'],
      postId: json['post_id'],
      authorId: json['author_id'],
      content: json['content'],
      createdAt: DateTime.parse(json['created_at']),
      authorUsername: author?['username'],
      authorAvatarUrl: author?['avatar_url'],
    );
  }
}

// ─── PROVIDERS ────────────────────────────────────────────────────────────
final commentsProvider = StreamProvider.family<List<CommentModel>, String>(
  (ref, postId) {
    final stream = Supabase.instance.client
        .from('comments')
        .stream(primaryKey: ['id'])
        .eq('post_id', postId)
        .order('created_at', ascending: true);

    return stream.map((data) => data
        .map((json) => CommentModel.fromJson(json))
        .toList());
  },
);

// Provider separado para cargar los datos completos con JOIN
final commentsWithAuthorsProvider =
    FutureProvider.family<List<CommentModel>, String>(
  (ref, postId) async {
    final response = await Supabase.instance.client
        .from('comments')
        .select('*, users(username, avatar_url)')
        .eq('post_id', postId)
        .order('created_at', ascending: true);

    return (response as List)
        .map((json) => CommentModel.fromJson(json))
        .toList();
  },
);

// ─── PANTALLA DE COMENTARIOS ──────────────────────────────────────────────
class CommentsScreen extends ConsumerStatefulWidget {
  final PostModel post;

  const CommentsScreen({super.key, required this.post});

  @override
  ConsumerState<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends ConsumerState<CommentsScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;
  List<CommentModel> _comments = [];

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    final response = await Supabase.instance.client
        .from('comments')
        .select('*, users(username, avatar_url)')
        .eq('post_id', widget.post.id)
        .order('created_at', ascending: true);

    if (mounted) {
      setState(() {
        _comments = (response as List)
            .map((json) => CommentModel.fromJson(json))
            .toList();
      });
    }
  }

  Future<void> _sendComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isSending = true);
    _controller.clear();

    try {
      final response = await Supabase.instance.client
          .from('comments')
          .insert({
            'post_id': widget.post.id,
            'author_id': userId,
            'content': text,
          })
          .select('*, users(username, avatar_url)')
          .single();

      final newComment = CommentModel.fromJson(response);

      setState(() {
        _comments.add(newComment);
      });

      // Actualizar contador de comentarios en la DB
      await Supabase.instance.client.rpc('increment_comments_count', params: {
        'post_id': widget.post.id,
      });

      // Scroll al final
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      debugPrint('[Comments] error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al comentar: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _deleteComment(CommentModel comment) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != comment.authorId) return;

    await Supabase.instance.client
        .from('comments')
        .delete()
        .eq('id', comment.id);

    setState(() => _comments.remove(comment));
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.cream,
        title: const Text(
          'Comentarios',
          style: TextStyle(
            fontFamily: 'DM Sans',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.cream,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: Column(
        children: [
          // Post original resumido
          _PostSummary(post: widget.post),
          Divider(height: 1, color: AppColors.border),

          // Lista de comentarios
          Expanded(
            child: _comments.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 48,
                          color: AppColors.cream.withOpacity(0.15),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Sé el primero en comentar',
                          style: TextStyle(
                            color: AppColors.cream.withOpacity(0.3),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _comments.length,
                    itemBuilder: (_, i) => _CommentTile(
                      comment: _comments[i],
                      currentUserId:
                          Supabase.instance.client.auth.currentUser?.id,
                      onDelete: () => _deleteComment(_comments[i]),
                    ),
                  ),
          ),

          // Input de comentario
          Divider(height: 1, color: AppColors.border),
          _CommentInput(
            controller: _controller,
            isSending: _isSending,
            userAsync: userAsync,
            onSend: _sendComment,
          ),
        ],
      ),
    );
  }
}

// ─── RESUMEN DEL POST ─────────────────────────────────────────────────────
class _PostSummary extends StatelessWidget {
  final PostModel post;
  const _PostSummary({required this.post});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Avatar(
            url: post.authorAvatarUrl,
            letter: (post.authorUsername ?? 'U')[0].toUpperCase(),
            size: 36,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.authorUsername ?? 'Usuario',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.cream,
                    fontFamily: 'DM Sans',
                  ),
                ),
                if (post.content != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    post.content!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.cream.withOpacity(0.6),
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── TILE DE COMENTARIO ───────────────────────────────────────────────────
class _CommentTile extends StatelessWidget {
  final CommentModel comment;
  final String? currentUserId;
  final VoidCallback onDelete;

  const _CommentTile({
    required this.comment,
    required this.currentUserId,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isOwn = comment.authorId == currentUserId;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Avatar(
            url: comment.authorAvatarUrl,
            letter: (comment.authorUsername ?? 'U')[0].toUpperCase(),
            size: 34,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.authorUsername ?? 'Usuario',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.cream,
                        fontFamily: 'DM Sans',
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      timeago.format(comment.createdAt, locale: 'es'),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.cream.withOpacity(0.35),
                      ),
                    ),
                    if (isOwn) ...[
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: AppColors.backgroundCard,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(20)),
                            ),
                            builder: (_) => Padding(
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
                                  ListTile(
                                    leading: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.redAccent,
                                    ),
                                    title: const Text(
                                      'Eliminar comentario',
                                      style: TextStyle(
                                        color: Colors.redAccent,
                                        fontFamily: 'DM Sans',
                                      ),
                                    ),
                                    onTap: () {
                                      Navigator.pop(context);
                                      onDelete();
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              ),
                            ),
                          );
                        },
                        child: Icon(
                          Icons.more_horiz,
                          size: 16,
                          color: AppColors.cream.withOpacity(0.3),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    comment.content,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.cream.withOpacity(0.85),
                      height: 1.4,
                    ),
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

// ─── INPUT DE COMENTARIO ──────────────────────────────────────────────────
class _CommentInput extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final AsyncValue userAsync;
  final VoidCallback onSend;

  const _CommentInput({
    required this.controller,
    required this.isSending,
    required this.userAsync,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Row(
        children: [
          userAsync.when(
            data: (user) => Avatar(
              url: user?.avatarUrl,
              letter: user?.username.substring(0, 1).toUpperCase() ?? 'U',
              size: 32,
            ),
            loading: () => const SizedBox(width: 32, height: 32),
            error: (_, __) => const SizedBox(width: 32, height: 32),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      style: const TextStyle(
                        color: AppColors.cream,
                        fontSize: 14,
                        fontFamily: 'DM Sans',
                      ),
                      decoration: InputDecoration(
                        hintText: 'Escribe un comentario...',
                        hintStyle: TextStyle(
                          color: AppColors.cream.withOpacity(0.3),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSend(),
                    ),
                  ),
                  GestureDetector(
                    onTap: isSending ? null : onSend,
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.peach, AppColors.peachDark],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: isSending
                          ? const Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}