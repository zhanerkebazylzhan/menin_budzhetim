import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:intl/intl.dart';

import '../../models/user_profile.dart';
import '../../models/currency_rate.dart';
import '../../services/database_service.dart';
import '../../services/mock_database_service.dart';
import '../../services/currency_service.dart';

/// Экран настроек приложения
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final dynamic _dbService;
  
  // Контроллеры формы
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  
  // Состояние
  UserProfile? _userProfile;
  List<CurrencyRate> _currencyRates = [];
  bool _isLoading = false;
  bool _isLoadingRates = false;
  bool _isEditing = false;
  String _selectedCurrency = 'KZT';

  @override
  void initState() {
    super.initState();
    _dbService = kIsWeb ? MockDatabaseService() : DatabaseService();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  /// Загрузка профиля пользователя
  Future<void> _loadUserProfile() async {
    try {
      final profile = await _dbService.getUserProfile();
      if (profile != null) {
        setState(() {
          _userProfile = profile;
          _nameController.text = profile.name;
          _emailController.text = profile.email;
          _selectedCurrency = profile.currency;
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки профиля: $e');
    }
  }

  /// Сохранение профиля
  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();

    if (name.isEmpty && email.isEmpty) {
      _showSnackBar('Заполните хотя бы одно поле', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final profile = UserProfile(
        id: _userProfile?.id,
        name: name,
        email: email,
        currency: _selectedCurrency,
        createdAt: _userProfile?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _dbService.saveUserProfile(profile);
      
      setState(() {
        _userProfile = profile;
        _isEditing = false;
        _isLoading = false;
      });

      _showSnackBar('Профиль сохранен');
    } catch (e) {
      debugPrint('Ошибка сохранения профиля: $e');
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Ошибка сохранения', isError: true);
    }
  }

  /// Загрузка курсов валют
  Future<void> _loadCurrencyRates() async {
    setState(() {
      _isLoadingRates = true;
    });

    try {
      final rates = await CurrencyService.fetchAllRates();
      setState(() {
        _currencyRates = rates;
        _isLoadingRates = false;
      });
      _showSnackBar('Курсы обновлены');
    } catch (e) {
      debugPrint('Ошибка загрузки курсов: $e');
      setState(() {
        _isLoadingRates = false;
      });
      _showSnackBar('Не удалось загрузить курсы', isError: true);
    }
  }

  /// Сброс всех данных
  Future<void> _resetAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Сброс данных'),
        content: const Text(
          'Вы уверены, что хотите удалить все данные?\n\n'
          'Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Удалить все'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        await _dbService.resetAllData();
        
        setState(() {
          _userProfile = null;
          _nameController.clear();
          _emailController.clear();
          _isEditing = false;
          _isLoading = false;
        });

        _showSnackBar('Все данные удалены');
        
        // Возвращаемся на главный экран
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } catch (e) {
        debugPrint('Ошибка сброса данных: $e');
        setState(() {
          _isLoading = false;
        });
        _showSnackBar('Ошибка удаления данных', isError: true);
      }
    }
  }

  /// Показать SnackBar
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Настройки',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Профиль пользователя
                  _buildProfileSection(),
                  
                  const SizedBox(height: 24),
                  
                  // Валюта
                  _buildCurrencySection(),
                  
                  const SizedBox(height: 24),
                  
                  // Курсы валют
                  _buildExchangeRatesSection(),
                  
                  const SizedBox(height: 24),
                  
                  // Опасная зона
                  _buildDangerZone(),
                ],
              ),
            ),
    );
  }

  /// Секция профиля
  Widget _buildProfileSection() {
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
                  'Профиль',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (!_isEditing)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      setState(() {
                        _isEditing = true;
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (_isEditing) ...[
              // Форма редактирования
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Имя',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isEditing = false;
                        // Восстанавливаем старые значения
                        if (_userProfile != null) {
                          _nameController.text = _userProfile!.name;
                          _emailController.text = _userProfile!.email;
                        }
                      });
                    },
                    child: const Text('Отмена'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Сохранить'),
                  ),
                ],
              ),
            ] else ...[
              // Отображение профиля
              if (_userProfile != null) ...[
                _buildProfileField(
                  icon: Icons.person,
                  label: 'Имя',
                  value: _userProfile!.name.isNotEmpty 
                      ? _userProfile!.name 
                      : 'Не указано',
                ),
                const SizedBox(height: 12),
                _buildProfileField(
                  icon: Icons.email,
                  label: 'Email',
                  value: _userProfile!.email.isNotEmpty 
                      ? _userProfile!.email 
                      : 'Не указан',
                ),
              ] else ...[
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Профиль не создан',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isEditing = true;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Создать профиль'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// Поле профиля
  Widget _buildProfileField({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey.shade600, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Секция валюты
  Widget _buildCurrencySection() {
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
            const Text(
              'Валюта по умолчанию',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.monetization_on,
                    color: Colors.green.shade700,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Казахстанский тенге',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'KZT (₸)',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.check_circle,
                    color: Colors.green.shade700,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'В текущей версии поддерживается только тенге',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Секция курсов валют
  Widget _buildExchangeRatesSection() {
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
                  '💰 Актуальные курсы валют',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_isLoadingRates)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            
            if (_currencyRates.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '📅 Обновлено: ${DateFormat('dd.MM.yyyy, HH:mm').format(_currencyRates.first.updatedAt)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              
              // Курсы валют
              ..._currencyRates.map((rate) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  children: [
                    Text(
                      rate.flag,
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rate.code,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            rate.name,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${rate.formattedRate} ₸',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              )),
              
              const SizedBox(height: 8),
              Text(
                '📊 Источник: ExchangeRate-API',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ] else ...[
              const SizedBox(height: 24),
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.currency_exchange,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Курсы не загружены',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Кнопка обновления
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoadingRates ? null : _loadCurrencyRates,
                icon: const Icon(Icons.refresh),
                label: const Text('🔄 Обновить курсы'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Опасная зона
  Widget _buildDangerZone() {
    return Card(
      elevation: 2,
      color: Colors.red.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning,
                  color: Colors.red.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  'Опасная зона',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Сброс всех данных приложения',
              style: TextStyle(
                fontSize: 14,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Будут удалены все транзакции, профиль и пользовательские настройки. '
              'Это действие нельзя отменить!',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _resetAllData,
                icon: const Icon(Icons.delete_forever),
                label: const Text('Удалить все данные'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}