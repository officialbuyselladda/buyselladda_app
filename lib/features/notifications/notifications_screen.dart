import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_service.dart';
import '../../core/constants.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<List<Map<String, dynamic>>> _fetch() async {
    final response = await ApiService.get('/notifications', query: {'limit': 50});
    final payload = response.data['data'] ?? response.data;
    final list = payload is List ? payload : (payload['notifications'] ?? []);
    return (list as List).map((item) => Map<String, dynamic>.from(item as Map)).toList();
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
            return RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                slivers: [
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
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      sliver: SliverList.builder(
                        itemCount: notifications.length,
                        itemBuilder: (context, index) {
                          final item = notifications[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _NotificationTile(
                              notification: item,
                              onTap: () => _markRead(item),
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

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: unread ? AppConstants.primaryLightColor : AppConstants.surfaceColor,
          borderRadius: BorderRadius.circular(8),
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
                borderRadius: BorderRadius.circular(8),
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
                          DateFormat('dd MMM').format(createdAt),
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
                ],
              ),
            ),
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

String _brandTitle(String value) {
  return value.replaceAll(RegExp(r'\badmin\b', caseSensitive: false), 'BuySellAdda');
}
