import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:intl/intl.dart';
import '../../services/database_service.dart';
import '../../services/mock_database_service.dart';
import '../../models/enums.dart';
import '../../models/transaction.dart';
import '../../models/category.dart';
import '../transactions/add_transaction_screen.dart';
import '../transactions/transactions_list_screen.dart';
import '../statistics/statistics_screen.dart';
import '../settings/settings_screen.dart';
import '../../widgets/transaction_swipe_widget.dart';

/// Главный экран приложения - Dashboard
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Используем разные сервисы для веб и мобильных платформ
  late final dynamic _dbService;
  double _balance = 0.0;
  List<Transaction> _recentTransactions = [];
  List<Category> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Определяем какой сервис использовать
    _dbService = kIsWeb ? MockDatabaseService() : DatabaseService();
    _loadData();
  }

  /// Загрузка всех данных
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Загружаем данные по отдельности для избежания проблем с типами
      final balance = await _dbService.getTotalBalance();
      final recentTransactions = await _dbService.getTransactions(limit: 5);
      final categories = await _dbService.getCategories();

      setState(() {
        _balance = balance;
        _recentTransactions = recentTransactions;
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

  /// Обновление данных (pull-to-refresh)
  Future<void> _refreshData() async {
    await _loadData();
  }

  /// Предупреждение о веб-версии
  Widget _buildWebWarning() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        border: Border.all(color: Colors.amber.shade400),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.amber.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Веб-версия (временные данные в памяти)',
              style: TextStyle(
                color: Colors.amber.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Форматирование суммы тенге
  String _formatAmount(double amount) {
    final absAmount = amount.abs();
    final formatter = absAmount.toStringAsFixed(0);
    
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

  /// Открытие экрана добавления транзакции
  Future<void> _openAddTransactionScreen([TransactionType? type]) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const AddTransactionScreen(),
      ),
    );

    // Если транзакция была добавлена, обновляем данные
    if (result == true) {
      _loadData();
    }
  }

  /// Открытие экрана списка всех транзакций
  Future<void> _openTransactionsListScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const TransactionsListScreen(),
      ),
    );

    // Обновляем данные при возврате
    _loadData();
  }

  /// Открытие экрана статистики
  Future<void> _openStatisticsScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const StatisticsScreen(),
      ),
    );

    // Обновляем данные при возврате
    _loadData();
  }

  /// Открытие экрана настроек
  Future<void> _openSettingsScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );

    // Обновляем данные при возврате
    _loadData();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Менің Бюджетім',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.green.shade700,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: _openSettingsScreen,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _refreshData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Информация о временной версии для веб
                    if (kIsWeb) _buildWebWarning(),
                    
                    // Карточка баланса
                    _buildBalanceCard(),
                    
                    const SizedBox(height: 24),
                    
                    // Кнопки действий
                    _buildActionButtons(),
                    
                    const SizedBox(height: 24),
                    
                    // Последние операции
                    _buildRecentTransactions(),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddTransactionScreen,
        backgroundColor: Colors.green.shade700,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  /// Карточка с текущим балансом
  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade700, Colors.green.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade200,
            offset: const Offset(0, 4),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'ТЕКУЩИЙ БАЛАНС',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatAmount(_balance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _balance >= 0 ? 'Положительный баланс' : 'Отрицательный баланс',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// Кнопки быстрых действий
  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _openAddTransactionScreen,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'Добавить доход',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _openAddTransactionScreen,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'Добавить расход',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // Кнопки навигации
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openTransactionsListScreen,
                icon: const Icon(Icons.list),
                label: const Text('Все операции'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openStatisticsScreen,
                icon: const Icon(Icons.analytics),
                label: const Text('Статистика'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Секция последних операций
  Widget _buildRecentTransactions() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Последние операции',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_recentTransactions.isNotEmpty)
                  TextButton(
                    onPressed: _openTransactionsListScreen,
                    child: const Text('Все'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _recentTransactions.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 48,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Пока нет операций',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Добавьте доход или расход',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: [
                      ..._recentTransactions.map((transaction) => 
                        _buildTransactionItem(transaction)
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _openTransactionsListScreen,
                              icon: const Icon(Icons.list),
                              label: const Text('Все операции'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _openStatisticsScreen,
                              icon: const Icon(Icons.analytics),
                              label: const Text('Статистика'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  /// Элемент транзакции в списке
  Widget _buildTransactionItem(Transaction transaction) {
    final category = _getCategoryById(transaction.categoryId);
    final categoryColor = category != null 
        ? Color(int.parse('0xFF${category.colorHex.substring(1)}'))
        : Colors.grey;

    final now = DateTime.now();
    final transactionDate = transaction.date;
    
    String timeLabel;
    if (DateFormat('yyyy-MM-dd').format(transactionDate) == 
        DateFormat('yyyy-MM-dd').format(now)) {
      timeLabel = 'Сегодня, ${DateFormat('HH:mm').format(transactionDate)}';
    } else {
      final difference = now.difference(transactionDate).inDays;
      if (difference == 1) {
        timeLabel = 'Вчера, ${DateFormat('HH:mm').format(transactionDate)}';
      } else {
        timeLabel = DateFormat('dd.MM.yyyy').format(transactionDate);
      }
    }

    return TransactionSwipeWidget(
      transaction: transaction,
      onDelete: () => _deleteTransaction(transaction),
      onEdit: () => _editTransaction(transaction),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Row(
          children: [
            // Иконка категории
            CircleAvatar(
              radius: 20,
              backgroundColor: categoryColor.withOpacity(0.1),
              child: Icon(
                _getCategoryIcon(category?.icon ?? 'more_horiz'),
                color: categoryColor,
                size: 18,
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Информация о транзакции
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.description.isNotEmpty 
                        ? transaction.description 
                        : category?.name ?? 'Без категории',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeLabel,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            
            // Сумма
            Text(
              transaction.formattedAmountWithSign,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: transaction.type == TransactionType.income
                    ? Colors.green.shade600
                    : Colors.red.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}