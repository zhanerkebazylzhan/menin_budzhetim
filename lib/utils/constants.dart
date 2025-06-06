import '../models/category.dart';
import '../models/enums.dart';

/// Константы приложения
class AppConstants {
  // Валидация
  static const double minAmount = 1.0;
  static const double maxAmount = 99999999.0;
  static const int maxDescriptionLength = 100;
  static final DateTime minDate = DateTime(2020, 1, 1);
  static DateTime get maxDate => DateTime.now().add(const Duration(days: 1));

  // Валюта
  static const String currency = '₸';
  static const String currencyName = 'Казахстанский тенге';

  // База данных
  static const String dbName = 'budget_app.db';
  static const int dbVersion = 1;

  // Цвета категорий
  static const String colorExpenseFood = '#FF6B6B';
  static const String colorExpenseTransport = '#4ECDC4';
  static const String colorExpenseHousing = '#45B7D1';
  static const String colorExpenseClothing = '#96CEB4';
  static const String colorExpenseHealth = '#FFEAA7';
  static const String colorExpenseEntertainment = '#DDA0DD';
  static const String colorExpenseEducation = '#FD79A8';
  static const String colorExpenseOther = '#A8A8A8';

  static const String colorIncomesSalary = '#00B894';
  static const String colorIncomeSideJob = '#00CEC9';
  static const String colorIncomeGifts = '#E17055';
  static const String colorIncomeSocial = '#74B9FF';
  static const String colorIncomeOther = '#81ECEC';
}

/// Предустановленные категории согласно ТЗ
class DefaultCategories {
  /// Категории расходов
  static List<Category> get expenseCategories => [
    Category(
      name: 'Еда и продукты',
      nameKz: 'Тамақ',
      icon: 'restaurant',
      colorHex: AppConstants.colorExpenseFood,
      type: TransactionType.expense,
      createdAt: DateTime.now(),
    ),
    Category(
      name: 'Транспорт',
      nameKz: 'Көлік',
      icon: 'directions_bus',
      colorHex: AppConstants.colorExpenseTransport,
      type: TransactionType.expense,
      createdAt: DateTime.now(),
    ),
    Category(
      name: 'ЖКХ и аренда',
      nameKz: 'Тұрғын үй',
      icon: 'home',
      colorHex: AppConstants.colorExpenseHousing,
      type: TransactionType.expense,
      createdAt: DateTime.now(),
    ),
    Category(
      name: 'Одежда',
      nameKz: 'Киім',
      icon: 'checkroom',
      colorHex: AppConstants.colorExpenseClothing,
      type: TransactionType.expense,
      createdAt: DateTime.now(),
    ),
    Category(
      name: 'Здоровье',
      nameKz: 'Денсаулық',
      icon: 'local_hospital',
      colorHex: AppConstants.colorExpenseHealth,
      type: TransactionType.expense,
      createdAt: DateTime.now(),
    ),
    Category(
      name: 'Развлечения',
      nameKz: 'Ойын-сауық',
      icon: 'sports_esports',
      colorHex: AppConstants.colorExpenseEntertainment,
      type: TransactionType.expense,
      createdAt: DateTime.now(),
    ),
    Category(
      name: 'Образование',
      nameKz: 'Білім',
      icon: 'school',
      colorHex: AppConstants.colorExpenseEducation,
      type: TransactionType.expense,
      createdAt: DateTime.now(),
    ),
    Category(
      name: 'Прочее',
      nameKz: 'Басқа',
      icon: 'more_horiz',
      colorHex: AppConstants.colorExpenseOther,
      type: TransactionType.expense,
      createdAt: DateTime.now(),
    ),
  ];

  /// Категории доходов
  static List<Category> get incomeCategories => [
    Category(
      name: 'Зарплата',
      nameKz: 'Жалақы',
      icon: 'payments',
      colorHex: AppConstants.colorIncomesSalary,
      type: TransactionType.income,
      createdAt: DateTime.now(),
    ),
    Category(
      name: 'Подработка',
      nameKz: 'Қосымша жұмыс',
      icon: 'work',
      colorHex: AppConstants.colorIncomeSideJob,
      type: TransactionType.income,
      createdAt: DateTime.now(),
    ),
    Category(
      name: 'Подарки',
      nameKz: 'Сыйлықтар',
      icon: 'card_giftcard',
      colorHex: AppConstants.colorIncomeGifts,
      type: TransactionType.income,
      createdAt: DateTime.now(),
    ),
    Category(
      name: 'Социальные выплаты',
      nameKz: 'Әлеуметтік төлемдер',
      icon: 'account_balance',
      colorHex: AppConstants.colorIncomeSocial,
      type: TransactionType.income,
      createdAt: DateTime.now(),
    ),
    Category(
      name: 'Прочее',
      nameKz: 'Басқа',
      icon: 'more_horiz',
      colorHex: AppConstants.colorIncomeOther,
      type: TransactionType.income,
      createdAt: DateTime.now(),
    ),
  ];

  /// Все предустановленные категории
  static List<Category> get all => [
    ...expenseCategories,
    ...incomeCategories,
  ];
}