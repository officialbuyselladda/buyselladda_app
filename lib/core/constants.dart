// Core constants for BuySellAdda app
import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'BuySellAdda';
  static const String tagline = 'Har Deal, Ek Nayi Shuruaat';
  static const String appVersion = '1.0.0';
  static const String websiteUrl = 'https://buyselladda.com';
  static const double defaultPadding = 16.0;
  static const Duration animationDuration = Duration(milliseconds: 300);
  
  // API paths
  static const String baseUrl = 'https://buyselladda.com/api/'; // ApiService normalizes and uses .env when present.
  static const String authPath = '/auth';
  static const String productPath = '/products';
  static const String userPath = '/users';
  static const String chatPath = '/chats';
  static const String uploadPath = '/upload';
  static const String geocodePath = '/geocode';
  
  // Website-aligned category fallback. Backend categories still load dynamically
  // where available, so admin-created categories appear without app updates.
  static const List<String> categories = [
    'Mobiles',
    'Electronics',
    'Computers & Laptops',
    'Vehicles',
    'Property',
    'Furniture',
    'Fashion',
    'Jobs',
    'Services',
    'Books',
    'Sports & Fitness',
    'Others',
  ];
  
  // Logo-led marketplace palette with OLX-style classifieds UX.
  static const Color primaryColor = Color(0xFF0B63E5);
  static const Color primaryDarkColor = Color(0xFF0647B5);
  static const Color primaryLightColor = Color(0xFFEAF2FF);
  static const Color primaryBorderColor = Color(0xFFBFD7FF);
  static const Color secondaryColor = Color(0xFF12A642);
  static const Color secondaryLightColor = Color(0xFFEAF8EF);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color successColor = Color(0xFF12A642);
  static const Color warningColor = Color(0xFFFF8200);
  static const Color backgroundColor = Color(0xFFF5F7FA);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color borderColor = Color(0xFFDDE5F0);
  static const Color textPrimaryColor = Color(0xFF17233C);
  static const Color textSecondaryColor = Color(0xFF5D6B82);
  static const Color textSubtleColor = Color(0xFF95A1B2);
}
