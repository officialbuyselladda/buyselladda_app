import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../core/api_service.dart';
import '../../core/auth_provider.dart';
import '../../core/constants.dart';

class ChatRoomScreen extends ConsumerStatefulWidget {
  final String chatId;
  final Map<String, dynamic>? initialChat;

  const ChatRoomScreen({super.key, required this.chatId, this.initialChat});

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  IO.Socket? _socket;
  Timer? _typingTimer;
  Map<String, dynamic>? _chat;
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _otherTyping = false;
  bool _otherOnline = false;
  DateTime? _otherLastSeen;
  String? _error;

  @override
  void initState() {
    super.initState();
    _chat = widget.initialChat;
    _messageController.addListener(_handleTypingChanged);
    _loadMessages();
    WidgetsBinding.instance.addPostFrameCallback((_) => _connectSocket());
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _emitTyping(false);
    _socket?.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(authProvider).user?.id ?? '';
    final otherUser = _otherUser(_chat, currentUserId);
    final product = _asMap(_chat?['product']);

    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _RoomHeader(
              otherUser: otherUser,
              product: product,
              online: _otherOnline,
              lastSeen: _otherLastSeen ?? DateTime.tryParse('${otherUser?['lastSeen'] ?? ''}'),
              typing: _otherTyping,
              onBack: () => Navigator.pop(context),
              onProfile: () => _showProfileSheet(otherUser, product),
            ),
            if (product != null) _ProductStrip(product: product),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _RoomError(message: _error!, onRetry: _loadMessages)
                      : _MessageList(
                          messages: _messages,
                          currentUserId: currentUserId,
                          scrollController: _scrollController,
                          otherTyping: _otherTyping,
                          watermark: 'BuySellAdda',
                        ),
            ),
            _Composer(
              controller: _messageController,
              sending: _sending,
              onSend: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadMessages() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ApiService.get('${AppConstants.chatPath}/${widget.chatId}/messages');
      final payload = _asMap(response.data['data'] ?? response.data);
      final chat = _asMap(payload?['chat']);
      final rawMessages = payload?['messages'];
      final messageList = rawMessages is List ? rawMessages : const [];
      final messages = messageList.whereType<Map>().map((message) => Map<String, dynamic>.from(message)).toList();
      if (!mounted) return;
      setState(() {
        _chat = chat ?? _chat;
        _messages = _mergeMessageLists(messages, _messages);
        _loading = false;
      });
      _requestPresence();
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;
    final auth = ref.read(authProvider);
    final tempId = 'temp-${DateTime.now().microsecondsSinceEpoch}';
    final temp = {
      '_id': tempId,
      'chat': widget.chatId,
      'sender': {
        '_id': auth.user?.id ?? '',
        'name': auth.user?.name ?? 'You',
        'avatar': auth.user?.avatar,
      },
      'text': text,
      'pending': true,
      'createdAt': DateTime.now().toIso8601String(),
    };

    setState(() {
      _messageController.clear();
      _sending = true;
      _messages = [..._messages, temp];
    });
    _scrollToBottom();

    try {
      final response = await ApiService.post('${AppConstants.chatPath}/${widget.chatId}/send', data: {'text': text});
      final payload = response.data['data'] ?? response.data;
      final savedPayload = _asMap(payload);
      final saved = _asMap(savedPayload?['message']) ?? savedPayload;
      if (saved == null) {
        throw Exception('Invalid message response');
      }
      if (!mounted) return;
      setState(() {
        _messages = _mergeSavedMessage(_messages, tempId, saved);
        _sending = false;
      });
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages = _messages.where((message) => message['_id'] != tempId).toList();
        _sending = false;
      });
      _showSnack('Message could not be sent. Please try again.');
    }
  }

  void _connectSocket() {
    final userId = ref.read(authProvider).user?.id;
    if (userId == null || userId.isEmpty || widget.chatId.isEmpty) return;

    final socket = IO.io(
      _socketBaseUrl(),
      IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .build(),
    );
    _socket = socket;

    socket.onConnect((_) {
      socket.emit('joinChat', widget.chatId);
      socket.emit('join_user', userId);
      _requestPresence();
    });
    socket.on('receive_message', _handleSocketMessage);
    socket.on('message', _handleSocketMessage);
    socket.on('typing:update', (data) {
      final event = _asMap(data);
      if (event?['chatId'] != widget.chatId || '${event?['userId']}' == userId) return;
      if (!mounted) return;
      setState(() => _otherTyping = event?['isTyping'] == true);
    });
    socket.on('presence:update', (data) {
      final event = _asMap(data);
      final otherUserId = _otherUserId(userId);
      if (otherUserId.isEmpty || '${event?['userId'] ?? ''}' != otherUserId || !mounted) return;
      setState(() {
        _otherOnline = event?['isOnline'] == true;
        _otherLastSeen = DateTime.tryParse('${event?['lastSeen'] ?? ''}');
      });
    });
    socket.connect();
  }

  void _requestPresence() {
    final socket = _socket;
    final currentUserId = ref.read(authProvider).user?.id ?? '';
    final otherUserId = _otherUserId(currentUserId);
    if (socket == null || otherUserId.isEmpty) return;
    socket.emitWithAck('presence:get', {'userIds': [otherUserId]}, ack: (data) {
      final payload = _asMap(data);
      final users = payload?['users'];
      if (users is! List || users.isEmpty || !mounted) return;
      final user = _asMap(users.first);
      setState(() {
        _otherOnline = user?['isOnline'] == true;
        _otherLastSeen = DateTime.tryParse('${user?['lastSeen'] ?? ''}');
      });
    });
  }

  String _otherUserId(String currentUserId) {
    final other = _otherUser(_chat, currentUserId);
    return '${other?['_id'] ?? other?['id'] ?? ''}';
  }

  void _handleSocketMessage(dynamic data) {
    final incoming = _asMap(data);
    if (incoming == null || !_sameChat(incoming, widget.chatId)) return;
    if (!mounted) return;
    setState(() {
      _otherTyping = false;
      _messages = _appendUniqueMessage(_messages, incoming);
    });
    _scrollToBottom();
  }

  void _handleTypingChanged() {
    if (_messageController.text.trim().isEmpty) {
      _emitTyping(false);
      return;
    }
    _emitTyping(true);
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(milliseconds: 900), () => _emitTyping(false));
  }

  void _emitTyping(bool typing) {
    final userId = ref.read(authProvider).user?.id;
    final socket = _socket;
    if (socket == null || userId == null || userId.isEmpty) return;
    socket.emit(typing ? 'typing:start' : 'typing:stop', {'chatId': widget.chatId, 'userId': userId});
  }

  String _socketBaseUrl() {
    final base = ApiService.baseUrl;
    return base.endsWith('/api') ? base.substring(0, base.length - 4) : base;
  }

  List<Map<String, dynamic>> _appendUniqueMessage(List<Map<String, dynamic>> current, Map<String, dynamic> incoming) {
    final id = '${incoming['_id'] ?? incoming['id'] ?? ''}';
    final clientTempId = '${incoming['clientTempId'] ?? ''}';
    final withoutTemp = clientTempId.isEmpty ? current : current.where((message) => message['_id'] != clientTempId).toList();
    if (id.isNotEmpty && withoutTemp.any((message) => '${message['_id'] ?? message['id']}' == id)) {
      return withoutTemp;
    }
    return [...withoutTemp, incoming];
  }

  bool _sameChat(Map<String, dynamic> message, String chatId) {
    final raw = message['chat'] ?? message['chatId'];
    if (raw == null) return true;
    if (raw is Map) return '${raw['_id'] ?? raw['id'] ?? ''}' == chatId;
    return '$raw' == chatId;
  }

  List<Map<String, dynamic>> _mergeSavedMessage(List<Map<String, dynamic>> current, String tempId, Map<String, dynamic> saved) {
    final savedId = '${saved['_id'] ?? saved['id'] ?? ''}';
    final withoutTemp = current.where((message) => message['_id'] != tempId).toList();
    if (savedId.isNotEmpty && withoutTemp.any((message) => '${message['_id'] ?? message['id']}' == savedId)) {
      return withoutTemp;
    }
    return [...withoutTemp, saved];
  }

  List<Map<String, dynamic>> _mergeMessageLists(List<Map<String, dynamic>> fresh, List<Map<String, dynamic>> existing) {
    final merged = [...fresh];
    for (final message in existing) {
      final id = '${message['_id'] ?? message['id'] ?? ''}';
      if (id.startsWith('temp-')) {
        merged.add(message);
        continue;
      }
      if (id.isNotEmpty && merged.any((item) => '${item['_id'] ?? item['id']}' == id)) {
        continue;
      }
      merged.add(message);
    }
    merged.sort((a, b) {
      final aTime = DateTime.tryParse('${a['createdAt'] ?? a['timestamp'] ?? ''}') ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = DateTime.tryParse('${b['createdAt'] ?? b['timestamp'] ?? ''}') ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aTime.compareTo(bTime);
    });
    return merged;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _showProfileSheet(Map<String, dynamic>? user, Map<String, dynamic>? product) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Avatar(user: user, radius: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${user?['name'] ?? 'User'}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      const Text('Verified BuySellAdda profile', style: TextStyle(color: AppConstants.primaryDarkColor, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (user?['email'] != null) _InfoLine(icon: Icons.email_outlined, text: '${user!['email']}'),
            if (product != null) _InfoLine(icon: Icons.inventory_2_outlined, text: '${product['title'] ?? 'Ad discussion'}'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showSnack('Report submitted to support review.');
                    },
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text('Report'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _RoomHeader extends StatelessWidget {
  final Map<String, dynamic>? otherUser;
  final Map<String, dynamic>? product;
  final bool online;
  final DateTime? lastSeen;
  final bool typing;
  final VoidCallback onBack;
  final VoidCallback onProfile;

  const _RoomHeader({
    required this.otherUser,
    required this.product,
    required this.online,
    required this.lastSeen,
    required this.typing,
    required this.onBack,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 8, 12, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppConstants.borderColor)),
        boxShadow: [BoxShadow(color: Color(0x08111827), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded)),
          InkWell(borderRadius: BorderRadius.circular(8), onTap: onProfile, child: _Avatar(user: otherUser, radius: 24)),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: onProfile,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${otherUser?['name'] ?? 'User'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  Row(
                    children: [
                      Icon(Icons.circle, size: 8, color: online ? AppConstants.successColor : AppConstants.textSubtleColor),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          typing ? 'typing...' : online ? 'Online now' : 'Last seen ${_relativeTime(lastSeen)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: typing || online ? AppConstants.successColor : AppConstants.textSecondaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          IconButton(onPressed: onProfile, icon: const Icon(Icons.more_vert_rounded)),
        ],
      ),
    );
  }
}

class _ProductStrip extends StatelessWidget {
  final Map<String, dynamic> product;

  const _ProductStrip({required this.product});

  @override
  Widget build(BuildContext context) {
    final image = _firstProductImage(product['images']);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppConstants.borderColor),
        boxShadow: const [BoxShadow(color: Color(0x07111827), blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: AppConstants.backgroundColor, borderRadius: BorderRadius.circular(8)),
            clipBehavior: Clip.antiAlias,
            child: image == null
                ? const Icon(Icons.image_not_supported_outlined, color: AppConstants.textSubtleColor)
                : CachedNetworkImage(
                    imageUrl: image,
                    fit: BoxFit.cover,
                    placeholder: (context, _) => Container(color: AppConstants.backgroundColor),
                    errorWidget: (context, _, __) => const Icon(Icons.image_not_supported_outlined, color: AppConstants.textSubtleColor),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${product['title'] ?? 'Ad'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                if (_toNum(product['price']) != null)
                  Text('Rs ${NumberFormat.decimalPattern('en_IN').format(_toNum(product['price']))}', style: const TextStyle(color: AppConstants.primaryDarkColor, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          const Icon(Icons.inventory_2_outlined, color: AppConstants.textSecondaryColor),
        ],
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  final List<Map<String, dynamic>> messages;
  final String currentUserId;
  final ScrollController scrollController;
  final bool otherTyping;
  final String watermark;

  const _MessageList({
    required this.messages,
    required this.currentUserId,
    required this.scrollController,
    required this.otherTyping,
    required this.watermark,
  });

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.waving_hand_outlined, size: 54, color: AppConstants.textSecondaryColor),
              SizedBox(height: 12),
              Text('Start the conversation', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              SizedBox(height: 6),
              Text('Ask about price, pickup, condition, or availability.', textAlign: TextAlign.center, style: TextStyle(color: AppConstants.textSecondaryColor)),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        Center(
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.045,
              child: RotatedBox(
                quarterTurns: 3,
                child: Text(watermark, style: const TextStyle(fontSize: 46, fontWeight: FontWeight.w900, color: AppConstants.textPrimaryColor)),
              ),
            ),
          ),
        ),
        ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          itemCount: messages.length + (otherTyping ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == messages.length) {
              return const _TypingBubble();
            }
            final message = messages[index];
            final sender = _asMap(message['sender']);
            final own = '${sender?['_id'] ?? message['sender']}' == currentUserId;
            final createdAt = DateTime.tryParse('${message['createdAt'] ?? message['timestamp'] ?? ''}');
            final previousTime = index == 0 ? null : DateTime.tryParse('${messages[index - 1]['createdAt'] ?? messages[index - 1]['timestamp'] ?? ''}');
            final showDate = _shouldShowDateDivider(previousTime, createdAt);
            return Column(
              children: [
                if (showDate) _DateDivider(date: createdAt ?? DateTime.now()),
                _MessageBubble(
                  text: '${message['text'] ?? ''}',
                  own: own,
                  pending: message['pending'] == true,
                  time: createdAt == null ? '' : DateFormat('hh:mm a').format(createdAt.toLocal()),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _DateDivider extends StatelessWidget {
  final DateTime date;

  const _DateDivider({required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999), border: Border.all(color: AppConstants.borderColor)),
          child: Text(_dateLabel(date), style: const TextStyle(color: AppConstants.textSecondaryColor, fontSize: 11, fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final bool own;
  final bool pending;
  final String time;

  const _MessageBubble({required this.text, required this.own, required this.pending, required this.time});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: own ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.76),
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 7),
        decoration: BoxDecoration(
          color: own ? AppConstants.primaryColor : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(own ? 8 : 2),
            bottomRight: Radius.circular(own ? 2 : 8),
          ),
          border: own ? null : Border.all(color: AppConstants.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(text, style: TextStyle(color: own ? Colors.white : AppConstants.textPrimaryColor, height: 1.38, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(time, style: TextStyle(color: own ? Colors.white70 : AppConstants.textSecondaryColor, fontSize: 10)),
                if (own) ...[
                  const SizedBox(width: 4),
                  Icon(pending ? Icons.schedule_rounded : Icons.done_all_rounded, size: 13, color: Colors.white70),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8),
            topRight: Radius.circular(8),
            bottomLeft: Radius.circular(2),
            bottomRight: Radius.circular(8),
          ),
          border: Border.all(color: AppConstants.borderColor),
        ),
        child: const Text(
          'typing...',
          style: TextStyle(color: AppConstants.textSecondaryColor, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  const _Composer({required this.controller, required this.sending, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppConstants.borderColor))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) {
                  if (controller.text.trim().isNotEmpty && !sending) onSend();
                },
                decoration: const InputDecoration(
                  hintText: 'Type your message...',
                  prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                final canSend = value.text.trim().isNotEmpty && !sending;
                return SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton.filled(
                    tooltip: 'Send',
                    onPressed: canSend ? onSend : null,
                    icon: sending
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded),
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

class _RoomError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _RoomError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 58, color: AppConstants.errorColor),
            const SizedBox(height: 10),
            const Text('Could not load messages', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppConstants.textSecondaryColor)),
            const SizedBox(height: 14),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final Map<String, dynamic>? user;
  final double radius;

  const _Avatar({required this.user, required this.radius});

  @override
  Widget build(BuildContext context) {
    final name = '${user?['name'] ?? 'U'}';
    final avatar = _avatarUrl(user?['avatar']);
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppConstants.primaryDarkColor,
      backgroundImage: avatar == null ? null : CachedNetworkImageProvider(avatar),
      child: avatar == null ? Text(name.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)) : null,
    );
  }
}

bool _shouldShowDateDivider(DateTime? previous, DateTime? current) {
  if (current == null) return previous == null;
  if (previous == null) return true;
  final a = previous.toLocal();
  final b = current.toLocal();
  return a.year != b.year || a.month != b.month || a.day != b.day;
}

String _dateLabel(DateTime date) {
  final now = DateTime.now();
  final local = date.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return DateFormat('dd MMM yyyy').format(local);
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

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppConstants.textSecondaryColor),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

Map<String, dynamic>? _otherUser(Map<String, dynamic>? chat, String currentUserId) {
  final users = (chat?['users'] as List?) ?? (chat?['participants'] as List?) ?? [];
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

String? _firstProductImage(dynamic images) {
  if (images is! List || images.isEmpty) return null;
  final first = images.first;
  if (first is String && first.isNotEmpty) return first;
  if (first is Map && first['url'] != null) return '${first['url']}';
  return null;
}

num? _toNum(dynamic value) {
  if (value is num) return value;
  return num.tryParse('$value');
}
