import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:intl/intl.dart';

import '../../models/enums.dart';
import '../../models/category.dart';
import '../../models/transaction.dart';
import '../../services/database_service.dart';
import '../../services/mock_database_service.dart';
import '../transactions/add_transaction_screen.dart';
import '../../widgets/transaction_swipe_widget.dart';

/// Экран списка всех транзакций с фильтрацией
class TransactionsListScreen extends StatefulWidget {
  const TransactionsListScreen({super.key});

  @override
  State<TransactionsListScreen> createState() => _TransactionsListScreenState();
}

class _TransactionsListScreenState extends State<TransactionsListScreen> {
  late final dynamic _dbService;
  
  List<Transaction> _transactions = [];
  List<Category> _categories = [];
  bool _isLoading = true;
  
  // Фильтры
  TransactionType? _selectedType;
  Category? _selectedCategory;
  String _searchQuery = '';
  FilterPeriod _selectedPeriod = FilterPeriod.all;
  
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _dbService = kIsWeb ? MockDatabaseService() : DatabaseService();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Загрузка всех данных
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Загружаем данные по отдельности для избежания проблем с типами
      final transactions = await _dbService.getTransactions();
      final categories = await _dbService.getCategories();

      setState(() {
        _transactions = transactions;
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Ошибка загрузки данных: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Фильтрация транзакций
  List<Transaction> get _filteredTransactions {
    var filtered = List<Transaction>.from(_transactions);

    // Фильтр по типу
    if (_selectedType != null) {
      filtered = filtered.where((t) => t.type == _selectedType).toList();
    }

    // Фильтр по категории
    if (_selectedCategory != null) {
      filtered = filtered.where((t) => t.categoryId == _selectedCategory!.id).toList();
    }

    // Поиск по описанию
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((t) => 
        t.description.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    // Фильтр по периоду
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case FilterPeriod.week:
        final weekAgo = now.subtract(const Duration(days: 7));
        filtered = filtered.where((t) => t.date.isAfter(weekAgo)).toList();
        break;
      case FilterPeriod.month:
        final monthAgo = DateTime(now.year, now.month - 1, now.day);
        filtered = filtered.where((t) => t.date.isAfter(monthAgo)).toList();
        break;
      case FilterPeriod.year:
        final yearAgo = DateTime(now.year - 1, now.month, now.day);
        filtered = filtered.where((t) => t.date.isAfter(yearAgo)).toList();
        break;
      case FilterPeriod.all:
        // Без фильтрации
        break;
    }

    // Сортировка по дате (новые сверху)
    filtered.sort((a, b) => b.date.compareTo(a.date));

    return filtered;
  }

  /// Группировка транзакций по дням
  Map<String, List<Transaction>> get _groupedTransactions {
    final grouped = <String, List<Transaction>>{};
    
    for (final transaction in _filteredTransactions) {
      final dateKey = DateFormat('yyyy-MM-dd').format(transaction.date);
      grouped[dateKey] ??= [];
      grouped[dateKey]!.add(transaction);
    }
    
    return grouped;
  }

  /// Открытие экрана добавления транзакции
  Future<void> _openAddTransactionScreen() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const AddTransactionScreen(),
      ),
    );

    if (result == true) {
      _loadData(); // Перезагружаем данные
    }
  }

  /// Получение категории по ID
  Category? _getCategoryById(int categoryId) {
    try {
      return _categories.firstWhere((cat) => cat.id == categoryId);
    } catch (e) {
      return null;
    }
  }

  /// Получение иконки категории
  IconData _getCategoryIcon(String iconName) {
    final iconMap = {
      'restaurant': Icons.restaurant,
      'directions_bus': Icons.directions_bus,
      'home': Icons.home,
      'checkroom': Icons.checkroom,
      'local_hospital': Icons.local_hospital,
      'sports_esports': Icons.sports_esports,
      'school': Icons.school,
      'more_horiz': Icons.more_horiz,
      'payments': Icons.payments,
      'work': Icons.work,
      'card_giftcard': Icons.card_giftcard,
      'account_balance': Icons.account_balance,
    };
    
    return iconMap[iconName] ?? Icons.category;
  }

  /// Очистка всех фильтров
  void _clearFilters() {
    setState(() {
      _selectedType = null;
      _selectedCategory = null;
      _searchQuery = '';
      _selectedPeriod = FilterPeriod.all;
      _searchController.clear();
    });
  }

  /// Удаление транзакции
  Future<void> _deleteTransaction(Transaction transaction) async {
    try {
      await _dbService.deleteTransaction(transaction.id!);
      _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Операция удалена'),
            backgroundColor: Colors.green.shade600,
            action: SnackBarAction(
              label: 'Отменить',
              textColor: Colors.white,
              onPressed: () async {
                // Восстанавливаем транзакцию
                await _dbService.insertTransaction(transaction);
                _loadData();
              },
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Ошибка удаления транзакции: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Ошибка удаления'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  /// Редактирование транзакции
  Future<void> _editTransaction(Transaction transaction) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => AddTransactionScreen(
          transaction: transaction,
        ),
      ),
    );

    if (result == true) {
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredTransactions = _filteredTransactions;
    final groupedTransactions = _groupedTransactions;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Все операции',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _openAddTransactionScreen,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Панель фильтров
                _buildFiltersPanel(),
                
                // Список транзакций
                Expanded(
                  child: filteredTransactions.isEmpty
                      ? _buildEmptyState()
                      : _buildTransactionsList(groupedTransactions),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddTransactionScreen,
        backgroundColor: Colors.green.shade700,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  /// Панель фильтров
  Widget _buildFiltersPanel() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Поиск
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Поиск по описанию...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          
          const SizedBox(height: 16),
          
          // Фильтры
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Фильтр по периоду
                _buildPeriodFilter(),
                
                const SizedBox(width: 12),
                
                // Фильтр по типу
                _buildTypeFilter(),
                
                const SizedBox(width: 12),
                
                // Кнопка очистки фильтров
                if (_selectedType != null || _selectedCategory != null || _selectedPeriod != FilterPeriod.all)
                  _buildClearFiltersButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Фильтр по периоду
  Widget _buildPeriodFilter() {
    return DropdownButton<FilterPeriod>(
      value: _selectedPeriod,
      icon: const Icon(Icons.arrow_drop_down),
      style: TextStyle(color: Colors.grey.shade700),
      underline: Container(),
      onChanged: (FilterPeriod? newValue) {
        if (newValue != null) {
          setState(() {
            _selectedPeriod = newValue;
          });
        }
      },
      items: FilterPeriod.values.map<DropdownMenuItem<FilterPeriod>>((FilterPeriod value) {
        return DropdownMenuItem<FilterPeriod>(
          value: value,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _selectedPeriod == value ? Colors.green.shade100 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(value.displayName),
          ),
        );
      }).toList(),
    );
  }

  /// Фильтр по типу транзакции
  Widget _buildTypeFilter() {
    return Row(
      children: [
        _buildTypeChip(null, 'Все'),
        const SizedBox(width: 8),
        _buildTypeChip(TransactionType.income, 'Доходы'),
        const SizedBox(width: 8),
        _buildTypeChip(TransactionType.expense, 'Расходы'),
      ],
    );
  }

  /// Чип фильтра по типу
  Widget _buildTypeChip(TransactionType? type, String label) {
    final isSelected = _selectedType == type;
    final color = type == TransactionType.income 
        ? Colors.green 
        : type == TransactionType.expense 
            ? Colors.red 
            : Colors.grey;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = type;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.shade100 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color.shade700 : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  /// Кнопка очистки фильтров
  Widget _buildClearFiltersButton() {
    return GestureDetector(
      onTap: _clearFilters,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.clear, size: 16, color: Colors.orange.shade700),
            const SizedBox(width: 4),
            Text(
              'Очистить',
              style: TextStyle(
                color: Colors.orange.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Пустое состояние
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _transactions.isEmpty 
                  ? 'Пока нет транзакций'
                  : 'Нет транзакций по выбранным фильтрам',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _transactions.isEmpty 
                  ? 'Добавьте первую операцию'
                  : 'Попробуйте изменить критерии поиска',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _transactions.isEmpty ? _openAddTransactionScreen : _clearFilters,
              icon: Icon(_transactions.isEmpty ? Icons.add : Icons.clear),
              label: Text(_transactions.isEmpty ? 'Добавить транзакцию' : 'Очистить фильтры'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Список транзакций, сгруппированных по дням
  Widget _buildTransactionsList(Map<String, List<Transaction>> groupedTransactions) {
    final sortedDates = groupedTransactions.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final dateKey = sortedDates[index];
        final transactions = groupedTransactions[dateKey]!;
        final date = DateTime.parse(dateKey);
        
        return _buildDayGroup(date, transactions);
      },
    );
  }

  /// Группа транзакций за один день
  Widget _buildDayGroup(DateTime date, List<Transaction> transactions) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final transactionDate = DateTime(date.year, date.month, date.day);

    String dateLabel;
    if (transactionDate == today) {
      dateLabel = 'Сегодня';
    } else if (transactionDate == yesterday) {
      dateLabel = 'Вчера';
    } else {
      dateLabel = DateFormat('dd.MM.yyyy').format(date);
    }

    // Подсчет суммы за день
    double dayTotal = 0;
    for (final transaction in transactions) {
      if (transaction.type == TransactionType.income) {
        dayTotal += transaction.amount;
      } else {
        dayTotal -= transaction.amount;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок дня
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateLabel,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              Text(
                '${dayTotal >= 0 ? '+' : ''}${dayTotal.toStringAsFixed(0)} ₸',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: dayTotal >= 0 ? Colors.green.shade600 : Colors.red.shade600,
                ),
              ),
            ],
          ),
        ),
        
        // Транзакции за день
        ...transactions.map((transaction) => _buildTransactionCard(transaction)),
        
        const SizedBox(height: 16),
      ],
    );
  }

  /// Карточка транзакции
  Widget _buildTransactionCard(Transaction transaction) {
    final category = _getCategoryById(transaction.categoryId);
    final categoryColor = category != null 
        ? Color(int.parse('0xFF${category.colorHex.substring(1)}'))
        : Colors.grey;

    return TransactionSwipeWidget(
      transaction: transaction,
      onDelete: () => _deleteTransaction(transaction),
      onEdit: () => _editTransaction(transaction),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8.0),
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: categoryColor.withOpacity(0.1),
            child: Icon(
              _getCategoryIcon(category?.icon ?? 'more_horiz'),
              color: categoryColor,
              size: 20,
            ),
          ),
          title: Text(
            transaction.description.isNotEmpty 
                ? transaction.description 
                : category?.name ?? 'Без категории',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category?.name ?? 'Без категории',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('HH:mm').format(transaction.date),
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          trailing: Text(
            transaction.formattedAmountWithSign,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: transaction.type == TransactionType.income
                  ? Colors.green.shade600
                  : Colors.red.shade600,
            ),
          ),
        ),
      ),
    );
  }
}