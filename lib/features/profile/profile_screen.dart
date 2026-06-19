import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_language.dart';
import '../../core/auth_provider.dart';
import '../../core/constants.dart';
import '../../core/theme_mode.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final language = ref.watch(appLanguageProvider);
    final themeMode = ref.watch(appThemeModeProvider);

    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: Text(tr(language, 'account')),
        backgroundColor: AppConstants.backgroundColor,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppConstants.borderColor),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: AppConstants.primaryLightColor,
                  backgroundImage: user?.avatar != null ? NetworkImage(user!.avatar!) : null,
                  child: user?.avatar == null
                      ? const Icon(Icons.person_rounded, size: 34, color: AppConstants.primaryDarkColor)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name.isNotEmpty == true ? user!.name : 'BuySellAdda User',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        user?.email ?? 'Manage your account',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppConstants.textSecondaryColor),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit profile',
                  onPressed: () => Navigator.pushNamed(context, '/edit-profile'),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
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
            ],
          ),
          const SizedBox(height: 14),
          _SettingsGroup(
            title: tr(language, 'settings'),
            children: [
              _SettingsTile(
                icon: themeMode == ThemeMode.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                title: 'Appearance',
                subtitle: themeMode == ThemeMode.dark ? 'Dark theme' : 'Light theme',
                onTap: () => ref.read(appThemeModeProvider.notifier).setDark(themeMode != ThemeMode.dark),
              ),
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
    );
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (!mounted) return;
    Navigator.popUntil(context, (route) => route.isFirst);
    _showSnack('Logged out successfully');
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
