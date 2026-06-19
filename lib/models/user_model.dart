class User {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? avatar;
  final String? location;
  
  User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.avatar,
    this.location,
  });
  
  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['_id'] ?? json['id'] ?? '',
    name: json['name'] ?? '',
    email: json['email'] ?? '',
    phone: json['phone'],
    avatar: json['avatar'],
    location: json['location'],
  );
  
  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone ?? '',
    'location': location ?? '',
  };
}

