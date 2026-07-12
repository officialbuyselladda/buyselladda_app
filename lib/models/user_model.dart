class User {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? avatar;
  final String? location;
  final DateTime? createdAt;
  final bool isEmailVerified;
  final int trustScore;
  
  User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.avatar,
    this.location,
    this.createdAt,
    this.isEmailVerified = false,
    this.trustScore = 0,
  });
  
  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['_id'] ?? json['id'] ?? '',
    name: '${json['name'] ?? ''}',
    email: '${json['email'] ?? ''}',
    phone: json['phone'] == null ? null : '${json['phone']}',
    avatar: _readAvatar(json['avatar']),
    location: json['location'] == null ? null : '${json['location']}',
    createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}'),
    isEmailVerified: json['isEmailVerified'] == true || json['emailVerified'] == true,
    trustScore: json['trustScore'] is num ? (json['trustScore'] as num).toInt() : int.tryParse('${json['trustScore']}') ?? 0,
  );
  
  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone ?? '',
    'location': location ?? '',
  };
}

String? _readAvatar(dynamic value) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  if (value is Map && value['url'] != null) return '${value['url']}';
  return null;
}

