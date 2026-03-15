/// Mirrors public.profiles (auth.users 1:1).
/// Schema: database/schema.sql
class Profile {
  const Profile({
    required this.id,
    this.username,
    this.fullName,
    this.email,
    this.phone,
    this.avatarUrl,
    this.birthDate,
    this.rating = 0,
    this.ratingCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String? username;
  final String? fullName;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final DateTime? birthDate;
  final double rating;
  final int ratingCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Display name: full_name or username or email fallback.
  String get displayName => fullName?.trim().isNotEmpty == true
      ? fullName!
      : (username?.trim().isNotEmpty == true ? '@$username' : (email ?? 'User'));

  static Profile fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      username: json['username'] as String?,
      fullName: json['full_name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      birthDate: json['birth_date'] != null
          ? DateTime.parse(json['birth_date'] as String)
          : null,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      ratingCount: (json['rating_count'] as int?) ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'avatar_url': avatarUrl,
        'birth_date': birthDate?.toIso8601String(),
        'rating': rating,
        'rating_count': ratingCount,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };
}
