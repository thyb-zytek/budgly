import 'package:app/src/services/preferences.dart';
import 'package:flutter/material.dart';


class PreferencesViewModel extends ChangeNotifier {
  final PreferencesService _preferencesService = PreferencesService();

  ThemeMode get mode => _preferencesService.themeMode;
  Locale get locale => _preferencesService.locale;
  String get currency => _preferencesService.currency;

  List<String> get supportedCurrencies =>
      PreferencesService.supportedCurrencies;

  Future<void> changeTheme(ThemeMode? themeMode) async {
    if (themeMode != null && themeMode != _preferencesService.themeMode) {
      await _preferencesService.setThemeMode(themeMode);
      notifyListeners();
    }
  }

  Future<void> changeLocale(Locale? locale) async {
    if (locale != null && locale != _preferencesService.locale) {
      await _preferencesService.setLocale(locale);
      notifyListeners();
    }
  }

  Future<void> changeCurrency(String? currency) async {
    if (currency != null && currency != _preferencesService.currency) {
      await _preferencesService.setCurrency(currency);
      notifyListeners();
    }
  }

  Future<void> loadInitialTheme() async {
    notifyListeners();
  }
}
