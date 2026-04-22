// Core constants for DealKro app
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
  
  // Categories
  static const List<String> categories = [
    'Electronics', 'Vehicles', 'Furniture', 'Clothing', 'Books', 'Sports',
    'Real Estate', 'Jobs', 'Services', 'Others'
  ];
  
  // Colors
  static const primaryColor = Color(0xFF
