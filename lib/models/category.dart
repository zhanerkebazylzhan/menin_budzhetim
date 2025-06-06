import 'enums.dart';

/// Модель категории для доходов и расходов
class Category {
  final int? id;
  final String name;         // Название на русском
  final String nameKz;       // Название на казахском
  final String icon;         // Название Material Icon
  final String colorHex;     // Цвет в формате HEX
  final TransactionType type; // income или expense
  final bool isDefault;      // Системная категория (нельзя удалить)
  final DateTime createdAt;

  const Category({
    this.id,
    required this.name,
    required this.nameKz,
    required this.icon,
    required this.colorHex,
    required this.type,
    this.isDefault = true,
    required this.createdAt,
  });

  /// Создание из Map (для SQLite)
  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int?,
      name: map['name'] as String,
      nameKz: map['name_kz'] as String,
      icon: map['icon'] as String,
      colorHex: map['color_hex'] as String,
      type: TransactionType.fromString(map['type'] as String),
      isDefault: (map['is_default'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Преобразование в Map (для SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'name_kz': nameKz,
      'icon': icon,
      'color_hex': colorHex,
      'type': type.value,
      'is_default': isDefault ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Копирование с изменениями
  Category copyWith({
    int? id,
    String? name,
    String? nameKz,
    String? icon,
    String? colorHex,
    TransactionType? type,
    bool? isDefault,
    DateTime? createdAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      nameKz: nameKz ?? this.nameKz,
      icon: icon ?? this.icon,
      colorHex: colorHex ?? this.colorHex,
      type: type ?? this.type,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'Category(id: $id, name: $name, type: ${type.value})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Category &&
        other.id == id &&
        other.name == name &&
        other.type == type;
  }

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ type.hashCode;
}