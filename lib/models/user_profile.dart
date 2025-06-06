/// Модель профиля пользователя
class UserProfile {
  final int? id;
  final String name;
  final String email;
  final String currency;  // Пока только 'KZT'
  final DateTime createdAt;
  final DateTime? updatedAt;

  const UserProfile({
    this.id,
    required this.name,
    required this.email,
    this.currency = 'KZT',
    required this.createdAt,
    this.updatedAt,
  });

  /// Создание из Map (для SQLite)
  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as int?,
      name: map['name'] as String,
      email: map['email'] as String,
      currency: map['currency'] as String? ?? 'KZT',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null 
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  /// Преобразование в Map (для SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'currency': currency,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Копирование с изменениями
  UserProfile copyWith({
    int? id,
    String? name,
    String? email,
    String? currency,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'UserProfile(id: $id, name: $name, email: $email)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile &&
        other.id == id &&
        other.name == name &&
        other.email == email;
  }

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ email.hashCode;
}