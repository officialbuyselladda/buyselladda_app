import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/app_language.dart';
import '../../core/api_service.dart';
import '../../core/auth_provider.dart';
import '../../core/constants.dart';
import '../../models/user_model.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late Future<Map<String, dynamic>?> _postingEligibilityFuture;
  late Future<Map<String, dynamic>> _profileStatsFuture;

  @override
  void initState() {
    super.initState();
    _postingEligibilityFuture = _fetchPostingEligibility();
    _profileStatsFuture = _fetchProfileStats();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final language = ref.watch(appLanguageProvider);

    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: Text(tr(language, 'account')),
        backgroundColor: AppConstants.backgroundColor,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshProfileData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
          _ProfileHero(
            user: user,
            onEdit: () => Navigator.pushNamed(context, '/edit-profile'),
          ),
          const SizedBox(height: 14),
          FutureBuilder<Map<String, dynamic>>(
            future: _profileStatsFuture,
            builder: (context, snapshot) => _ProfileStatsGrid(
              stats: snapshot.data,
              isLoading: snapshot.connectionState == ConnectionState.waiting,
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<Map<String, dynamic>?>(
            future: _postingEligibilityFuture,
            builder: (context, snapshot) {
              return _PostingQuotaCard(
                eligibility: snapshot.data,
                isLoading: snapshot.connectionState == ConnectionState.waiting,
                onPostAd: () => Navigator.pushNamed(context, '/create-product'),
              );
            },
          ),
          const SizedBox(height: 16),
          _SettingsGroup(
            title: tr(language, 'profile'),
            children: [
              _SettingsTile(
                icon: Icons.person_outline_rounded,
                title: tr(language, 'view_edit_profile'),
                subtitle: user?.phone == null ? tr(language, 'add_phone_location') : user!.phone!,
                onTap: () => Navigator.pushNamed(context, '/edit-profile'),
              ),
              _SettingsTile(
                icon: Icons.favorite_border_rounded,
                title: tr(language, 'wishlist'),
                subtitle: tr(language, 'wishlist_subtitle'),
                onTap: () => Navigator.pushNamed(context, '/favorites'),
              ),
              _SettingsTile(
                icon: Icons.inventory_2_outlined,
                title: tr(language, 'my_ads'),
                subtitle: tr(language, 'my_ads_subtitle'),
                onTap: () => Navigator.pushNamed(context, '/my-ads'),
              ),
              _SettingsTile(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Messages',
                subtitle: 'Manage buyer and seller conversations',
                onTap: () => Navigator.pushNamed(context, '/chat'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SettingsGroup(
            title: tr(language, 'settings'),
            children: [
              _SettingsTile(
                icon: Icons.privacy_tip_outlined,
                title: tr(language, 'privacy'),
                subtitle: tr(language, 'privacy_subtitle'),
                onTap: () => Navigator.pushNamed(context, '/privacy'),
              ),
              _SettingsTile(
                icon: Icons.lock_reset_rounded,
                title: 'Change password',
                subtitle: 'Update your account password securely',
                onTap: () => Navigator.pushNamed(context, '/change-password'),
              ),
              _SettingsTile(
                icon: Icons.language_rounded,
                title: tr(language, 'select_language'),
                subtitle: language,
                onTap: () => Navigator.pushNamed(context, '/language'),
              ),
              _SettingsTile(
                icon: Icons.help_outline_rounded,
                title: tr(language, 'help_support'),
                subtitle: tr(language, 'help_subtitle'),
                onTap: () => Navigator.pushNamed(context, '/help-support'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SettingsGroup(
            title: tr(language, 'session'),
            children: [
              _SettingsTile(
                icon: Icons.logout_rounded,
                title: tr(language, 'logout'),
                subtitle: tr(language, 'logout_subtitle'),
                danger: true,
                onTap: _logout,
              ),
            ],
          ),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshProfileData() async {
    setState(() {
      _postingEligibilityFuture = _fetchPostingEligibility();
      _profileStatsFuture = _fetchProfileStats();
    });
    await Future.wait([
      _postingEligibilityFuture,
      _profileStatsFuture,
    ]);
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (!mounted) return;
    Navigator.popUntil(context, (route) => route.isFirst);
    _showSnack('Logged out successfully');
  }

  Future<Map<String, dynamic>?> _fetchPostingEligibility() async {
    try {
      final response = await ApiService.get('${AppConstants.productPath}/posting-eligibility');
      final payload = response.data;
      final data = payload is Map ? (payload['data'] ?? payload) : null;
      if (data is Map) return Map<String, dynamic>.from(data);
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<Map<String, dynamic>> _fetchProfileStats() async {
    try {
      final response = await ApiService.get('${AppConstants.userPath}/profile-stats');
      final payload = response.data;
      final data = payload is Map ? (payload['data'] ?? payload) : null;
      if (data is Map) return Map<String, dynamic>.from(data);
    } catch (_) {}
    return const {};
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ProfileHero extends StatelessWidget {
  final User? user;
  final VoidCallback onEdit;

  const _ProfileHero({required this.user, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final name = '${user?.name ?? ''}'.trim().isNotEmpty ? '${user?.name}' : 'BuySellAdda User';
    final email = '${user?.email ?? ''}'.trim();
    final phone = '${user?.phone ?? ''}'.trim();
    final location = '${user?.location ?? ''}'.trim();
    final joined = user?.createdAt;
    final avatar = '${user?.avatar ?? ''}'.trim();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppConstants.borderColor),
        boxShadow: const [BoxShadow(color: Color(0x0A1E293B), blurRadius: 20, offset: Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppConstants.primaryBorderColor, width: 2),
              ),
              child: CircleAvatar(
                radius: 36,
                backgroundColor: AppConstants.primaryLightColor,
                backgroundImage: avatar.isEmpty ? null : NetworkImage(avatar),
                child: avatar.isEmpty ? Text(name.substring(0, 1).toUpperCase(), style: const TextStyle(color: AppConstants.primaryDarkColor, fontSize: 28, fontWeight: FontWeight.w900)) : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Edit profile',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                  ),
                ]),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(email, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppConstants.textSecondaryColor, fontWeight: FontWeight.w700)),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ProfileChip(
                      icon: user?.isEmailVerified == true ? Icons.verified_rounded : Icons.mark_email_unread_outlined,
                      label: user?.isEmailVerified == true ? 'Email verified' : 'Verify email',
                      color: user?.isEmailVerified == true ? AppConstants.successColor : AppConstants.warningColor,
                    ),
                    if (phone.isNotEmpty) _ProfileChip(icon: Icons.call_outlined, label: phone, color: AppConstants.secondaryColor),
                    if (location.isNotEmpty) _ProfileChip(icon: Icons.place_outlined, label: location, color: AppConstants.primaryDarkColor),
                  ],
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppConstants.backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppConstants.borderColor),
            ),
            child: Row(children: [
              Expanded(
                child: _HeroMeta(
                  label: 'Member since',
                  value: joined == null ? 'Not available' : DateFormat('MMM yyyy').format(joined.toLocal()),
                ),
              ),
              Container(width: 1, height: 34, color: AppConstants.borderColor),
              Expanded(
                child: _HeroMeta(
                  label: 'Trust score',
                  value: '${user?.trustScore ?? 0}',
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _ProfileChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _ProfileChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 170),
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w900)),
        ),
      ]),
    );
  }
}

class _HeroMeta extends StatelessWidget {
  final String label;
  final String value;

  const _HeroMeta({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Text(label, style: const TextStyle(color: AppConstants.textSecondaryColor, fontSize: 11, fontWeight: FontWeight.w800)),
      const SizedBox(height: 3),
      Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppConstants.textPrimaryColor, fontWeight: FontWeight.w900)),
    ]);
  }
}

class _ProfileStatsGrid extends StatelessWidget {
  final Map<String, dynamic>? stats;
  final bool isLoading;

  const _ProfileStatsGrid({required this.stats, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatItem(Icons.inventory_2_outlined, 'Total ads', _number(stats?['totalProducts']), AppConstants.primaryDarkColor),
      _StatItem(Icons.verified_outlined, 'Live ads', _number(stats?['approvedProducts']), AppConstants.successColor),
      _StatItem(Icons.visibility_outlined, 'Views', _number(stats?['totalViews']), AppConstants.secondaryColor),
      _StatItem(Icons.chat_bubble_outline_rounded, 'Chats', _number(stats?['totalChats']), AppConstants.warningColor),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 430;
      return GridView.builder(
        itemCount: items.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: compact ? 2 : 4,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          mainAxisExtent: 92,
        ),
        itemBuilder: (context, index) {
          final item = items[index];
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppConstants.borderColor),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(item.icon, size: 18, color: item.color),
                const Spacer(),
                if (isLoading) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
              ]),
              const Spacer(),
              Text(isLoading ? '--' : item.value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: AppConstants.textPrimaryColor)),
              const SizedBox(height: 2),
              Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppConstants.textSecondaryColor, fontSize: 11.5, fontWeight: FontWeight.w800)),
            ]),
          );
        },
      );
    });
  }

  static String _number(dynamic value) {
    final n = value is num ? value : num.tryParse('$value') ?? 0;
    return NumberFormat.compact(locale: 'en_IN').format(n);
  }
}

class _StatItem {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem(this.icon, this.label, this.value, this.color);
}

class _PostingQuotaCard extends StatelessWidget {
  final Map<String, dynamic>? eligibility;
  final bool isLoading;
  final VoidCallback onPostAd;

  const _PostingQuotaCard({
    required this.eligibility,
    required this.isLoading,
    required this.onPostAd,
  });

  @override
  Widget build(BuildContext context) {
    final canPost = eligibility?['canPost'] != false;
    final unlimited = eligibility?['unlimited'] == true;
    final daily = _asMap(eligibility?['daily']);
    final monthly = _asMap(eligibility?['monthly']);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: canPost ? Colors.white : const Color(0xFFFFFAFA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: canPost ? AppConstants.borderColor : const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Posting limit',
                      style: TextStyle(
                        color: AppConstants.textSecondaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isLoading
                          ? 'Checking ad slots...'
                          : canPost
                              ? 'Ads you can still post'
                              : 'Posting limit reached',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: onPostAd,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Post Ad'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final children = [
                _QuotaMetric(
                  icon: Icons.schedule_rounded,
                  label: 'Today remaining',
                  value: isLoading ? '--' : _formatRemaining(daily['remaining']),
                  used: _asInt(daily['used']),
                  limit: _asInt(daily['limit']),
                  unlimited: unlimited,
                  color: AppConstants.primaryDarkColor,
                  background: AppConstants.primaryLightColor,
                ),
                _QuotaMetric(
                  icon: Icons.calendar_month_rounded,
                  label: 'This month remaining',
                  value: isLoading ? '--' : _formatRemaining(monthly['remaining']),
                  used: _asInt(monthly['used']),
                  limit: _asInt(monthly['limit']),
                  unlimited: unlimited,
                  color: AppConstants.successColor,
                  background: const Color(0xFFEFFBF3),
                ),
              ];

              if (compact) {
                return Column(
                  children: [
                    children.first,
                    const SizedBox(height: 10),
                    children.last,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: children.first),
                  const SizedBox(width: 10),
                  Expanded(child: children.last),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  static int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  static String _formatRemaining(dynamic value) {
    if (value == null) return 'Unlimited';
    return '${_asInt(value)}';
  }
}

class _QuotaMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final int used;
  final int limit;
  final bool unlimited;
  final Color color;
  final Color background;

  const _QuotaMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.used,
    required this.limit,
    required this.unlimited,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    final progress = limit <= 0 ? 0.0 : (used / limit).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppConstants.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppConstants.textSecondaryColor, fontSize: 12, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(value, style: const TextStyle(color: AppConstants.textPrimaryColor, fontSize: 22, fontWeight: FontWeight.w900)),
                if (!unlimited) ...[
                  const SizedBox(height: 2),
                  Text('$used of $limit used', style: const TextStyle(color: AppConstants.textSecondaryColor, fontSize: 11, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: AppConstants.borderColor,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
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

class _SettingsGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsGroup({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title, style: const TextStyle(color: AppConstants.textSecondaryColor, fontWeight: FontWeight.w900)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppConstants.borderColor),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool danger;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.danger = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppConstants.errorColor : AppConstants.textPrimaryColor;
    return ListTile(
      leading: Icon(icon, color: danger ? AppConstants.errorColor : AppConstants.primaryDarkColor),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: color)),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
