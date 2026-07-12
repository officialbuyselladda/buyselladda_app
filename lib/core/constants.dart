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
  static const String baseUrl = 'https://dealkro.in/api/'; // ApiService normalizes and uses .env when present.
  static const String authPath = '/auth';
  static const String productPath = '/products';
  static const String userPath = '/users';
  static const String chatPath = '/chats';
  static const String uploadPath = '/upload';
  static const String geocodePath = '/geocode';
  
  // Website-aligned category fallback. Backend categories still load dynamically
  // where available, so admin-created categories appear without app updates.
  static const List<String> categories = [
    'Stationary',
    'Electronics',
    'Jobs',
    'Clothes',
    'Room',
    'Flat,Building',
    'Cars',
    'Motorcycle',
    'For Sale: Houses & Apartments',
    'For Rent: Houses & Apartments',
  ];
  
  // Brand colors aligned with the home screen design system.
  static const Color primaryColor = Color(0xFFF97316);
  static const Color primaryDarkColor = Color(0xFFEA6A05);
  static const Color primaryLightColor = Color(0xFFFFF7ED);
  static const Color primaryBorderColor = Color(0xFFFED7AA);
  static const Color secondaryColor = Color(0xFF2563EB);
  static const Color secondaryLightColor = Color(0xFFEFF6FF);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color backgroundColor = Color(0xFFF8FAFF);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color borderColor = Color(0xFFE2E8F0);
  static const Color textPrimaryColor = Color(0xFF1E293B);
  static const Color textSecondaryColor = Color(0xFF64748B);
  static const Color textSubtleColor = Color(0xFF94A3B8);
}
