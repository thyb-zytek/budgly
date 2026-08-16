import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/core/view_models/base_view_model.dart';
import 'package:budgly/src/services/profile.dart';
import 'package:flutter/material.dart';

class PreferencesViewModel extends BaseViewModel {
  final ProfileService _profileService = ProfileService.instance;

  PreferencesViewModel() {
    _profileService.addListener(_onServiceChanged);
  }

  void _onServiceChanged() {
    if (!isDisposed) notifyListeners();
  }

  ThemeMode get mode => _profileService.themeMode;
  Locale get locale => _profileService.locale;
  String get currency => _profileService.currency;
  List<String> get supportedCurrencies => AppConstants.supportedCurrencies;

  @override
  void dispose() {
    _profileService.removeListener(_onServiceChanged);
    super.dispose();
  }

  Future<void> changeTheme(ThemeMode? themeMode) async {
    if (themeMode != null) {
      await _profileService.setThemeMode(themeMode);
    }
  }

  Future<void> changeLocale(Locale? locale) async {
    if (locale != null) {
      await _profileService.setLocale(locale);
    }
  }

  Future<void> changeCurrency(String? currency) async {
    if (currency != null) {
      await _profileService.setCurrency(currency);
    }
  }
}