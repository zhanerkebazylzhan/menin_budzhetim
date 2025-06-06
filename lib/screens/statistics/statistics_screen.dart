import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../models/enums.dart';
import '../../models/category.dart';
import '../../models/transaction.dart';
import '../../services/database_service.dart';
import '../../services/mock_database_service.dart';

/// Экран статистики и аналитики
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with TickerProviderStateMixin {
  late final dynamic _dbService;
  late final TabController _tabController;

  List<Transaction> _transactions = [];
  List<Category> _categories = [];
  bool _isLoading = true;
  FilterPeriod _selectedPeriod = FilterPeriod.month;

  // Статистические данные
  double _totalIncome = 0;
  double _totalExpense = 0;
  double _balance = 0;
  final Map<String, double> _expensesByCategory = {};
  final Map<String, double> _incomesByCategory = {};
  final List<FlSpot> _incomeSpots = [];
  final List<FlSpot> _expenseSpots = [];

  @override
  void initState() {
    super.initState();
    _dbService = kIsWeb ? MockDatabaseService() : DatabaseService();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Загрузка всех данных
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final transactions = await _dbService.getTransactions();
      final categories = await _dbService.getCategories();

      setState(() {
        _transactions = transactions;
        _categories = categories;
        _isLoading = false;
      });

      _calculateStatistics();
    } catch (e) {
      debugPrint('Ошибка загрузки данных: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Расчет статистики
  void _calculateStatistics() {
    final filteredTransactions = _getFilteredTransactions();
    
    // Основные суммы
    _totalIncome = 0;
    _totalExpense = 0;
    _expensesByCategory.clear();
    _incomesByCategory.clear();

    for (final transaction in filteredTransactions) {
      final category = _getCategoryById(transaction.categoryId);
      final categoryName = category?.name ?? 'Без категории';

      if (transaction.type == TransactionType.income) {
        _totalIncome += transaction.amount;
        _incomesByCategory[categoryName] = 
            (_incomesByCategory[categoryName] ?? 0) + transaction.amount;
      } else {
        _totalExpense += transaction.amount;
        _expensesByCategory[categoryName] = 
            (_expensesByCategory[categoryName] ?? 0) + transaction.amount;
      }
    }

    _balance = _totalIncome - _totalExpense;

    // Данные для графиков
    _calculateChartData(filteredTransactions);

    setState(() {});
  }

  /// Расчет данных для графиков
  void _calculateChartData(List<Transaction> transactions) {
    final now = DateTime.now();
    final startDate = _getStartDate(now);
    
    // Группируем транзакции по дням
    final incomeByDay = <String, double>{};
    final expenseByDay = <String, double>{};

    for (final transaction in transactions) {
      if (transaction.date.isAfter(startDate)) {
        final dayKey = DateFormat('yyyy-MM-dd').format(transaction.date);
        
        if (transaction.type == TransactionType.income) {
          incomeByDay[dayKey] = (incomeByDay[dayKey] ?? 0) + transaction.amount;
        } else {
          expenseByDay[dayKey] = (expenseByDay[dayKey] ?? 0) + transaction.amount;
        }
      }
    }

    // Создаем точки для графика
    _incomeSpots.clear();
    _expenseSpots.clear();

    final days = _getDaysInPeriod(startDate, now);
    
    for (int i = 0; i < days.length; i++) {
      final dayKey = DateFormat('yyyy-MM-dd').format(days[i]);
      _incomeSpots.add(FlSpot(i.toDouble(), incomeByDay[dayKey] ?? 0));
      _expenseSpots.add(FlSpot(i.toDouble(), expenseByDay[dayKey] ?? 0));
    }
  }

  /// Получение транзакций за выбранный период
  List<Transaction> _getFilteredTransactions() {
    final now = DateTime.now();
    final startDate = _getStartDate(now);
    
    return _transactions.where((transaction) => 
      transaction.date.isAfter(startDate)
    ).toList();
  }

  /// Получение начальной даты для периода
  DateTime _getStartDate(DateTime now) {
    switch (_selectedPeriod) {
      case FilterPeriod.week:
        return now.subtract(const Duration(days: 7));
      case FilterPeriod.month:
        return DateTime(now.year, now.month - 1, now.day);
      case FilterPeriod.year:
        return DateTime(now.year - 1, now.month, now.day);
      case FilterPeriod.all:
        return DateTime(2020, 1, 1);
    }
  }

  /// Получение списка дней в периоде
  List<DateTime> _getDaysInPeriod(DateTime start, DateTime end) {
    final days = <DateTime>[];
    var current = start;
    
    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      days.add(current);
      current = current.add(const Duration(days: 1));
    }
    
    return days;
  }

  /// Получение категории по ID
  Category? _getCategoryById(int categoryId) {
    try {
      return _categories.firstWhere((cat) => cat.id == categoryId);
    } catch (e) {
      return null;
    }
  }

  /// Форматирование суммы
  String _formatAmount(double amount) {
    return '${amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    )} ₸';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Статистика',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Обзор'),
            Tab(text: 'Расходы'),
            Tab(text: 'Доходы'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Селектор периода
                _buildPeriodSelector(),
                
                // Содержимое вкладок
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(),
                      _buildExpensesTab(),
                      _buildIncomeTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  /// Селектор периода
  Widget _buildPeriodSelector() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          const Text(
            'Период:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: FilterPeriod.values.map((period) => 
                  _buildPeriodChip(period)
                ).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Чип периода
  Widget _buildPeriodChip(FilterPeriod period) {
    final isSelected = _selectedPeriod == period;
    
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedPeriod = period;
          });
          _calculateStatistics();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.green.shade600 : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            period.displayName,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade700,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  /// Вкладка обзора
  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Карточки с основными метриками
          _buildMetricsCards(),
          
          const SizedBox(height: 24),
          
          // График доходов и расходов
          _buildLineChart(),
          
          const SizedBox(height: 24),
          
          // Топ категорий
          _buildTopCategories(),
        ],
      ),
    );
  }

  /// Карточки с метриками
  Widget _buildMetricsCards() {
    return Row(
      children: [
        Expanded(child: _buildMetricCard(
          'Доходы',
          _formatAmount(_totalIncome),
          Colors.green.shade600,
          Icons.arrow_upward,
        )),
        const SizedBox(width: 16),
        Expanded(child: _buildMetricCard(
          'Расходы',
          _formatAmount(_totalExpense),
          Colors.red.shade600,
          Icons.arrow_downward,
        )),
        const SizedBox(width: 16),
        Expanded(child: _buildMetricCard(
          'Баланс',
          _formatAmount(_balance),
          _balance >= 0 ? Colors.green.shade600 : Colors.red.shade600,
          _balance >= 0 ? Icons.trending_up : Icons.trending_down,
        )),
      ],
    );
  }

  /// Карточка метрики
  Widget _buildMetricCard(String title, String value, Color color, IconData icon) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Линейный график
  Widget _buildLineChart() {
    if (_incomeSpots.isEmpty && _expenseSpots.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(
            child: Text(
              'Нет данных для отображения графика',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Динамика доходов и расходов',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: _getChartInterval(),
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.shade300,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 60,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const Text('0');
                          return Text(
                            '${(value / 1000).toStringAsFixed(0)}к',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: _getBottomInterval(),
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= _getDaysCount()) return const Text('');
                          
                          final date = _getStartDate(DateTime.now()).add(Duration(days: index));
                          return Text(
                            DateFormat('dd').format(date),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    // Линия доходов
                    LineChartBarData(
                      spots: _incomeSpots,
                      isCurved: true,
                      color: Colors.green.shade600,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.green.shade600.withOpacity(0.1),
                      ),
                    ),
                    // Линия расходов
                    LineChartBarData(
                      spots: _expenseSpots,
                      isCurved: true,
                      color: Colors.red.shade600,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.red.shade600.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Доходы', Colors.green.shade600),
                const SizedBox(width: 24),
                _buildLegendItem('Расходы', Colors.red.shade600),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Элемент легенды
  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  /// Интервал для графика
  double _getChartInterval() {
    final max = [_totalIncome, _totalExpense].reduce((a, b) => a > b ? a : b);
    if (max == 0) return 1000;
    return (max / 5).roundToDouble();
  }

  /// Интервал для нижней оси
  double _getBottomInterval() {
    final daysCount = _getDaysCount();
    if (daysCount <= 7) return 1;
    if (daysCount <= 31) return 7;
    return 30;
  }

  /// Количество дней в периоде
  int _getDaysCount() {
    final now = DateTime.now();
    final start = _getStartDate(now);
    return now.difference(start).inDays;
  }

  /// Топ категорий
  Widget _buildTopCategories() {
    final topExpenses = _expensesByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final topIncomes = _incomesByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (topExpenses.isNotEmpty)
          Expanded(child: _buildTopCategoriesCard('Топ расходы', topExpenses, Colors.red.shade600)),
        if (topExpenses.isNotEmpty && topIncomes.isNotEmpty)
          const SizedBox(width: 16),
        if (topIncomes.isNotEmpty)
          Expanded(child: _buildTopCategoriesCard('Топ доходы', topIncomes, Colors.green.shade600)),
      ],
    );
  }

  /// Карточка топ категорий
  Widget _buildTopCategoriesCard(String title, List<MapEntry<String, double>> categories, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...categories.take(3).map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: const TextStyle(fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    _formatAmount(entry.value),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  /// Вкладка расходов
  Widget _buildExpensesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          if (_expensesByCategory.isNotEmpty)
            _buildPieChart(_expensesByCategory, 'Расходы по категориям', Colors.red)
          else
            _buildEmptyChart('Нет данных о расходах'),
        ],
      ),
    );
  }

  /// Вкладка доходов
  Widget _buildIncomeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          if (_incomesByCategory.isNotEmpty)
            _buildPieChart(_incomesByCategory, 'Доходы по категориям', Colors.green)
          else
            _buildEmptyChart('Нет данных о доходах'),
        ],
      ),
    );
  }

  /// Круговая диаграмма
  Widget _buildPieChart(Map<String, double> data, String title, MaterialColor colorScheme) {
    final total = data.values.fold(0.0, (sum, value) => sum + value);
    final entries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: entries.asMap().entries.map((entry) {
                    final index = entry.key;
                    final data = entry.value;
                    final percentage = (data.value / total * 100);
                    
                    return PieChartSectionData(
                      color: _getChartColor(colorScheme, index),
                      value: data.value,
                      title: '${percentage.toStringAsFixed(1)}%',
                      radius: 80,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Легенда
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: entries.asMap().entries.map((entry) {
                final index = entry.key;
                final data = entry.value;
                return _buildPieLegendItem(
                  data.key,
                  _formatAmount(data.value),
                  _getChartColor(colorScheme, index),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// Пустая диаграмма
  Widget _buildEmptyChart(String message) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(64.0),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.pie_chart_outline,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Цвет для диаграммы
  Color _getChartColor(MaterialColor colorScheme, int index) {
    final shades = [600, 500, 400, 700, 300, 800, 200, 900];
    return colorScheme[shades[index % shades.length]]!;
  }

  /// Элемент легенды для круговой диаграммы
  Widget _buildPieLegendItem(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: $value',
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}