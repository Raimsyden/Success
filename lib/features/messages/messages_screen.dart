import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../app/app_theme.dart';
import '../../core/providers/auth_provider.dart';
import '../feed/feed_screen.dart' show Avatar;

// ─── MODELOS ──────────────────────────────────────────────────────────────
class ConversationModel {
  final String id;
  final String participantOne;
  final String participantTwo;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final DateTime createdAt;
  // Datos del otro participante
  final String? otherUsername;
  final String? otherAvatarUrl;
  final String? otherUserId;

  const ConversationModel({
    required this.id,
    required this.participantOne,
    required this.participantTwo,
    this.lastMessage,
    this.lastMessageAt,
    required this.createdAt,
    this.otherUsername,
    this.otherAvatarUrl,
    this.otherUserId,
  });
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
        user_one:users!conversations_participant_one_fkey(id, username, avatar_url),
        user_two:users!conversations_participant_two_fkey(id, username, avatar_url)
      ''')
      .or('participant_one.eq.$userId,participant_two.eq.$userId')
      .order('last_message_at', ascending: false, nullsFirst: false);

  return (response as List).map((json) {
    final isOne = json['participant_one'] == userId;
    final other = isOne
        ? json['user_two'] as Map<String, dynamic>?
        : json['user_one'] as Map<String, dynamic>?;

    return ConversationModel(
      id: json['id'],
      participantOne: json['participant_one'],
      participantTwo: json['participant_two'],
      lastMessage: json['last_message'],
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
      otherUserId: other?['id'],
      otherUsername: other?['username'],
      otherAvatarUrl: other?['avatar_url'],
    );
  }).toList();
});

final messagesProvider =
    StreamProvider.family<List<MessageModel>, String>((ref, conversationId) {
  return Supabase.instance.client
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('conversation_id', conversationId)
      .order('created_at', ascending: true)
      .map((data) => data.map((json) => MessageModel.fromJson(json)).toList());
});

// ─── PANTALLA DE CONVERSACIONES ───────────────────────────────────────────
class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.cream,
        title: const Text(
          'Mensajes',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontSize: 20,
            fontWeight: FontWeight.w700,
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
      body: conversationsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.peach, strokeWidth: 2),
        ),
        error: (e, _) => Center(
          child: Text(
            'Error cargando mensajes',
            style: TextStyle(color: AppColors.cream.withOpacity(0.4)),
          ),
        ),
        data: (conversations) {
          if (conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 56,
                    color: AppColors.cream.withOpacity(0.15),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No tienes conversaciones aún',
                    style: TextStyle(
                      color: AppColors.cream.withOpacity(0.4),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ve al perfil de alguien y envíale un mensaje',
                    style: TextStyle(
                      color: AppColors.cream.withOpacity(0.25),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: AppColors.peach,
            backgroundColor: AppColors.backgroundCard,
            onRefresh: () => ref.refresh(conversationsProvider.future),
            child: ListView.separated(
              itemCount: conversations.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: AppColors.border, indent: 72),
              itemBuilder: (_, i) => _ConversationTile(
                conversation: conversations[i],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ChatScreen(conversation: conversations[i]),
                    ),
                  ).then((_) => ref.refresh(conversationsProvider.future));
                },
              ),
            ),
          );
        },
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
          color: AppColors.backgroundDeep,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Avatar(
                url: conv.otherAvatarUrl,
                letter: (conv.otherUsername ?? 'U')[0].toUpperCase(),
                size: 48,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          conv.otherUsername ?? 'Usuario',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.cream,
                            fontFamily: 'DM Sans',
                          ),
                        ),
                        if (conv.lastMessageAt != null)
                          Text(
                            timeago.format(conv.lastMessageAt!, locale: 'es'),
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.cream.withOpacity(0.35),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      conv.lastMessage ?? 'Inicia la conversación',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.cream.withOpacity(
                          conv.lastMessage != null ? 0.5 : 0.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.mint,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── PANTALLA DE CHAT ─────────────────────────────────────────────────────
class ChatScreen extends ConsumerStatefulWidget {
  final ConversationModel conversation;

  const ChatScreen({super.key, required this.conversation});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

  String get _currentUserId =>
      Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _controller.clear();

    try {
      // Insertar mensaje
      await Supabase.instance.client.from('messages').insert({
        'conversation_id': widget.conversation.id,
        'sender_id': _currentUserId,
        'content': text,
        'is_read': false,
      });

      // Actualizar último mensaje en la conversación
      await Supabase.instance.client
          .from('conversations')
          .update({
            'last_message': text,
            'last_message_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.conversation.id);

      _scrollToBottom();
    } catch (e) {
      debugPrint('[Chat] error enviando: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync =
        ref.watch(messagesProvider(widget.conversation.id));

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.cream,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Avatar(
              url: widget.conversation.otherAvatarUrl,
              letter:
                  (widget.conversation.otherUsername ?? 'U')[0].toUpperCase(),
              size: 34,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.conversation.otherUsername ?? 'Usuario',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.cream,
                    fontFamily: 'DM Sans',
                  ),
                ),
                Text(
                  'En línea',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.mint.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: Column(
        children: [
          // Lista de mensajes
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                    color: AppColors.peach, strokeWidth: 2),
              ),
              error: (e, _) => Center(
                child: Text('Error cargando mensajes',
                    style:
                        TextStyle(color: AppColors.cream.withOpacity(0.4))),
              ),
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.waving_hand_rounded,
                          size: 48,
                          color: AppColors.cream.withOpacity(0.15),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Saluda a ${widget.conversation.otherUsername}',
                          style: TextStyle(
                            color: AppColors.cream.withOpacity(0.3),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                _scrollToBottom();

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 16),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final msg = messages[i];
                    final isMe = msg.senderId == _currentUserId;
                    final showDate = i == 0 ||
                        messages[i].createdAt.day !=
                            messages[i - 1].createdAt.day;

                    return Column(
                      children: [
                        if (showDate) _DateDivider(date: msg.createdAt),
                        _MessageBubble(message: msg, isMe: isMe),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Input de mensaje
          Divider(height: 1, color: AppColors.border),
          _MessageInput(
            controller: _controller,
            isSending: _isSending,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}

// ─── BURBUJA DE MENSAJE ───────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 4,
          bottom: 4,
          left: isMe ? 64 : 0,
          right: isMe ? 0 : 64,
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: isMe
              ? const LinearGradient(
                  colors: [AppColors.peach, AppColors.peachDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isMe ? null : AppColors.backgroundLight,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          border: isMe
              ? null
              : Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: TextStyle(
                fontSize: 14,
                color: isMe ? AppColors.background : AppColors.cream,
                height: 1.4,
                fontFamily: 'DM Sans',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 10,
                color: isMe
                    ? AppColors.background.withOpacity(0.6)
                    : AppColors.cream.withOpacity(0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── SEPARADOR DE FECHA ───────────────────────────────────────────────────
class _DateDivider extends StatelessWidget {
  final DateTime date;
  const _DateDivider({required this.date});

  String _formatDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDate = DateTime(date.year, date.month, date.day);
    final diff = today.difference(msgDate).inDays;

    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Ayer';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: AppColors.border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _formatDate(),
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
class _MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  const _MessageInput({
    required this.controller,
    required this.isSending,
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
                        hintText: 'Escribe un mensaje...',
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
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: isSending ? null : onSend,
            child: Container(
              width: 44, height: 44,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.peach, AppColors.peachDark],
                ),
                shape: BoxShape.circle,
              ),
              child: isSending
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}