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
  final double? latitude;
  final double? longitude;

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
    this.latitude,
    this.longitude,
  });

  bool get hasCoordinates => latitude != null && longitude != null;

  factory Product.fromJson(Map<String, dynamic> json) {
    final coords = _readCoordinates(json);
    return Product(
      id: json['_id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      price: _toDouble(json['price']),
      images: _readImages(json['images']),
      location: (json['location'] ?? '').toString().trim(),
      category: json['category'] ?? '',
      userId: json['user'] is String ? json['user'] : (json['userId'] ?? json['user']?['_id'] ?? ''),
      user: json['user'] is Map<String, dynamic> ? User.fromJson(json['user']) : null,
      createdAt: DateTime.tryParse('${json['createdAt']}') ?? DateTime.now(),
      updatedAt: DateTime.tryParse('${json['updatedAt']}') ?? DateTime.now(),
      isActive: (json['status'] ?? 'approved') == 'approved',
      condition: json['condition'] ?? 'Used',
      views: json['views'] ?? 0,
      status: json['status'] ?? 'approved',
      latitude: coords?.$2,
      longitude: coords?.$1,
    );
  }
  
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

double? _readNum(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}

(double, double)? _readLngLatList(dynamic value) {
  final list = value is Map ? value['coordinates'] : value;
  if (list is! List || list.length < 2) return null;
  final lng = _readNum(list[0]);
  final lat = _readNum(list[1]);
  if (lat == null || lng == null || (lat == 0 && lng == 0)) return null;
  return (lng, lat);
}

(double, double)? _readCoordinates(Map<String, dynamic> json) {
  final geo = _readLngLatList(json['locationCoords']);
  if (geo != null) return geo;

  final coords = _readLngLatList(json['coordinates']);
  if (coords != null) return coords;

  final location = json['location'];
  if (location is Map) {
    final fromLocationCoords = _readLngLatList(location['coordinates']);
    if (fromLocationCoords != null) return fromLocationCoords;
    final lat = _readNum(location['lat'] ?? location['latitude']);
    final lng = _readNum(location['lng'] ?? location['longitude']);
    if (lat != null && lng != null && !(lat == 0 && lng == 0)) return (lng, lat);
  }

  final lat = _readNum(json['lat'] ?? json['latitude']);
  final lng = _readNum(json['lng'] ?? json['longitude']);
  if (lat != null && lng != null && !(lat == 0 && lng == 0)) return (lng, lat);
  return null;
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
