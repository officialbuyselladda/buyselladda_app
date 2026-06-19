import 'user_model.dart';

class Product {
  final String id;
  final String title;
  final String description;
  final double price;
  final List<String> images;
  final String location;
  final String category;
  final String userId;
  final User? user;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final String condition;
  final int views;
  final String status;
  
  Product({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.images,
    required this.location,
    required this.category,
    required this.userId,
    this.user,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.condition = 'Used',
    this.views = 0,
    this.status = 'approved',
  });
  
  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['_id'] ?? '',
    title: json['title'] ?? '',
    description: json['description'] ?? '',
    price: _toDouble(json['price']),
    images: _readImages(json['images']),
    location: json['location'] ?? '',
    category: json['category'] ?? '',
    userId: json['user'] is String ? json['user'] : (json['userId'] ?? json['user']?['_id'] ?? ''),
    user: json['user'] is Map<String, dynamic> ? User.fromJson(json['user']) : null,
    createdAt: DateTime.tryParse('${json['createdAt']}') ?? DateTime.now(),
    updatedAt: DateTime.tryParse('${json['updatedAt']}') ?? DateTime.now(),
    isActive: (json['status'] ?? 'approved') == 'approved',
    condition: json['condition'] ?? 'Used',
    views: json['views'] ?? 0,
    status: json['status'] ?? 'approved',
  );
  
  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'price': price,
    'category': category,
    'location': location,
  };
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

List<String> _readImages(dynamic value) {
  if (value is! List) return [];
  return value
      .map((image) {
        if (image is String) return image;
        if (image is Map && image['url'] != null) return '${image['url']}';
        return '';
      })
      .where((url) => url.isNotEmpty)
      .toList();
}

