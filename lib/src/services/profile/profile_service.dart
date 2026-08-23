import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/models/user/user.dart';
import 'package:budgly/src/services/auth/auth_service.dart';
import 'package:budgly/src/stores/profile.dart';
import 'package:budgly/src/services/providers/supabase/user_profiles.dart';
import 'package:budgly/src/services/session/session_data_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class ProfileService implements Listenable {
  static ProfileService? _instance;

  static ProfileService get instance {
    _instance ??= ProfileService._();
    return _instance!;
  }

  final ProfileStore _store;
  final AuthService _authService;
  final UserProfileSupabase _profileSupabase;
  final SessionDataService _sessionDataService;

  SharedPreferences? _prefs;
  Future<void>? _loadProfileFuture;
  int _sessionGeneration = 0;

  static const String _themeKey = AppConstants.themeKey;
  static const String _localeKey = AppConstants.localeKey;
  static const String _currencyKey = AppConstants.currencyKey;

  ProfileService({
    ProfileStore? store,
    AuthService? authService,
    UserProfileSupabase? profileSupabase,
    SessionDataService? sessionDataService,
  })  : _store = store ?? ProfileStore.instance,
        _authService = authService ?? AuthService.instance,
        _profileSupabase = profileSupabase ?? UserProfileSupabase(),
        _sessionDataService = sessionDataService ?? SessionDataService.instance;

  ProfileService._() : this();

  User? get currentUser => _store.currentUser;
  ThemeMode get themeMode => _store.themeMode;
  Locale get locale => _store.locale;
  String get currency => _store.currency;
  bool get onboardingCompleted => _store.currentUser?.profile?.onboardingCompleted ?? false;
  bool get isLoading => _store.isLoading;

  @override
  void addListener(VoidCallback listener) => _store.addListener(listener);
  @override
  void removeListener(VoidCallback listener) => _store.removeListener(listener);

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _loadLocalPreferences();
  }

  Future<void> _loadLocalPreferences() async {
    if (_prefs == null) return;

    final themeIndex = _prefs!.getInt(_themeKey);
    final theme = themeIndex != null
        ? ThemeMode.values[themeIndex.clamp(0, ThemeMode.values.length - 1)]
        : ThemeMode.system;

    final languageCode = _prefs!.getString(_localeKey) ?? AppConstants.defaultLocale;
    final currency = _prefs!.getString(_currencyKey) ?? AppConstants.defaultCurrency;

    _store.setPreferences(themeMode: theme, locale: Locale(languageCode), currency: currency);
  }

  Future<void> syncPreferencesWithServer(User user) async {
    if (user.hasProfile) {
      try {
        final profile = user.profile!;
        final serverTheme = _getThemeModeFromString(profile.themeMode);

        _store.setPreferences(
          themeMode: serverTheme,
          locale: Locale(profile.language),
          currency: profile.currency,
        );

        await _prefs?.setInt(_themeKey, serverTheme.index);
        await _prefs?.setString(_localeKey, profile.language);
        await _prefs?.setString(_currencyKey, profile.currency);
      } catch (e) {
        AppLogger.error('Error syncing preferences with server: $e', e);
      }
    }
  }

  ThemeMode _getThemeModeFromString(String modeString) {
    return switch (modeString) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> loadUserProfile({bool forceRefresh = false}) async {
    if (_store.hasLoaded && !forceRefresh && _store.currentUser != null) return;
    if (_loadProfileFuture != null) return _loadProfileFuture!;

    final future = _loadUserProfile();
    _loadProfileFuture = future;
    try {
      await future;
    } finally {
      if (identical(_loadProfileFuture, future)) _loadProfileFuture = null;
    }
  }

  Future<void> _loadUserProfile() async {
    final generation = _sessionGeneration;
    _store.beginLoading();
    try {
      final user = await _authService.reloadCurrentUser();
      if (user != null && generation == _sessionGeneration) {
        _store.setUser(user);
        await syncPreferencesWithServer(user);
      }
    } catch (e) {
      AppLogger.error('Failed to load user profile', e);
    } finally {
      _store.endLoading();
    }
  }

  Future<void> updateUserName(String name) async {
    _store.setLoading(true);
    try {
      await _authService.onChangeName(name);
      final user = await _authService.reloadCurrentUser();
      if (user != null) _store.setUser(user);
    } finally {
      _store.setLoading(false);
    }
  }

  Future<void> changePassword(String oldPassword, String newPassword) async {
    _store.setLoading(true);
    try {
      final user = await _authService.changePassword(oldPassword, newPassword);
      _store.setUser(user);
    } finally {
      _store.setLoading(false);
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_store.themeMode == mode) return;
    _prefs ??= await SharedPreferences.getInstance();

    await _prefs!.setInt(_themeKey, mode.index);
    _store.setPreferences(themeMode: mode);
    await _updateServerProfile();
  }

  Future<void> setLocale(Locale newLocale) async {
    if (_store.locale.languageCode == newLocale.languageCode) return;
    _prefs ??= await SharedPreferences.getInstance();

    await _prefs!.setString(_localeKey, newLocale.languageCode);
    _store.setPreferences(locale: newLocale);
    await _updateServerProfile();
  }

  Future<void> setCurrency(String newCurrency) async {
    if (_store.currency == newCurrency) return;
    _prefs ??= await SharedPreferences.getInstance();

    await _prefs!.setString(_currencyKey, newCurrency);
    _store.setPreferences(currency: newCurrency);
    await _updateServerProfile();
  }

  Future<void> _updateServerProfile() async {
    final user = _store.currentUser;
    if (user != null) {
      try {
        await _profileSupabase.updateProfile(user.id, {
          'theme_mode': _store.themeMode.toString().split('.').last,
          'language': _store.locale.languageCode,
          'currency': _store.currency,
        });
        final updatedUser = await _authService.reloadCurrentUser();
        if (updatedUser != null) _store.setUser(updatedUser);
      } catch (e) {
        await _loadLocalPreferences();
        rethrow;
      }
    }
  }

  Future<void> completeOnboarding() async {
    final user = _store.currentUser;
    if (user == null || user.profile?.onboardingCompleted == true) return;

    await _profileSupabase.updateProfile(user.id, {
      'onboarding_completed': true,
    });

    final updatedUser = await _authService.reloadCurrentUser();
    if (updatedUser != null) _store.setUser(updatedUser);
  }

  Future<void> signOut() async {
    _store.setLoading(true);
    try {
      await _authService.signOut();
      _sessionGeneration++;
      _sessionDataService.clearUserData();
      _store.clear();
    } finally {
      _store.setLoading(false);
    }
  }
}
