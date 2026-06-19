import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final appLanguageProvider = StateNotifierProvider<AppLanguageNotifier, String>((ref) {
  return AppLanguageNotifier()..load();
});

class AppLanguageNotifier extends StateNotifier<String> {
  AppLanguageNotifier() : super('English');

  static const _key = 'deal_app_language';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_key) ?? 'English';
  }

  Future<void> setLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, language);
    state = language;
  }
}

String tr(String language, String key) {
  final table = _translations[language] ?? _translations['English']!;
  return table[key] ?? _translations['English']![key] ?? key;
}

const _english = {
  'app_title': 'BuySellAdda',
  'home': 'Home',
  'account': 'Account',
  'profile': 'Profile',
  'view_edit_profile': 'View and edit profile',
  'add_phone_location': 'Add phone, name and location',
  'wishlist': 'Wishlist',
  'wishlist_subtitle': 'Saved ads and favorite products',
  'my_ads': 'My Ads',
  'my_ads_subtitle': 'Manage active and pending ads',
  'settings': 'Settings',
  'privacy': 'Privacy',
  'privacy_subtitle': 'Account safety and visibility',
  'select_language': 'Select language',
  'help_support': 'Help & support',
  'help_subtitle': 'Report issues, safety tips and FAQs',
  'session': 'Session',
  'logout': 'Logout',
  'logout_subtitle': 'Sign out from this device',
  'save': 'Save',
  'done': 'Done',
  'browse_ads': 'Browse ads',
  'search_hint': 'Search cars, phones, furniture...',
  'fresh_ads': 'Fresh recommendations',
  'loading_ads': 'Loading fresh ads',
  'ads_near_you': 'ads near you',
  'edit_profile': 'Edit profile',
  'save_details': 'Save details',
  'privacy_1_title': 'Profile visibility',
  'privacy_1_body': 'Your email stays private. Phone details are shown only in trusted contact flows.',
  'privacy_2_title': 'Chats',
  'privacy_2_body': 'BuySellAdda keeps conversations attached to the ad so buyer and seller context remains clear.',
  'privacy_3_title': 'Location',
  'privacy_3_body': 'Location helps show nearby listings. You can change or clear it anytime from the home screen.',
  'help_1_title': 'Buying safely',
  'help_1_body': 'Meet in public places, inspect the item, and avoid advance payments.',
  'help_2_title': 'Selling better',
  'help_2_body': 'Use clear photos, fair pricing, and quick replies to get better buyer responses.',
  'help_3_title': 'Support tickets',
  'help_3_body': 'For product, payment, account, or chat issues, contact BuySellAdda support with clear details.',
};

final Map<String, Map<String, String>> _translations = {
  'English': _english,
  'Hindi': _english,
  'Marathi': _english,
  'Gujarati': _english,
  'Tamil': _english,
  'Telugu': _english,
  'Bengali': _english,
};
