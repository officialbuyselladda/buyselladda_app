import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_service.dart';
import 'constants.dart';

class DealAppConfig {
  final String appName;
  final String tagline;
  final String versionName;
  final String logoUrl;
  final String appIconUrl;
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final String splashTitle;
  final String splashSubtitle;
  final String splashLoadingText;
  final Color splashBackgroundColor;
  final String splashLogoUrl;
  final List<String> splashChips;
  final String previewLocationText;
  final String previewSearchPlaceholder;
  final List<String> featuredCategories;
  final bool maintenanceMode;
  final String maintenanceMessage;
  final bool forceUpdate;
  final String updateMessage;

  const DealAppConfig({
    required this.appName,
    required this.tagline,
    required this.versionName,
    required this.logoUrl,
    required this.appIconUrl,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.splashTitle,
    required this.splashSubtitle,
    required this.splashLoadingText,
    required this.splashBackgroundColor,
    required this.splashLogoUrl,
    required this.splashChips,
    required this.previewLocationText,
    required this.previewSearchPlaceholder,
    required this.featuredCategories,
    required this.maintenanceMode,
    required this.maintenanceMessage,
    required this.forceUpdate,
    required this.updateMessage,
  });

  factory DealAppConfig.fallback() => const DealAppConfig(
        appName: AppConstants.appName,
        tagline: AppConstants.tagline,
        versionName: AppConstants.appVersion,
        logoUrl: '',
        appIconUrl: '',
        primaryColor: AppConstants.primaryColor,
        secondaryColor: AppConstants.secondaryColor,
        accentColor: Color(0xFFFF8200),
        splashTitle: AppConstants.appName,
        splashSubtitle: AppConstants.tagline,
        splashLoadingText: 'Loading fresh deals near you',
        splashBackgroundColor: Colors.white,
        splashLogoUrl: '',
        splashChips: ['Nearby', 'Verified', 'Chat'],
        previewLocationText: 'India',
        previewSearchPlaceholder: 'Search cars, phones, furniture...',
        featuredCategories: ['Electronics', 'Vehicles', 'Property', 'Services'],
        maintenanceMode: false,
        maintenanceMessage: 'App maintenance is in progress. Please try again later.',
        forceUpdate: false,
        updateMessage: 'Please update the app to continue.',
      );

  factory DealAppConfig.fromJson(Map<String, dynamic> json) {
    final fallback = DealAppConfig.fallback();
    final identity = _map(json['identity']);
    final branding = _map(json['branding']);
    final splash = _map(json['splash']);
    final preview = _map(json['preview']);
    final controls = _map(json['controls']);

    return DealAppConfig(
      appName: _string(identity['appName'], fallback.appName),
      tagline: _string(identity['tagline'], fallback.tagline),
      versionName: _string(identity['versionName'], fallback.versionName),
      logoUrl: _string(branding['logoUrl'], fallback.logoUrl),
      appIconUrl: _string(branding['appIconUrl'], fallback.appIconUrl),
      primaryColor: _color(branding['primaryColor'], fallback.primaryColor),
      secondaryColor: _color(branding['secondaryColor'], fallback.secondaryColor),
      accentColor: _color(branding['accentColor'], fallback.accentColor),
      splashTitle: _string(splash['title'], _string(identity['appName'], fallback.splashTitle)),
      splashSubtitle: _string(splash['subtitle'], _string(identity['tagline'], fallback.splashSubtitle)),
      splashLoadingText: _string(splash['loadingText'], fallback.splashLoadingText),
      splashBackgroundColor: _color(splash['backgroundColor'], fallback.splashBackgroundColor),
      splashLogoUrl: _string(splash['logoUrl'], _string(branding['logoUrl'], fallback.splashLogoUrl)),
      splashChips: _stringList(splash['chips'], fallback.splashChips),
      previewLocationText: _string(preview['locationText'], fallback.previewLocationText),
      previewSearchPlaceholder: _string(preview['searchPlaceholder'], fallback.previewSearchPlaceholder),
      featuredCategories: _stringList(preview['featuredCategories'], fallback.featuredCategories),
      maintenanceMode: controls['maintenanceMode'] == true,
      maintenanceMessage: _string(controls['maintenanceMessage'], fallback.maintenanceMessage),
      forceUpdate: controls['forceUpdate'] == true,
      updateMessage: _string(controls['updateMessage'], fallback.updateMessage),
    );
  }
}

final appConfigProvider = FutureProvider<DealAppConfig>((ref) async {
  try {
    final response = await ApiService.get('/app-config');
    final data = response.data is Map<String, dynamic>
        ? response.data['data']
        : null;
    if (data is Map<String, dynamic>) {
      return DealAppConfig.fromJson(data);
    }
  } catch (_) {}
  return DealAppConfig.fallback();
});

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return {};
}

String _string(dynamic value, String fallback) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? fallback : text;
}

List<String> _stringList(dynamic value, List<String> fallback) {
  if (value is! List) return fallback;
  final items = value.map((item) => item.toString().trim()).where((item) => item.isNotEmpty).toList();
  return items.isEmpty ? fallback : items;
}

Color _color(dynamic value, Color fallback) {
  final text = value?.toString().replaceAll('#', '').trim();
  if (text == null || text.length != 6) return fallback;
  final parsed = int.tryParse('FF$text', radix: 16);
  return parsed == null ? fallback : Color(parsed);
}
