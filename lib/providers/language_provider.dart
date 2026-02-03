import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  Locale _currentLocale = const Locale('th', 'TH');

  Locale get currentLocale => _currentLocale;

  LanguageProvider() {
    _loadSavedLanguage();
  }

  Future<void> _loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('language_code') ?? 'th';
    final countryCode = prefs.getString('country_code') ?? 'TH';
    
    _currentLocale = Locale(languageCode, countryCode);
    notifyListeners();
  }

  Future<void> changeLanguage(Locale locale) async {
    if (_currentLocale == locale) return;

    _currentLocale = locale;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', locale.languageCode);
    await prefs.setString('country_code', locale.countryCode ?? '');
  }

  Future<void> setThai() async {
    await changeLanguage(const Locale('th', 'TH'));
  }

  Future<void> setEnglish() async {
    await changeLanguage(const Locale('en', 'US'));
  }

  bool get isThai => _currentLocale.languageCode == 'th';
  bool get isEnglish => _currentLocale.languageCode == 'en';
}
