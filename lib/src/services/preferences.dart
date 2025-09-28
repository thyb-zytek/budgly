import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/src/services/auth.dart';
import 'package:app/src/services/supabase.dart';

class PreferencesService with ChangeNotifier {
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  
  static const String _themeKey = 'theme_mode';
  static const String _localeKey = 'app_locale';
  static const String _currencyKey = 'app_currency';
  
  final AuthService _authService = AuthService();
  static SharedPreferences? _prefs;
  
  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = const Locale('fr');
  String _currency = 'EUR';

  static const List<String> supportedCurrencies = ['EUR', 'USD', 'GBP'];
  
  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
  String get currency => _currency;
  
  PreferencesService._internal();
  
  static Future<void> init() async {
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
      await _instance._loadPreferences();
    }
  }
  
  Future<void> _loadPreferences() async {
    final themeIndex = _prefs!.getInt(_themeKey) ?? ThemeMode.system.index;
    _themeMode = ThemeMode.values[themeIndex];
    
    final languageCode = _prefs!.getString(_localeKey) ?? 'fr';
    _locale = Locale(languageCode);
    
    _currency = _prefs!.getString(_currencyKey) ?? 'EUR';
    
    await _syncWithServer();
    notifyListeners();
  }
  
  Future<void> _syncWithServer() async {
    if (_authService.currentUser != null) {
      try {
        final user = _authService.currentUser!;
        if (user.hasProfile) {
          final serverTheme = getThemeModeFromString(user.profile!.themeMode);
          if (serverTheme != _themeMode) {
            _themeMode = serverTheme;
            await _prefs!.setInt(_themeKey, _themeMode.index);
          }
          
          if (user.profile!.language != _locale.languageCode) {
            _locale = Locale(user.profile!.language);
            await _prefs!.setString(_localeKey, _locale.languageCode);
          }
          
          if (user.profile!.currency != _currency) {
            _currency = user.profile!.currency;
            await _prefs!.setString(_currencyKey, _currency);
          }
        }
      } catch (e) {
        print('Error syncing preferences with server: $e');
      }
    }
  }
  
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    if (_prefs == null) _prefs = await SharedPreferences.getInstance();
    
    _themeMode = mode;
    await _prefs!.setInt(_themeKey, mode.index);
    notifyListeners();
    
    await _updateServer();
  }
  
  ThemeMode getThemeModeFromString(String modeString) {
    return switch (modeString) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }
  
  Future<void> setThemeModeFromString(String modeString) async {
    await setThemeMode(getThemeModeFromString(modeString));
  }

  Future<void> setLocale(Locale newLocale) async {
    if (_locale.languageCode == newLocale.languageCode) return;
    if (_prefs == null) _prefs = await SharedPreferences.getInstance();
    
    _locale = newLocale;
    await _prefs!.setString(_localeKey, newLocale.languageCode);
    notifyListeners();
    
    await _updateServer();
  }
  
  Future<void> setLocaleFromLanguageCode(String languageCode) async {
    await setLocale(Locale(languageCode));
  }
  
  Future<void> setCurrency(String newCurrency) async {
    if (_currency == newCurrency) return;
    if (_prefs == null) _prefs = await SharedPreferences.getInstance();
    
    _currency = newCurrency;
    await _prefs!.setString(_currencyKey, newCurrency);
    notifyListeners();
    
    await _updateServer();
  }
  
  Future<void> _updateServer() async {
    if (_authService.currentUser != null) {
      try {
        await SupabaseService().updateProfile(_authService.currentUser!.id, {
          'theme_mode': _themeMode.toString().split('.').last,
          'language': _locale.languageCode,
          'currency': _currency,
        });
        await _authService.reloadCurrentUser();
      } catch (e) {
        await _loadPreferences();
        rethrow;
      }
    }
  }
  
  @override
  void dispose() {
    super.dispose();
  }
}
