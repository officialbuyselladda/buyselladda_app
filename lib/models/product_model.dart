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
  });
  
  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['_id'] ?? '',
    title: json['title'] ?? '',
    description: json['description'] ?? '',
    price: (json['price'] ?? 0).toDouble(),
    images: List<String>.from((json['images'] ?? [])),
    location: json['location'] ?? '',
    category: json['category'] ?? '',
    userId: json['userId'] ?? '',
    user: json['user'] != null ? User.fromJson(json['user']) : null,
    createdAt: DateTime.parse(json['createdAt']),
    updatedAt: DateTime.parse(json['updatedAt']),
  );
  
  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'price': price,
    'category': category,
    'location': location,
  };
}

