import 'package:flutter/foundation.dart' show debugPrint;
import '../models/category.dart';
import '../models/transaction.dart' as app_models;
import '../models/enums.dart';
import '../models/user_profile.dart';
import '../utils/constants.dart';

/// Временный сервис для веб-версии (без SQLite)
class MockDatabaseService {
  static final MockDatabaseService _instance = MockDatabaseService._internal();
  factory MockDatabaseService() => _instance;
  MockDatabaseService._internal();

  // Временные данные в памяти
  final List<Category> _categories = [];
  final List<app_models.Transaction> _transactions = [];
  UserProfile? _userProfile;
  bool _initialized = false;

  /// Инициализация (имитация создания БД)
  Future<void> _initialize() async {
    if (_initialized) return;
    
    // Добавляем предустановленные категории
    _categories.addAll(DefaultCategories.all.map((category) => 
      category.copyWith(id: _categories.length + 1)
    ));
    
    _initialized = true;
    
    debugPrint('📱 Временная база данных инициализирована');
    debugPrint('📂 Загружено категорий: ${_categories.length}');
  }

  // ===== РАБОТА С КАТЕГОРИЯМИ =====

  /// Получить все категории
  Future<List<Category>> getCategories() async {
    await _initialize();
    return List.from(_categories);
  }

  /// Получить категории по типу
  Future<List<Category>> getCategoriesByType(TransactionType type) async {
    await _initialize();
    return _categories.where((cat) => cat.type == type).toList();
  }

  /// Получить категорию по ID
  Future<Category?> getCategoryById(int id) async {
    await _initialize();
    try {
      return _categories.firstWhere((cat) => cat.id == id);
    } catch (e) {
      return null;
    }
  }

  // ===== РАБОТА С ТРАНЗАКЦИЯМИ =====

  /// Добавить транзакцию
  Future<int> insertTransaction(app_models.Transaction transaction) async {
    await _initialize();
    
    final newId = _transactions.length + 1;
    final newTransaction = transaction.copyWith(id: newId);
    _transactions.add(newTransaction);
    
    debugPrint('💰 Добавлена транзакция: ${newTransaction.description} - ${newTransaction.formattedAmountWithSign}');
    debugPrint('📊 Всего транзакций: ${_transactions.length}');
    
    return newId;
  }

  /// Получить все транзакции
  Future<List<app_models.Transaction>> getTransactions({
    int? limit,
    String? orderBy = 'date DESC',
  }) async {
    await _initialize();
    
    var result = List<app_models.Transaction>.from(_transactions);
    
    // Простая сортировка по дате (по убыванию)
    result.sort((a, b) => b.date.compareTo(a.date));
    
    if (limit != null && limit > 0) {
      result = result.take(limit).toList();
    }
    
    return result;
  }

  /// Получить транзакции по типу
  Future<List<app_models.Transaction>> getTransactionsByType(TransactionType type) async {
    await _initialize();
    return _transactions.where((t) => t.type == type).toList();
  }

  /// Получить транзакции за период
  Future<List<app_models.Transaction>> getTransactionsByPeriod(
    DateTime startDate,
    DateTime endDate,
  ) async {
    await _initialize();
    return _transactions.where((t) => 
      t.date.isAfter(startDate) && t.date.isBefore(endDate)
    ).toList();
  }

  /// Обновить транзакцию
  Future<int> updateTransaction(app_models.Transaction transaction) async {
    await _initialize();
    
    final index = _transactions.indexWhere((t) => t.id == transaction.id);
    if (index != -1) {
      _transactions[index] = transaction;
      return 1;
    }
    return 0;
  }

  /// Удалить транзакцию
  Future<int> deleteTransaction(int id) async {
    await _initialize();
    
    final index = _transactions.indexWhere((t) => t.id == id);
    if (index != -1) {
      _transactions.removeAt(index);
      return 1;
    }
    return 0;
  }

  // ===== СТАТИСТИКА =====

  /// Получить общий баланс
  Future<double> getTotalBalance() async {
    await _initialize();
    
    double totalIncome = 0.0;
    double totalExpense = 0.0;
    
    for (final transaction in _transactions) {
      if (transaction.type == TransactionType.income) {
        totalIncome += transaction.amount;
      } else {
        totalExpense += transaction.amount;
      }
    }
    
    final balance = totalIncome - totalExpense;
    debugPrint('💰 Текущий баланс: ${balance.toStringAsFixed(0)} ₸ (Доходы: ${totalIncome.toStringAsFixed(0)} ₸, Расходы: ${totalExpense.toStringAsFixed(0)} ₸)');
    
    return balance;
  }

  /// Получить доходы и расходы за период
  Future<Map<String, double>> getIncomeExpenseByPeriod(
    DateTime startDate,
    DateTime endDate,
  ) async {
    await _initialize();
    
    double income = 0.0;
    double expense = 0.0;
    
    for (final transaction in _transactions) {
      if (transaction.date.isAfter(startDate) && transaction.date.isBefore(endDate)) {
        if (transaction.type == TransactionType.income) {
          income += transaction.amount;
        } else {
          expense += transaction.amount;
        }
      }
    }
    
    return {
      'income': income,
      'expense': expense,
      'balance': income - expense,
    };
  }

  /// Закрыть базу данных (заглушка)
  Future<void> close() async {
    // Ничего не делаем для временной версии
  }

  // ===== РАБОТА С ПРОФИЛЕМ ПОЛЬЗОВАТЕЛЯ =====

  /// Получить профиль пользователя
  Future<UserProfile?> getUserProfile() async {
    await _initialize();
    return _userProfile;
  }

  /// Сохранить или обновить профиль пользователя
  Future<int> saveUserProfile(UserProfile profile) async {
    await _initialize();
    
    if (_userProfile != null) {
      // Обновляем существующий
      _userProfile = profile.copyWith(id: 1);
    } else {
      // Создаем новый
      _userProfile = profile.copyWith(id: 1);
    }
    
    debugPrint('👤 Профиль сохранен: ${_userProfile!.name} (${_userProfile!.email})');
    return 1;
  }

  /// Удалить профиль пользователя
  Future<int> deleteUserProfile() async {
    await _initialize();
    _userProfile = null;
    debugPrint('🗑️ Профиль пользователя удален');
    return 1;
  }

  // ===== СБРОС ДАННЫХ =====

  /// Полный сброс всех данных приложения
  Future<void> resetAllData() async {
    _transactions.clear();
    _userProfile = null;
    debugPrint('🧹 Все данные приложения сброшены');
  }

  // ===== ДОПОЛНИТЕЛЬНЫЕ МЕТОДЫ ДЛЯ ОТЛАДКИ =====

  /// Получить статистику
  void printStats() {
    debugPrint('\n📊 === СТАТИСТИКА ВРЕМЕННОЙ БД ===');
    debugPrint('📂 Категорий: ${_categories.length}');
    debugPrint('💰 Транзакций: ${_transactions.length}');
    
    if (_transactions.isNotEmpty) {
      final income = _transactions.where((t) => t.type == TransactionType.income).length;
      final expense = _transactions.where((t) => t.type == TransactionType.expense).length;
      debugPrint('📈 Доходов: $income');
      debugPrint('📉 Расходов: $expense');
    }
    debugPrint('==================================\n');
  }

  /// Очистить все данные
  Future<void> clearAll() async {
    _transactions.clear();
    debugPrint('🧹 Все транзакции удалены');
  }
}