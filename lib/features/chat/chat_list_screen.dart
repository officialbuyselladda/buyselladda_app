import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../core/api_service.dart';
import '../../core/auth_provider.dart';
import '../../core/constants.dart';
import 'chat_room_screen.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  late Future<List<Map<String, dynamic>>> _chatsFuture;
  IO.Socket? _socket;
  final Map<String, Map<String, dynamic>> _presence = {};

  @override
  void initState() {
    super.initState();
    _chatsFuture = _fetchChats();
    WidgetsBinding.instance.addPostFrameCallback((_) => _connectSocket());
  }

  @override
  void dispose() {
    _socket?.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchChats() async {
    final response = await ApiService.get(AppConstants.chatPath);
    final payload = response.data['data'] ?? response.data;
    if (payload is! List) return [];
    return payload.map((chat) => Map<String, dynamic>.from(chat as Map)).toList();
  }

  Future<void> _refresh() async {
    setState(() => _chatsFuture = _fetchChats());
    await _chatsFuture;
  }

  void _connectSocket() {
    final userId = ref.read(authProvider).user?.id;
    if (userId == null || userId.isEmpty) return;

    final socket = IO.io(
      _socketBaseUrl(),
      IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .build(),
    );
    _socket = socket;
    socket.onConnect((_) {
      socket.emit('join_user', userId);
      _requestPresence();
    });
    socket.on('chat_updated', (_) {
      if (!mounted) return;
      setState(() => _chatsFuture = _fetchChats());
      _requestPresence();
    });
    socket.on('presence:update', (data) {
      final event = _asMap(data);
      final id = '${event?['userId'] ?? ''}';
      if (id.isEmpty || !mounted) return;
      setState(() {
        _presence[id] = {
          'isOnline': event?['isOnline'] == true,
          'lastSeen': event?['lastSeen'],
        };
      });
    });
    socket.connect();
  }

  Future<void> _requestPresence() async {
    final socket = _socket;
    if (socket == null) return;
    final chats = await _chatsFuture.catchError((_) => <Map<String, dynamic>>[]);
    final currentUserId = ref.read(authProvider).user?.id ?? '';
    final ids = chats
        .map((chat) => _otherUser(chat, currentUserId))
        .whereType<Map<String, dynamic>>()
        .map((user) => '${user['_id'] ?? user['id'] ?? ''}')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) return;
    socket.emitWithAck('presence:get', {'userIds': ids}, ack: (data) {
      final payload = _asMap(data);
      final users = payload?['users'];
      if (users is! List || !mounted) return;
      setState(() {
        for (final item in users) {
          final map = _asMap(item);
          final id = '${map?['userId'] ?? ''}';
          if (id.isNotEmpty) _presence[id] = map!;
        }
      });
    });
  }

  String _socketBaseUrl() {
    final base = ApiService.baseUrl;
    return base.endsWith('/api') ? base.substring(0, base.length - 4) : base;
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      body: SafeArea(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _chatsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _ChatLoading();
            }
            if (snapshot.hasError) {
              return _ChatError(message: '${snapshot.error}', onRetry: _refresh);
            }

            final chats = snapshot.data ?? [];
            return RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _ChatHeader(count: chats.length, unread: _unreadCount(chats))),
                  if (chats.isEmpty)
                    SliverFillRemaining(hasScrollBody: false, child: const _EmptyChats())
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      sliver: SliverList.builder(
                        itemCount: chats.length * 2 - 1,
                        itemBuilder: (context, index) {
                          if (index.isOdd) return const SizedBox(height: 10);
                          final chat = chats[index ~/ 2];
                          return _ChatTile(
                            chat: chat,
                            currentUserId: auth.user?.id ?? '',
                            presence: _presence,
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatRoomScreen(chatId: '${chat['_id'] ?? chat['id']}', initialChat: chat),
                                ),
                              );
                              if (mounted) _refresh();
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  int _unreadCount(List<Map<String, dynamic>> chats) {
    return chats.fold<int>(0, (total, chat) => total + _toInt(chat['unreadCount']));
  }
}

class _ChatHeader extends StatelessWidget {
  final int count;
  final int unread;

  const _ChatHeader({required this.count, required this.unread});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppConstants.borderColor),
          boxShadow: const [BoxShadow(color: Color(0x08111827), blurRadius: 16, offset: Offset(0, 6))],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: AppConstants.primaryLightColor, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.message_outlined, color: AppConstants.primaryDarkColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Messages', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(count == 0 ? 'No conversations yet' : '$count active conversations', style: const TextStyle(color: AppConstants.textSecondaryColor)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(999)),
              child: Text('$unread unread', style: const TextStyle(color: AppConstants.primaryDarkColor, fontWeight: FontWeight.w900, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final Map<String, dynamic> chat;
  final String currentUserId;
  final Map<String, Map<String, dynamic>> presence;
  final VoidCallback onTap;

  const _ChatTile({required this.chat, required this.currentUserId, required this.presence, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final otherUser = _otherUser(chat, currentUserId);
    final product = _asMap(chat['product']);
    final lastMessage = _asMap(chat['lastMessage']);
    final unread = _toInt(chat['unreadCount']);
    final updatedAt = DateTime.tryParse('${lastMessage?['createdAt'] ?? chat['updatedAt'] ?? ''}');
    final avatarUrl = _avatarUrl(otherUser?['avatar']);
    final title = '${otherUser?['name'] ?? 'Seller'}';
    final message = '${lastMessage?['text'] ?? product?['title'] ?? 'Say hello to start the conversation'}';
    final userId = '${otherUser?['_id'] ?? otherUser?['id'] ?? ''}';
    final online = presence[userId]?['isOnline'] == true;
    final lastSeen = DateTime.tryParse('${presence[userId]?['lastSeen'] ?? otherUser?['lastSeen'] ?? ''}');

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: unread > 0 ? AppConstants.primaryLightColor : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: unread > 0 ? AppConstants.primaryBorderColor : AppConstants.borderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 27,
                  backgroundColor: unread > 0 ? AppConstants.primaryColor : const Color(0xFF64748B),
                  backgroundImage: avatarUrl == null ? null : CachedNetworkImageProvider(avatarUrl),
                  child: avatarUrl == null ? Text(title.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)) : null,
                ),
                if (unread > 0)
                  Positioned(
                    right: -3,
                    top: -3,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(color: AppConstants.errorColor, shape: BoxShape.circle),
                      child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                    ),
                  ),
                Positioned(
                  right: 1,
                  bottom: 1,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: online ? AppConstants.successColor : AppConstants.textSubtleColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: unread > 0 ? FontWeight.w900 : FontWeight.w800)),
                      ),
                      if (updatedAt != null)
                        Text(DateFormat('dd MMM').format(updatedAt), style: const TextStyle(color: AppConstants.textSecondaryColor, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(message, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: unread > 0 ? AppConstants.textPrimaryColor : AppConstants.textSecondaryColor, fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(
                    online ? 'Online now' : 'Last seen ${_relativeTime(lastSeen)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppConstants.textSubtleColor, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  if (product != null) ...[
                    const SizedBox(height: 9),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                      decoration: BoxDecoration(color: AppConstants.backgroundColor, borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.inventory_2_outlined, size: 14, color: AppConstants.textSecondaryColor),
                          const SizedBox(width: 5),
                          Flexible(child: Text('${product['title'] ?? 'Ad'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                          if (_toNum(product['price']) != null) ...[
                            const SizedBox(width: 8),
                            Text('Rs ${NumberFormat.decimalPattern('en_IN').format(_toNum(product['price']))}', style: const TextStyle(fontSize: 12, color: AppConstants.primaryDarkColor, fontWeight: FontWeight.w900)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: AppConstants.textSecondaryColor),
          ],
        ),
      ),
    );
  }
}

class _ChatLoading extends StatelessWidget {
  const _ChatLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _ChatError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ChatError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline, size: 62, color: AppConstants.errorColor),
            const SizedBox(height: 12),
            const Text('Could not load chats', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppConstants.textSecondaryColor)),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _EmptyChats extends StatelessWidget {
  const _EmptyChats();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(color: AppConstants.primaryLightColor, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.forum_outlined, size: 42, color: AppConstants.primaryDarkColor),
            ),
            const SizedBox(height: 16),
            Text('No messages yet', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text('Contact a seller from any ad to start chatting.', textAlign: TextAlign.center, style: TextStyle(color: AppConstants.textSecondaryColor)),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
              icon: const Icon(Icons.storefront_outlined),
              label: const Text('Browse ads'),
            ),
          ],
        ),
      ),
    );
  }
}

Map<String, dynamic>? _otherUser(Map<String, dynamic> chat, String currentUserId) {
  final users = (chat['users'] as List?) ?? (chat['participants'] as List?) ?? [];
  for (final user in users) {
    final map = _asMap(user);
    if (map != null && '${map['_id'] ?? map['id']}' != currentUserId) return map;
  }
  return users.isNotEmpty ? _asMap(users.first) : null;
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

String? _avatarUrl(dynamic avatar) {
  if (avatar is String && avatar.isNotEmpty) return avatar;
  if (avatar is Map && avatar['url'] != null) return '${avatar['url']}';
  return null;
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

num? _toNum(dynamic value) {
  if (value is num) return value;
  return num.tryParse('$value');
}

String _relativeTime(DateTime? time) {
  if (time == null) return 'recently';
  final diff = DateTime.now().difference(time.toLocal());
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('dd MMM').format(time.toLocal());
}
