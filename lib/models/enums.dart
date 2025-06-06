/// Типы транзакций
enum TransactionType {
  income('income', 'Доход'),
  expense('expense', 'Расход');

  const TransactionType(this.value, this.displayName);
  
  final String value;
  final String displayName;
  
  /// Создает TransactionType из строки
  static TransactionType fromString(String value) {
    return TransactionType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => TransactionType.expense,
    );
  }
}

/// Периоды для фильтрации
enum FilterPeriod {
  week('week', 'Неделя'),
  month('month', 'Месяц'), 
  year('year', 'Год'),
  all('all', 'Все время');

  const FilterPeriod(this.value, this.displayName);
  
  final String value;
  final String displayName;
}