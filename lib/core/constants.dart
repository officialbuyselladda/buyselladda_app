// Core constants for DealKro app
import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'DealKro';
  static const String appVersion = '1.0.0';
  static const double defaultPadding = 16.0;
  static const Duration animationDuration = Duration(milliseconds: 300);
  
  // API paths
  static const String baseUrl = '.env'; // Loaded from dotenv
  static const String authPath = '/auth';
  static const String productPath = '/product';
  static const String userPath = '/user';
  static const String chatPath = '/chat';
  static const String uploadPath = '/upload';
  static const String geocodePath = '/geocode';
  
  // Categories - FIXED to match backend validation enum exactly
  static const List<String> categories = [
    'Electronics', 
    'Vehicles', 
    'Property', 
    'Jobs', 
    'Services', 
    'Others'
  ];
  
  // Colors
  static const Color primaryColor = Color(0xFF10B981);
  static const Color primaryDarkColor = Color(0xFF059669);
  static const Color secondaryColor = Color(0xFF3B82F6);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color textPrimaryColor = Color(0xFF0F172A);
  static const Color textSecondaryColor = Color(0xFF64748B);
}
