import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../app/app_theme.dart';
import '../../core/models/user_model.dart';
import '../../core/providers/auth_provider.dart';

// ─── MODELOS LOCALES ──────────────────────────────────────────────────────

class ConversationModel {
  final String id;
  final String otherUserId;
  final String otherUsername;
  final String? otherAvatarUrl;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  const ConversationModel({
    required this.id,
    required this.otherUserId,
    required this.otherUsername,
    this.otherAvatarUrl,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  factory ConversationModel.fromJson(
      Map<String, dynamic> json, String currentUserId) {
    final isParticipantOne = json['participant_one'] == currentUserId;
    final otherUser = isParticipantOne
        ? json['participant_two_user'] as Map<String, dynamic>?
        : json['participant_one_user'] as Map<String, dynamic>?;

    return ConversationModel(
      id: json['id'],
      otherUserId: otherUser?['id'] ?? '',
      otherUsername: otherUser?['username'] ?? 'Usuario',
      otherAvatarUrl: otherUser?['avatar_url'],
      lastMessage: json['last_message'],
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'])
          : null,
    );
  }
}

class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final bool isRead;
  final DateTime createdAt;

  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.isRead,
    required this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'],
      conversationId: json['conversation_id'],
      senderId: json['sender_id'],
      content: json['content'],
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

// ─── PROVIDERS ────────────────────────────────────────────────────────────

final conversationsProvider =
    FutureProvider<List<ConversationModel>>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return [];

  final response = await Supabase.instance.client
      .from('conversations')
      .select('''
        *,
        participant_one_user:users!participant_one(id, username, avatar_url),
        participant_two_user:users!participant_two(id, username, avatar_url)
      ''')
      .or('participant_one.eq.$userId,participant_two.eq.$userId')
      .order('last_message_at', ascending: false);

  return (response as List)
      .map((json) => ConversationModel.fromJson(json, userId))
      .toList();
});

// Provider de mensajes en tiempo real usando Stream
final messagesProvider =
    StreamProvider.family<List<MessageModel>, String>((ref, conversationId) {
  return Supabase.instance.client
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('conversation_id', conversationId)
      .order('created_at')
      .map((data) => data.map(MessageModel.fromJson).toList());
});

// ─── PANTALLA 1: LISTA DE CONVERSACIONES ─────────────────────────────────
class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen>
    with SingleTickerProviderStateMixin {

  final _searchController = TextEditingController();
  String _searchQuery = '';
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
    _searchController.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conversationsAsync = ref.watch(conversationsProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _MessagesHeader(),

              // Buscador
              _SearchBar(
                controller: _searchController,
                onChanged: (q) => setState(() => _searchQuery = q),
              ),

              // Lista de conversaciones
              Expanded(
                child: conversationsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.peach,
                    ),
                  ),
                  error: (e, _) => _EmptyChats(
                    icon: Icons.wifi_off_rounded,
                    message: 'Error cargando mensajes',
                  ),
                  data: (conversations) {
                    final filtered = _searchQuery.isEmpty
                        ? conversations
                        : conversations
                            .where((c) => c.otherUsername
                                .toLowerCase()
                                .contains(_searchQuery.toLowerCase()))
                            .toList();

                    if (filtered.isEmpty) {
                      return _EmptyChats(
                        icon: Icons.chat_bubble_outline_rounded,
                        message: _searchQuery.isEmpty
                            ? 'No tienes mensajes aún'
                            : 'Sin resultados para "$_searchQuery"',
                      );
                    }

                    return ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        color: AppColors.border,
                        indent: 76,
                      ),
                      itemBuilder: (ctx, i) => _ConversationTile(
                        conversation: filtered[i],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              conversation: filtered[i],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── HEADER DE MENSAJES ───────────────────────────────────────────────────
class _MessagesHeader extends StatelessWidget {
  const _MessagesHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
      child: Row(
        children: [
          const Text(
            'Mensajes',
            style: TextStyle(
              fontFamily: 'Playfair Display',
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.cream,
            ),
          ),
          const Spacer(),
          _IconBtn(
            icon: Icons.edit_outlined,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

// ─── BUSCADOR ─────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(
          color: AppColors.cream,
          fontSize: 14,
          fontFamily: 'DM Sans',
        ),
        decoration: InputDecoration(
          hintText: 'Buscar conversación...',
          prefixIcon: Icon(
            Icons.search_rounded,
            color: AppColors.cream.withOpacity(0.3),
            size: 20,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          filled: true,
          fillColor: AppColors.backgroundLight.withOpacity(0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: AppColors.borderFocus,
              width: 1,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── TILE DE CONVERSACIÓN ─────────────────────────────────────────────────
class _ConversationTile extends StatefulWidget {
  final ConversationModel conversation;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conversation,
    required this.onTap,
  });

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile>
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
    _scale = Tween<double>(begin: 1, end: 0.97).animate(
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
    final conv = widget.conversation;

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
          color: Colors.transparent,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          child: Row(
            children: [
              // Avatar
              _ChatAvatar(
                url: conv.otherAvatarUrl,
                letter: conv.otherUsername[0].toUpperCase(),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conv.otherUsername,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: conv.unreadCount > 0
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: AppColors.cream,
                              fontFamily: 'DM Sans',
                            ),
                          ),
                        ),
                        if (conv.lastMessageAt != null)
                          Text(
                            timeago.format(
                              conv.lastMessageAt!,
                              locale: 'es',
                            ),
                            style: TextStyle(
                              fontSize: 11,
                              color: conv.unreadCount > 0
                                  ? AppColors.peach
                                  : AppColors.cream.withOpacity(0.3),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conv.lastMessage ?? 'Inicia una conversación',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: conv.unreadCount > 0
                                  ? AppColors.cream.withOpacity(0.7)
                                  : AppColors.cream.withOpacity(0.35),
                              fontWeight: conv.unreadCount > 0
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (conv.unreadCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.peach,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${conv.unreadCount}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.background,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── PANTALLA 2: CHAT EN TIEMPO REAL ──────────────────────────────────────
class ChatScreen extends ConsumerStatefulWidget {
  final ConversationModel conversation;

  const ChatScreen({super.key, required this.conversation});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {

  final _messageController = TextEditingController();
  final _scrollController  = ScrollController();
  bool _isSending = false;

  String get _currentUserId =>
      Supabase.instance.client.auth.currentUser!.id;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ─── ENVIAR MENSAJE ─────────────────────────────────────────────────
  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    _messageController.clear();
    setState(() => _isSending = true);

    try {
      await Supabase.instance.client.from('messages').insert({
        'conversation_id': widget.conversation.id,
        'sender_id': _currentUserId,
        'content': content,
      });

      // Actualizar el último mensaje de la conversación
      await Supabase.instance.client
          .from('conversations')
          .update({
            'last_message': content,
            'last_message_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.conversation.id);

      // Scroll al final automáticamente
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error enviando mensaje')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(
      messagesProvider(widget.conversation.id),
    );

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: _buildAppBar(),
      body: Column(
        children: [

          // Lista de mensajes
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: AppColors.peach,
                ),
              ),
              error: (e, _) => Center(
                child: Text(
                  'Error cargando mensajes',
                  style: TextStyle(
                    color: AppColors.cream.withOpacity(0.4),
                  ),
                ),
              ),
              data: (messages) {
                if (messages.isEmpty) {
                  return _EmptyChat(
                    username: widget.conversation.otherUsername,
                  );
                }

                // Scroll al final cuando llegan nuevos mensajes
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(
                      _scrollController.position.maxScrollExtent,
                    );
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (ctx, i) {
                    final msg = messages[i];
                    final isMe = msg.senderId == _currentUserId;

                    // Mostrar fecha si hay un salto de día entre mensajes
                    final showDate = i == 0 ||
                        !_isSameDay(
                          messages[i - 1].createdAt,
                          msg.createdAt,
                        );

                    return Column(
                      children: [
                        if (showDate) _DateDivider(date: msg.createdAt),
                        _MessageBubble(
                          message: msg,
                          isMe: isMe,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Input de mensaje
          _MessageInput(
            controller: _messageController,
            isSending: _isSending,
            onSend: _sendMessage,
          ),
        ],
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
      title: Row(
        children: [
          _ChatAvatar(
            url: widget.conversation.otherAvatarUrl,
            letter: widget.conversation.otherUsername[0].toUpperCase(),
            size: 36,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.conversation.otherUsername,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.cream,
                  fontFamily: 'DM Sans',
                ),
              ),
              Text(
                'En línea',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.mint.withOpacity(0.8),
                  fontFamily: 'DM Sans',
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        _IconBtn(icon: Icons.videocam_outlined, onTap: () {}),
        _IconBtn(icon: Icons.call_outlined, onTap: () {}),
      ],
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

// ─── BURBUJA DE MENSAJE ───────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;

  const _MessageBubble({
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) const SizedBox(width: 4),

          // Burbuja
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                gradient: isMe
                    ? const LinearGradient(
                        colors: [AppColors.peach, AppColors.peachDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isMe ? null : AppColors.background,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                border: isMe
                    ? null
                    : Border.all(color: AppColors.border),
                boxShadow: isMe
                    ? [
                        BoxShadow(
                          color: AppColors.peach.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      fontSize: 14,
                      color: isMe
                          ? AppColors.background
                          : AppColors.cream.withOpacity(0.9),
                      height: 1.4,
                      fontFamily: 'DM Sans',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.createdAt),
                        style: TextStyle(
                          fontSize: 10,
                          color: isMe
                              ? AppColors.background.withOpacity(0.6)
                              : AppColors.cream.withOpacity(0.3),
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.isRead
                              ? Icons.done_all_rounded
                              : Icons.done_rounded,
                          size: 12,
                          color: message.isRead
                              ? AppColors.background
                              : AppColors.background.withOpacity(0.5),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ─── SEPARADOR DE FECHA ───────────────────────────────────────────────────
class _DateDivider extends StatelessWidget {
  final DateTime date;
  const _DateDivider({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    String label;

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      label = 'Hoy';
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      label = 'Ayer';
    } else {
      label = '${date.day}/${date.month}/${date.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: AppColors.border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.cream.withOpacity(0.3),
                fontFamily: 'DM Sans',
              ),
            ),
          ),
          Expanded(child: Divider(color: AppColors.border)),
        ],
      ),
    );
  }
}

// ─── INPUT DE MENSAJE ─────────────────────────────────────────────────────
class _MessageInput extends StatefulWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  const _MessageInput({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  @override
  State<_MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<_MessageInput>
    with SingleTickerProviderStateMixin {

  bool _hasText = false;
  late AnimationController _sendCtrl;
  late Animation<double> _sendScale;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() {
      final hasText = widget.controller.text.isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
    _sendCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _sendScale = Tween<double>(begin: 1, end: 0.85).animate(
      CurvedAnimation(parent: _sendCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _sendCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16, 10, 16,
        MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [

          // Campo de texto
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight.withOpacity(0.5),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: widget.controller,
                maxLines: null,
                style: const TextStyle(
                  color: AppColors.cream,
                  fontSize: 14,
                  fontFamily: 'DM Sans',
                ),
                decoration: InputDecoration(
                  hintText: 'Escribe un mensaje...',
                  hintStyle: TextStyle(
                    color: AppColors.cream.withOpacity(0.25),
                    fontSize: 14,
                    fontFamily: 'DM Sans',
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Botón enviar
          GestureDetector(
            onTapDown: (_) {
              if (_hasText) _sendCtrl.forward();
            },
            onTapUp: (_) {
              _sendCtrl.reverse();
              widget.onSend();
            },
            onTapCancel: () => _sendCtrl.reverse(),
            child: ScaleTransition(
              scale: _sendScale,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 48, height: 48,
                decoration: BoxDecoration(
                  gradient: _hasText
                      ? const LinearGradient(
                          colors: [AppColors.peach, AppColors.peachDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: _hasText ? null : AppColors.backgroundLight,
                  shape: BoxShape.circle,
                  boxShadow: _hasText
                      ? [
                          BoxShadow(
                            color: AppColors.peach.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: widget.isSending
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(
                        Icons.send_rounded,
                        color: _hasText
                            ? AppColors.background
                            : AppColors.cream.withOpacity(0.2),
                        size: 20,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── WIDGETS AUXILIARES ───────────────────────────────────────────────────

class _ChatAvatar extends StatelessWidget {
  final String? url;
  final String letter;
  final double size;

  const _ChatAvatar({
    this.url,
    required this.letter,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [AppColors.peach, AppColors.mint],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: url != null
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => Center(
                  child: Text(
                    letter,
                    style: TextStyle(
                      fontSize: size * 0.38,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            )
          : Center(
              child: Text(
                letter,
                style: TextStyle(
                  fontSize: size * 0.38,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontFamily: 'DM Sans',
                ),
              ),
            ),
    );
  }
}

class _IconBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconBtn({required this.icon, required this.onTap});

  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn>
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
          width: 38, height: 38,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(widget.icon, color: AppColors.cream, size: 18),
        ),
      ),
    );
  }
}

class _EmptyChats extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyChats({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: AppColors.cream.withOpacity(0.1)),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 15,
              color: AppColors.cream.withOpacity(0.3),
              fontFamily: 'DM Sans',
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  final String username;
  const _EmptyChat({required this.username});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72, height: 72,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.peach, AppColors.mint],
              ),
            ),
            child: Center(
              child: Text(
                username[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            username,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.cream,
              fontFamily: 'Playfair Display',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Inicia la conversación 👋',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.cream.withOpacity(0.35),
            ),
          ),
        ],
      ),
    );
  }
}