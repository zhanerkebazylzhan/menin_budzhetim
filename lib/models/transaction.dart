import 'enums.dart';

/// Модель транзакции (доход или расход)
class Transaction {
  final int? id;
  final double amount;          // Сумма в тенге
  final String description;     // Описание операции
  final DateTime date;          // Дата операции
  final int categoryId;         // ID категории
  final TransactionType type;   // income или expense
  final DateTime createdAt;     // Дата создания записи
  final DateTime? updatedAt;    // Дата последнего изменения

  const Transaction({
    this.id,
    required this.amount,
    required this.description,
    required this.date,
    required this.categoryId,
    required this.type,
    required this.createdAt,
    this.updatedAt,
  });

  /// Создание из Map (для SQLite)
  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as int?,
      amount: (map['amount'] as num).toDouble(),
      description: map['description'] as String? ?? '',
      date: DateTime.parse(map['date'] as String),
      categoryId: map['category_id'] as int,
      type: TransactionType.fromString(map['type'] as String),
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
      'amount': amount,
      'description': description,
      'date': date.toIso8601String(),
      'category_id': categoryId,
      'type': type.value,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Копирование с изменениями
  Transaction copyWith({
    int? id,
    double? amount,
    String? description,
    DateTime? date,
    int? categoryId,
    TransactionType? type,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      date: date ?? this.date,
      categoryId: categoryId ?? this.categoryId,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Проверка валидности транзакции
  bool get isValid {
    return amount > 0 && 
           amount <= 99999999 && 
           description.length <= 100 &&
           date.isAfter(DateTime(2020, 1, 1)) &&
           date.isBefore(DateTime.now().add(const Duration(days: 2)));
  }

  /// Форматированная сумма с валютой
  String get formattedAmount {
    final formatter = amount.toStringAsFixed(0);
    // Добавляем пробелы для разделения тысяч
    final parts = <String>[];
    final chars = formatter.split('').reversed.toList();
    
    for (int i = 0; i < chars.length; i++) {
      if (i % 3 == 0 && i != 0) {
        parts.add(' ');
      }
      parts.add(chars[i]);
    }
    
    return '${parts.reversed.join('')} ₸';
  }

  /// Форматированная сумма с знаком
  String get formattedAmountWithSign {
    final sign = type == TransactionType.income ? '+' : '-';
    return '$sign$formattedAmount';
  }
  @override
  String toString() {
    return 'Transaction(id: $id, amount: $amount, type: ${type.value}, date: $date)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Transaction &&
        other.id == id &&
        other.amount == amount &&
        other.type == type &&
        other.date == date;
  }

  @override
  int get hashCode => 
      id.hashCode ^ amount.hashCode ^ type.hashCode ^ date.hashCode;
}