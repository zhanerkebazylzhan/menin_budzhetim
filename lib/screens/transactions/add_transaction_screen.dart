import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:intl/intl.dart';

import '../../models/enums.dart';
import '../../models/category.dart';
import '../../models/transaction.dart';
import '../../services/database_service.dart';
import '../../services/mock_database_service.dart';
import '../../utils/constants.dart';

/// Экран добавления/редактирования транзакции
class AddTransactionScreen extends StatefulWidget {
  final Transaction? transaction;  // Для режима редактирования
  final Category? category;        // Категория для предзаполнения
  
  const AddTransactionScreen({
    super.key,
    this.transaction,
    this.category,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final TabController _tabController;
  late final dynamic _dbService;

  // Контроллеры формы
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  // Состояние формы
  TransactionType _selectedType = TransactionType.expense;
  Category? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  List<Category> _categories = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _dbService = kIsWeb ? MockDatabaseService() : DatabaseService();
    
    // Определяем начальный тип и вкладку
    if (widget.transaction != null) {
      // Режим редактирования
      _selectedType = widget.transaction!.type;
      _tabController = TabController(
        length: 2,
        vsync: this,
        initialIndex: _selectedType == TransactionType.expense ? 0 : 1,
      );
      
      // Заполняем поля
      _amountController.text = widget.transaction!.amount.toInt().toString();
      _descriptionController.text = widget.transaction!.description;
      _selectedDate = widget.transaction!.date;
    } else {
      // Режим добавления
      _tabController = TabController(length: 2, vsync: this);
    }
    
    _tabController.addListener(_onTabChanged);
    _loadCategories();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Обработка смены вкладки (Доход/Расход)
  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _selectedType = _tabController.index == 0 
            ? TransactionType.expense 
            : TransactionType.income;
        _selectedCategory = null; // Сбрасываем категорию при смене типа
      });
      _loadCategories();
    }
  }

  /// Загрузка категорий по типу
  Future<void> _loadCategories() async {
    try {
      final categories = await _dbService.getCategoriesByType(_selectedType);
      setState(() {
        _categories = categories;
        
        // В режиме редактирования выбираем нужную категорию
        if (widget.transaction != null && _categories.isNotEmpty) {
          _selectedCategory = _categories.firstWhere(
            (cat) => cat.id == widget.transaction!.categoryId,
            orElse: () => _categories.first,
          );
        } else if (_categories.isNotEmpty && _selectedCategory == null) {
          // Выбираем первую категорию по умолчанию
          _selectedCategory = _categories.first;
        }
      });
    } catch (e) {
      debugPrint('Ошибка загрузки категорий: $e');
    }
  }

  /// Валидация суммы
  String? _validateAmount(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите сумму';
    }

    final amount = double.tryParse(value.replaceAll(' ', ''));
    if (amount == null) {
      return 'Некорректная сумма';
    }

    if (amount < AppConstants.minAmount) {
      return 'Минимальная сумма: ${AppConstants.minAmount.toInt()} ₸';
    }

    if (amount > AppConstants.maxAmount) {
      return 'Максимальная сумма: ${AppConstants.maxAmount.toInt()} ₸';
    }

    return null;
  }

  /// Валидация описания
  String? _validateDescription(String? value) {
    if (value != null && value.length > AppConstants.maxDescriptionLength) {
      return 'Максимум ${AppConstants.maxDescriptionLength} символов';
    }
    return null;
  }

  /// Сохранение транзакции
  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategory == null) {
      _showErrorSnackBar('Выберите категорию');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final amount = double.parse(_amountController.text.replaceAll(' ', ''));
      final description = _descriptionController.text.trim();

      if (widget.transaction != null) {
        // Режим редактирования
        final updatedTransaction = widget.transaction!.copyWith(
          amount: amount,
          description: description.isEmpty ? _selectedCategory!.name : description,
          date: _selectedDate,
          categoryId: _selectedCategory!.id!,
          type: _selectedType,
          updatedAt: DateTime.now(),
        );

        await _dbService.updateTransaction(updatedTransaction);
        
        if (mounted) {
          Navigator.of(context).pop(true);
          _showSuccessSnackBar('Транзакция обновлена');
        }
      } else {
        // Режим добавления
        final transaction = Transaction(
          amount: amount,
          description: description.isEmpty ? _selectedCategory!.name : description,
          date: _selectedDate,
          categoryId: _selectedCategory!.id!,
          type: _selectedType,
          createdAt: DateTime.now(),
        );

        await _dbService.insertTransaction(transaction);

        if (mounted) {
          Navigator.of(context).pop(true);
          _showSuccessSnackBar('Транзакция добавлена');
        }
      }
    } catch (e) {
      debugPrint('Ошибка сохранения транзакции: $e');
      _showErrorSnackBar('Ошибка сохранения');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Показать SnackBar с ошибкой
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        action: SnackBarAction(
          label: 'ОК',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  /// Показать SnackBar с успехом
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade600,
      ),
    );
  }

  /// Выбор даты
  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: AppConstants.minDate,
      lastDate: AppConstants.maxDate,
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  /// Форматирование суммы при вводе
  void _formatAmount() {
    final text = _amountController.text.replaceAll(' ', '');
    if (text.isNotEmpty) {
      final amount = double.tryParse(text);
      if (amount != null) {
        // Простое форматирование без локализации
        final parts = amount.toInt().toString().split('').reversed.toList();
        final formatted = <String>[];
        
        for (int i = 0; i < parts.length; i++) {
          if (i % 3 == 0 && i != 0) {
            formatted.add(' ');
          }
          formatted.add(parts[i]);
        }
        
        final formattedText = formatted.reversed.join('');
        _amountController.value = TextEditingValue(
          text: formattedText,
          selection: TextSelection.collapsed(
            offset: formattedText.length,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          widget.transaction != null ? 'Редактировать операцию' : 'Добавить операцию',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: _selectedType == TransactionType.expense
            ? Colors.red.shade600
            : Colors.green.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _saveTransaction,
              child: const Text(
                'Сохранить',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
        bottom: widget.transaction == null
            ? TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: const [
                  Tab(text: 'Расход'),
                  Tab(text: 'Доход'),
                ],
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Поле суммы
                    _buildAmountField(),
                    
                    const SizedBox(height: 24),
                    
                    // Выбор категории
                    _buildCategorySelector(),
                    
                    const SizedBox(height: 24),
                    
                    // Поле описания
                    _buildDescriptionField(),
                    
                    const SizedBox(height: 24),
                    
                    // Выбор даты
                    _buildDateSelector(),
                    
                    const SizedBox(height: 32),
                    
                    // Кнопка сохранения
                    _buildSaveButton(),
                  ],
                ),
              ),
            ),
    );
  }

  /// Поле ввода суммы
  Widget _buildAmountField() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Сумма *',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d\s]')),
              ],
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                hintText: '0',
                suffixText: '₸',
                suffixStyle: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _selectedType == TransactionType.expense
                        ? Colors.red.shade600
                        : Colors.green.shade600,
                    width: 2,
                  ),
                ),
              ),
              validator: _validateAmount,
              onChanged: (_) => _formatAmount(),
            ),
          ],
        ),
      ),
    );
  }

  /// Селектор категории
  Widget _buildCategorySelector() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Категория *',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            if (_categories.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((category) => _buildCategoryChip(category)).toList(),
              ),
          ],
        ),
      ),
    );
  }

  /// Чип категории
  Widget _buildCategoryChip(Category category) {
    final isSelected = _selectedCategory?.id == category.id;
    final color = Color(int.parse('0xFF${category.colorHex.substring(1)}'));
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = category;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: color,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getIconData(category.icon),
              color: isSelected ? Colors.white : color,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              category.name,
              style: TextStyle(
                color: isSelected ? Colors.white : color,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Получение IconData по имени иконки
  IconData _getIconData(String iconName) {
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

  /// Поле описания
  Widget _buildDescriptionField() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Описание',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              maxLength: AppConstants.maxDescriptionLength,
              decoration: InputDecoration(
                hintText: _selectedCategory?.name ?? 'Введите описание...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _selectedType == TransactionType.expense
                        ? Colors.red.shade600
                        : Colors.green.shade600,
                    width: 2,
                  ),
                ),
              ),
              validator: _validateDescription,
            ),
          ],
        ),
      ),
    );
  }

  /// Селектор даты
  Widget _buildDateSelector() {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: _selectDate,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Дата',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('dd.MM.yyyy').format(_selectedDate),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey.shade400,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Кнопка сохранения
  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _saveTransaction,
      style: ElevatedButton.styleFrom(
        backgroundColor: _selectedType == TransactionType.expense
            ? Colors.red.shade600
            : Colors.green.shade600,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
      ),
      child: _isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : Text(
              widget.transaction != null 
                  ? 'Сохранить изменения'
                  : 'Добавить ${_selectedType.displayName.toLowerCase()}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }
}