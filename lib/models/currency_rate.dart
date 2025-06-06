/// Модель курса валюты
class CurrencyRate {
  final String code;      // USD, RUB, CNY, EUR, TRY
  final double rate;      // Курс к тенге
  final String flag;      // Флаг страны (emoji)
  final String name;      // Название валюты
  final DateTime updatedAt;

  const CurrencyRate({
    required this.code,
    required this.rate,
    required this.flag,
    required this.name,
    required this.updatedAt,
  });

  /// Создание из API ответа
  factory CurrencyRate.fromApiResponse(String code, Map<String, dynamic> apiResponse) {
    final rates = apiResponse['rates'] as Map<String, dynamic>;
    final kztRate = rates['KZT'] as num;
    
    // Для USD rate будет 509.67 (сколько тенге за 1 доллар)
    // Для других валют нужно пересчитать через кросс-курс
    double rateToKzt;
    
    if (code == 'USD') {
      rateToKzt = kztRate.toDouble();
    } else {
      // Если это не USD, нужно пересчитать через USD
      final codeRate = rates[code] as num;
      rateToKzt = kztRate / codeRate;
    }
    
    return CurrencyRate(
      code: code,
      rate: rateToKzt,
      flag: _getFlag(code),
      name: _getName(code),
      updatedAt: DateTime.now(),
    );
  }

  /// Получение флага страны
  static String _getFlag(String code) {
    switch (code) {
      case 'USD':
        return '🇺🇸';
      case 'RUB':
        return '🇷🇺';
      case 'EUR':
        return '🇪🇺';
      case 'CNY':
        return '🇨🇳';
      case 'TRY':
        return '🇹🇷';
      default:
        return '🏳️';
    }
  }

  /// Получение названия валюты
  static String _getName(String code) {
    switch (code) {
      case 'USD':
        return 'Доллар США';
      case 'RUB':
        return 'Российский рубль';
      case 'EUR':
        return 'Евро';
      case 'CNY':
        return 'Китайский юань';
      case 'TRY':
        return 'Турецкая лира';
      default:
        return code;
    }
  }

  /// Форматированный курс
  String get formattedRate {
    return rate.toStringAsFixed(2);
  }

  @override
  String toString() {
    return '$flag $code: $formattedRate ₸';
  }
}