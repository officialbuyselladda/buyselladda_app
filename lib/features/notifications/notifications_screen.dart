import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_service.dart';
import '../../core/constants.dart';
import '../chat/chat_room_screen.dart';
import '../product/product_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  String _typeFilter = 'all';

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<List<Map<String, dynamic>>> _fetch() async {
    final response = await ApiService.get('/notifications', query: {'limit': 50});
    final payload = response.data['data'] ?? response.data;
    final list = payload is List
        ? payload
        : payload is Map
            ? (payload['notifications'] ?? payload['data'] ?? payload['items'] ?? [])
            : [];
    if (list is! List) return [];
    return list.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  Future<void> _refresh() async {
    setState(() => _future = _fetch());
    await _future;
  }

  Future<void> _markAllRead() async {
    try {
      await ApiService.patch('/notifications/read-all');
      await _refresh();
    } catch (_) {
      _showSnack('Could not update notifications');
    }
  }

  Future<void> _markRead(Map<String, dynamic> notification) async {
    final id = '${notification['_id'] ?? notification['id'] ?? ''}';
    if (id.isEmpty || notification['isRead'] == true) return;
    try {
      await ApiService.patch('/notifications/$id/read');
      await _refresh();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton.icon(
            onPressed: _markAllRead,
            icon: const Icon(Icons.done_all_rounded, size: 18),
            label: const Text('Read all'),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            final notifications = snapshot.data ?? [];
            final visible = _filter(notifications);
            final unread = notifications.where((item) => item['isRead'] != true).length;
            return RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: _NotificationSummary(
                        total: notifications.length,
                        unread: unread,
                        selected: _typeFilter,
                        onChanged: (value) => setState(() => _typeFilter = value),
                      ),
                    ),
                  ),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (snapshot.hasError)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _NotificationState(
                        icon: Icons.notifications_off_outlined,
                        title: 'Could not load notifications',
                        message: '${snapshot.error}',
                        action: 'Retry',
                        onPressed: _refresh,
                      ),
                    )
                  else if (notifications.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _NotificationState(
                        icon: Icons.notifications_none_rounded,
                        title: 'No notifications yet',
                        message: 'BuySellAdda updates, ad status alerts, and messages will appear here.',
                        action: 'Refresh',
                        onPressed: _refresh,
                      ),
                    )
                  else if (visible.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _NotificationState(
                        icon: Icons.filter_alt_off_outlined,
                        title: 'No ${_typeLabel(_typeFilter).toLowerCase()} notifications',
                        message: 'Try another filter or pull down to refresh.',
                        action: 'Show all',
                        onPressed: () => setState(() => _typeFilter = 'all'),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      sliver: SliverList.builder(
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final item = visible[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _NotificationTile(
                              notification: item,
                              onTap: () => _handleNotificationTap(item),
                            ),
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

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> items) {
    if (_typeFilter == 'all') return items;
    if (_typeFilter == 'unread') return items.where((item) => item['isRead'] != true).toList();
    return items.where((item) => '${item['type'] ?? 'system'}' == _typeFilter).toList();
  }

  Future<void> _handleNotificationTap(Map<String, dynamic> notification) async {
    await _markRead(notification);
    if (!mounted) return;
    final productId = _relatedProductId(notification);
    if (productId.isNotEmpty) {
      Navigator.pushNamed(context, ProductDetailScreen.routeName, arguments: productId);
      return;
    }
    final chatId = _relatedChatId(notification);
    if (chatId.isNotEmpty) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatRoomScreen(chatId: chatId)));
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _NotificationSummary extends StatelessWidget {
  final int total;
  final int unread;
  final String selected;
  final ValueChanged<String> onChanged;

  const _NotificationSummary({
    required this.total,
    required this.unread,
    required this.selected,
    required this.onChanged,
  });

  static const filters = ['all', 'unread', 'new_message', 'product_status', 'favorite_activity', 'promotion', 'system'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppConstants.borderColor),
        boxShadow: const [BoxShadow(color: Color(0x081E293B), blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppConstants.primaryLightColor, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.notifications_active_outlined, color: AppConstants.primaryDarkColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Notifications', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text('$total total updates', style: const TextStyle(color: AppConstants.textSecondaryColor, fontWeight: FontWeight.w700)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: unread > 0 ? AppConstants.primaryLightColor : AppConstants.backgroundColor,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: unread > 0 ? AppConstants.primaryBorderColor : AppConstants.borderColor),
            ),
            child: Text('$unread unread', style: const TextStyle(color: AppConstants.primaryDarkColor, fontSize: 12, fontWeight: FontWeight.w900)),
          ),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final filter = filters[index];
              final active = selected == filter;
              return ChoiceChip(
                selected: active,
                label: Text(_typeLabel(filter)),
                onSelected: (_) => onChanged(filter),
                selectedColor: AppConstants.primaryLightColor,
                side: BorderSide(color: active ? AppConstants.primaryBorderColor : AppConstants.borderColor),
                labelStyle: TextStyle(
                  color: active ? AppConstants.primaryDarkColor : AppConstants.textSecondaryColor,
                  fontWeight: FontWeight.w900,
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final unread = notification['isRead'] != true;
    final createdAt = DateTime.tryParse('${notification['createdAt'] ?? ''}');
    final title = _brandTitle('${notification['title'] ?? 'BuySellAdda update'}');
    final message = _brandTitle('${notification['message'] ?? ''}');
    final type = '${notification['type'] ?? 'system'}';
    final priority = '${notification['priority'] ?? 'medium'}';
    final product = _asMap(notification['relatedProduct']);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: unread ? AppConstants.primaryLightColor : AppConstants.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: unread ? AppConstants.primaryBorderColor : AppConstants.borderColor),
          boxShadow: const [BoxShadow(color: Color(0x081E293B), blurRadius: 14, offset: Offset(0, 6))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: unread ? AppConstants.primaryColor : AppConstants.secondaryLightColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_iconFor(type), color: unread ? Colors.white : AppConstants.secondaryColor, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      if (createdAt != null)
                        Text(
                          _relativeTime(createdAt),
                          style: const TextStyle(color: AppConstants.textSecondaryColor, fontSize: 12),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    message,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppConstants.textSecondaryColor, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'From BuySellAdda',
                    style: TextStyle(
                      color: unread ? AppConstants.primaryDarkColor : AppConstants.textSubtleColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (product != null) ...[
                    const SizedBox(height: 9),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(unread ? 0.74 : 1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppConstants.borderColor),
                      ),
                      child: Row(children: [
                        const Icon(Icons.inventory_2_outlined, size: 15, color: AppConstants.textSecondaryColor),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${product['title'] ?? 'Related ad'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, size: 18, color: AppConstants.textSubtleColor),
                      ]),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(children: [
              if (unread)
                Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(color: AppConstants.primaryColor, shape: BoxShape.circle),
                ),
              const SizedBox(height: 10),
              if (priority == 'high')
                const Icon(Icons.priority_high_rounded, color: AppConstants.errorColor, size: 18),
            ]),
          ],
        ),
      ),
    );
  }
}

class _NotificationState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String action;
  final VoidCallback onPressed;

  const _NotificationState({
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppConstants.textSecondaryColor),
            const SizedBox(height: 14),
            Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppConstants.textSecondaryColor)),
            const SizedBox(height: 18),
            FilledButton(onPressed: onPressed, child: Text(action)),
          ],
        ),
      ),
    );
  }
}

IconData _iconFor(String type) {
  return switch (type) {
    'new_message' => Icons.chat_bubble_outline_rounded,
    'product_status' => Icons.inventory_2_outlined,
    'favorite_activity' => Icons.favorite_border_rounded,
    'promotion' => Icons.local_offer_outlined,
    _ => Icons.notifications_none_rounded,
  };
}

String _typeLabel(String type) {
  return switch (type) {
    'all' => 'All',
    'unread' => 'Unread',
    'new_message' => 'Messages',
    'product_status' => 'Ads',
    'favorite_activity' => 'Favorites',
    'promotion' => 'Offers',
    'system' => 'System',
    _ => type,
  };
}

String _brandTitle(String value) {
  return value.replaceAll(RegExp(r'\badmin\b', caseSensitive: false), 'BuySellAdda');
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

String _relatedProductId(Map<String, dynamic> notification) {
  final related = _asMap(notification['relatedProduct']);
  final data = _asMap(notification['data']);
  return '${related?['_id'] ?? related?['id'] ?? data?['productId'] ?? notification['productId'] ?? ''}';
}

String _relatedChatId(Map<String, dynamic> notification) {
  final related = _asMap(notification['relatedChat']);
  final data = _asMap(notification['data']);
  return '${related?['_id'] ?? related?['id'] ?? data?['chatId'] ?? notification['chatId'] ?? ''}';
}

String _relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time.toLocal());
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return DateFormat('dd MMM').format(time.toLocal());
}
