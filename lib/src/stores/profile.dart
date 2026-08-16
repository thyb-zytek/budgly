import 'package:flutter/material.dart';
import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/models/user/user.dart';

class ProfileStore extends ChangeNotifier {
  static ProfileStore? _instance;
  
  static ProfileStore get instance {
    _instance ??= ProfileStore._();
    return _instance!;
  }

  // État du Profil
  User? _currentUser;
  bool _isLoading = false;
  bool _hasLoaded = false;

  // État des Préférences
  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = const Locale(AppConstants.defaultLocale);
  String _currency = AppConstants.defaultCurrency;

  // Getters
  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
  String get currency => _currency;

  ProfileStore._();

  void setUser(User? user) {
    _currentUser = user;
    _hasLoaded = true;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setPreferences({ThemeMode? themeMode, Locale? locale, String? currency}) {
    if (themeMode != null) _themeMode = themeMode;
    if (locale != null) _locale = locale;
    if (currency != null) _currency = currency;
    notifyListeners();
  }

  void clear() {
    _currentUser = null;
    _hasLoaded = false;
    _themeMode = ThemeMode.system;
    _locale = const Locale(AppConstants.defaultLocale);
    _currency = AppConstants.defaultCurrency;
    notifyListeners();
  }
}