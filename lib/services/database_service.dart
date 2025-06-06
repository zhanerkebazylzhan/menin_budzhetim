import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/category.dart';
import '../models/transaction.dart' as app_models;
import '../models/enums.dart';
import '../models/user_profile.dart';
import '../utils/constants.dart';

/// Сервис для работы с базой данных SQLite
class DatabaseService {
  static Database? _database;
  static final DatabaseService _instance = DatabaseService._internal();
  
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  /// Получение экземпляра базы данных
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  /// Инициализация базы данных
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.dbName);

    return await openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _createTables,
      onUpgrade: _upgradeDatabase,
    );
  }

  /// Создание таблиц при первом запуске
  Future<void> _createTables(Database db, int version) async {
    // Таблица категорий
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        name_kz TEXT NOT NULL,
        icon TEXT NOT NULL,
        color_hex TEXT NOT NULL,
        type TEXT NOT NULL CHECK(type IN ('income', 'expense')),
        is_default INTEGER DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    // Таблица транзакций
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL CHECK(amount > 0),
        description TEXT DEFAULT '',
        date TEXT NOT NULL,
        category_id INTEGER NOT NULL,
        type TEXT NOT NULL CHECK(type IN ('income', 'expense')),
        created_at TEXT NOT NULL,
        updated_at TEXT,
        FOREIGN KEY (category_id) REFERENCES categories (id)
      )
    ''');

    // Таблица профиля пользователя
    await db.execute('''
      CREATE TABLE user_profile (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        currency TEXT DEFAULT 'KZT',
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    // Индексы для ускорения запросов
    await db.execute('CREATE INDEX idx_transactions_date ON transactions(date)');
    await db.execute('CREATE INDEX idx_transactions_type ON transactions(type)');
    await db.execute('CREATE INDEX idx_transactions_category ON transactions(category_id)');

    // Вставляем предустановленные категории
    await _insertDefaultCategories(db);
  }

  /// Обновление схемы базы данных
  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    // Пока не нужно - первая версия
  }

  /// Вставка предустановленных категорий
  Future<void> _insertDefaultCategories(Database db) async {
    final batch = db.batch();
    
    // Добавляем все предустановленные категории
    for (final category in DefaultCategories.all) {
      batch.insert('categories', category.toMap());
    }
    
    await batch.commit();
  }

  // ===== РАБОТА С КАТЕГОРИЯМИ =====

  /// Получить все категории
  Future<List<Category>> getCategories() async {
    final db = await database;
    final maps = await db.query('categories', orderBy: 'name');
    return maps.map((map) => Category.fromMap(map)).toList();
  }

  /// Получить категории по типу
  Future<List<Category>> getCategoriesByType(TransactionType type) async {
    final db = await database;
    final maps = await db.query(
      'categories',
      where: 'type = ?',
      whereArgs: [type.value],
      orderBy: 'name',
    );
    return maps.map((map) => Category.fromMap(map)).toList();
  }

  /// Получить категорию по ID
  Future<Category?> getCategoryById(int id) async {
    final db = await database;
    final maps = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    
    if (maps.isEmpty) return null;
    return Category.fromMap(maps.first);
  }

  // ===== РАБОТА С ТРАНЗАКЦИЯМИ =====

  /// Добавить транзакцию
  Future<int> insertTransaction(app_models.Transaction transaction) async {
    final db = await database;
    return await db.insert('transactions', transaction.toMap());
  }

  /// Получить все транзакции
  Future<List<app_models.Transaction>> getTransactions({
    int? limit,
    String? orderBy = 'date DESC',
  }) async {
    final db = await database;
    final maps = await db.query(
      'transactions',
      orderBy: orderBy,
      limit: limit,
    );
    return maps.map((map) => app_models.Transaction.fromMap(map)).toList();
  }

  /// Получить транзакции по типу
  Future<List<app_models.Transaction>> getTransactionsByType(TransactionType type) async {
    final db = await database;
    final maps = await db.query(
      'transactions',
      where: 'type = ?',
      whereArgs: [type.value],
      orderBy: 'date DESC',
    );
    return maps.map((map) => app_models.Transaction.fromMap(map)).toList();
  }

  /// Получить транзакции за период
  Future<List<app_models.Transaction>> getTransactionsByPeriod(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    final maps = await db.query(
      'transactions',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [
        startDate.toIso8601String(),
        endDate.toIso8601String(),
      ],
      orderBy: 'date DESC',
    );
    return maps.map((map) => app_models.Transaction.fromMap(map)).toList();
  }

  /// Обновить транзакцию
  Future<int> updateTransaction(app_models.Transaction transaction) async {
    final db = await database;
    return await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  /// Удалить транзакцию
  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ===== СТАТИСТИКА =====

  /// Получить общий баланс
  Future<double> getTotalBalance() async {
    final db = await database;
    
    // Общие доходы
    final incomeResult = await db.rawQuery(
      'SELECT SUM(amount) as total FROM transactions WHERE type = ?',
      ['income'],
    );
    final totalIncome = (incomeResult.first['total'] as double?) ?? 0.0;
    
    // Общие расходы
    final expenseResult = await db.rawQuery(
      'SELECT SUM(amount) as total FROM transactions WHERE type = ?',
      ['expense'],
    );
    final totalExpense = (expenseResult.first['total'] as double?) ?? 0.0;
    
    return totalIncome - totalExpense;
  }

  /// Получить доходы и расходы за период
  Future<Map<String, double>> getIncomeExpenseByPeriod(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    
    final result = await db.rawQuery('''
      SELECT 
        type,
        SUM(amount) as total
      FROM transactions 
      WHERE date BETWEEN ? AND ?
      GROUP BY type
    ''', [
      startDate.toIso8601String(),
      endDate.toIso8601String(),
    ]);
    
    double income = 0.0;
    double expense = 0.0;
    
    for (final row in result) {
      final type = row['type'] as String;
      final total = (row['total'] as double?) ?? 0.0;
      
      if (type == 'income') {
        income = total;
      } else if (type == 'expense') {
        expense = total;
      }
    }
    
    return {
      'income': income,
      'expense': expense,
      'balance': income - expense,
    };
  }

  /// Закрыть базу данных
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  // ===== РАБОТА С ПРОФИЛЕМ ПОЛЬЗОВАТЕЛЯ =====

  /// Получить профиль пользователя
  Future<UserProfile?> getUserProfile() async {
    final db = await database;
    final maps = await db.query('user_profile', limit: 1);
    
    if (maps.isEmpty) return null;
    return UserProfile.fromMap(maps.first);
  }

  /// Сохранить или обновить профиль пользователя
  Future<int> saveUserProfile(UserProfile profile) async {
    final db = await database;
    
    // Проверяем, есть ли уже профиль
    final existing = await getUserProfile();
    
    if (existing != null) {
      // Обновляем существующий
      return await db.update(
        'user_profile',
        profile.copyWith(id: existing.id).toMap(),
        where: 'id = ?',
        whereArgs: [existing.id],
      );
    } else {
      // Создаем новый
      return await db.insert('user_profile', profile.toMap());
    }
  }

  /// Удалить профиль пользователя
  Future<int> deleteUserProfile() async {
    final db = await database;
    return await db.delete('user_profile');
  }

  // ===== СБРОС ДАННЫХ =====

  /// Полный сброс всех данных приложения
  Future<void> resetAllData() async {
    final db = await database;
    
    // Удаляем все транзакции
    await db.delete('transactions');
    
    // Удаляем профиль пользователя
    await db.delete('user_profile');
    
    // Удаляем пользовательские категории (оставляем только системные)
    await db.delete(
      'categories',
      where: 'is_default = ?',
      whereArgs: [0],
    );
    
    // Если нужно полностью пересоздать БД с предустановленными категориями:
    // await db.close();
    // await deleteDatabase(join(await getDatabasesPath(), AppConstants.dbName));
    // _database = null;
    // await database; // Это пересоздаст БД
  }
}