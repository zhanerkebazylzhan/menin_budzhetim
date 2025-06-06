import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/currency_rate.dart';

/// Сервис для получения курсов валют
class CurrencyService {
  static const String baseUrl = 'https://api.exchangerate-api.com/v4/latest';
  static const List<String> supportedCurrencies = ['USD', 'RUB', 'CNY', 'EUR', 'TRY'];
  static const String cacheKey = 'cached_currency_rates';
  static const String cacheTimeKey = 'cached_currency_rates_time';
  
  /// Получить все курсы валют к тенге
  static Future<List<CurrencyRate>> fetchAllRates() async {
    final rates = <CurrencyRate>[];
    
    try {
      // Для каждой валюты отправляем отдельный запрос
      for (final currency in supportedCurrencies) {
        final rate = await _fetchSingleRate(currency);
        if (rate != null) {
          rates.add(rate);
        }
      }
      
      debugPrint('💱 Загружено курсов: ${rates.length}');
      
      // Сохраняем в кэш
      if (rates.isNotEmpty) {
        await saveRatesToCache(rates);
      }
      
      return rates;
    } catch (e) {
      debugPrint('❌ Ошибка загрузки курсов: $e');
      
      // Пробуем загрузить из кэша
      final cachedRates = await loadRatesFromCache();
      if (cachedRates != null && cachedRates.isNotEmpty) {
        debugPrint('📱 Загружены курсы из кэша');
        return cachedRates;
      }
      
      throw Exception('Не удалось загрузить курсы валют');
    }
  }
  
  /// Получить курс одной валюты к тенге
  static Future<CurrencyRate?> _fetchSingleRate(String currencyCode) async {
    try {
      final url = Uri.parse('$baseUrl/$currencyCode');
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Таймаут при загрузке курса $currencyCode');
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        
        // Проверяем, есть ли курс KZT в ответе
        final rates = data['rates'] as Map<String, dynamic>?;
        if (rates != null && rates.containsKey('KZT')) {
          final rate = CurrencyRate.fromApiResponse(currencyCode, data);
          debugPrint('✅ $currencyCode: ${rate.formattedRate} ₸');
          return rate;
        } else {
          debugPrint('⚠️ Нет курса KZT для $currencyCode');
          return null;
        }
      } else {
        debugPrint('❌ Ошибка HTTP ${response.statusCode} для $currencyCode');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Ошибка загрузки курса $currencyCode: $e');
      return null;
    }
  }
  
  /// Сохранить курсы в SharedPreferences для офлайн доступа
  static Future<void> saveRatesToCache(List<CurrencyRate> rates) async {
    try {
      // SharedPreferences не работает корректно в веб-версии
      if (kIsWeb) {
        debugPrint('⚠️ Кэширование недоступно в веб-версии');
        return;
      }
      
      final prefs = await SharedPreferences.getInstance();
      
      // Подготавливаем данные для сохранения
      final ratesData = rates.map((rate) => {
        'code': rate.code,
        'rate': rate.rate,
        'flag': rate.flag,
        'name': rate.name,
        'updatedAt': rate.updatedAt.toIso8601String(),
      }).toList();
      
      // Сохраняем как JSON строку
      final jsonString = json.encode(ratesData);
      await prefs.setString(cacheKey, jsonString);
      
      // Сохраняем время кэширования
      await prefs.setString(cacheTimeKey, DateTime.now().toIso8601String());
      
      debugPrint('💾 Курсы сохранены в кэш');
    } catch (e) {
      debugPrint('❌ Ошибка сохранения в кэш: $e');
    }
  }
  
  /// Загрузить курсы из кэша
  static Future<List<CurrencyRate>?> loadRatesFromCache() async {
    try {
      // SharedPreferences не работает корректно в веб-версии
      if (kIsWeb) {
        return null;
      }
      
      final prefs = await SharedPreferences.getInstance();
      
      // Получаем данные из кэша
      final jsonString = prefs.getString(cacheKey);
      if (jsonString == null) {
        return null;
      }
      
      // Парсим JSON
      final ratesData = json.decode(jsonString) as List<dynamic>;
      
      // Преобразуем в объекты CurrencyRate
      final rates = ratesData.map((data) => CurrencyRate(
        code: data['code'] as String,
        rate: (data['rate'] as num).toDouble(),
        flag: data['flag'] as String,
        name: data['name'] as String,
        updatedAt: DateTime.parse(data['updatedAt'] as String),
      )).toList();
      
      // Проверяем время кэша
      final cacheTimeString = prefs.getString(cacheTimeKey);
      if (cacheTimeString != null) {
        final cacheTime = DateTime.parse(cacheTimeString);
        final age = DateTime.now().difference(cacheTime);
        debugPrint('📱 Возраст кэша: ${age.inMinutes} минут');
      }
      
      return rates;
    } catch (e) {
      debugPrint('❌ Ошибка загрузки из кэша: $e');
      return null;
    }
  }
  
  /// Проверить актуальность кэша
  static Future<bool> isCacheValid() async {
    try {
      if (kIsWeb) {
        return false;
      }
      
      final prefs = await SharedPreferences.getInstance();
      final cacheTimeString = prefs.getString(cacheTimeKey);
      
      if (cacheTimeString == null) {
        return false;
      }
      
      final cacheTime = DateTime.parse(cacheTimeString);
      final age = DateTime.now().difference(cacheTime);
      
      // Считаем кэш валидным если ему меньше 24 часов
      return age.inHours < 24;
    } catch (e) {
      return false;
    }
  }
  
  /// Очистить кэш
  static Future<void> clearCache() async {
    try {
      if (kIsWeb) {
        return;
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(cacheKey);
      await prefs.remove(cacheTimeKey);
      debugPrint('🧹 Кэш курсов очищен');
    } catch (e) {
      debugPrint('❌ Ошибка очистки кэша: $e');
    }
  }
}