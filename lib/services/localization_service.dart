import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalizationService extends Notifier<Locale> {
  @override
  Locale build() {
    loadLocale();
    return const Locale('en');
  }
  
  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('hi'),
    Locale('mr'),
  ];
  
  Future<void> loadLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final languageCode = prefs.getString('language_code') ?? 'en';
      state = Locale(languageCode);
    } catch (e) {
      debugPrint('Error loading locale: $e');
    }
  }
  
  Future<void> setLocale(Locale newLocale) async {
    if (!supportedLocales.contains(newLocale)) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language_code', newLocale.languageCode);
      state = newLocale;
    } catch (e) {
      debugPrint('Error setting locale: $e');
    }
  }
  
  String getLanguageName(String code) {
    switch (code) {
      case 'en':
        return 'English';
      case 'hi':
        return 'हिन्दी';
      case 'mr':
        return 'मराठी';
      default:
        return 'English';
    }
  }
}

final localizationProvider = NotifierProvider<LocalizationService, Locale>(LocalizationService.new);
