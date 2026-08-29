import 'dart:async';

import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/models/user/user.dart';
import 'package:budgly/src/core/auth/auth_exception.dart';
import 'package:budgly/src/services/auth/auth_service.dart';
import 'package:budgly/src/stores/profile.dart';
import 'package:budgly/src/services/providers/supabase/user_profiles.dart';
import 'package:budgly/src/services/offline/local_cache.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/categories/categories_service.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/services/budget/account_budgets_service.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
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
  final LocalCache _localCache = LocalCache();
  final SyncQueue _syncQueue = SyncQueue.instance;

  SharedPreferences? _prefs;
  Future<void>? _loadProfileFuture;

  static const String _themeKey = AppConstants.themeKey;
  static const String _localeKey = AppConstants.localeKey;
  static const String _currencyKey = AppConstants.currencyKey;
  static const String _amountDecimalPlacesKey = 'amount_decimal_places';

  ProfileService({
    ProfileStore? store,
    AuthService? authService,
    UserProfileSupabase? profileSupabase,
  })  : _store = store ?? ProfileStore.instance,
        _authService = authService ?? AuthService.instance,
        _profileSupabase = profileSupabase ?? UserProfileSupabase() {
    SyncManager.instance.registerHandler('user_profiles', _handlePendingSync);
  }

  ProfileService._() : this();

  User? get currentUser => _store.currentUser;
  ThemeMode get themeMode => _store.themeMode;
  Locale get locale => _store.locale;
  String get currency => _store.currency;
  int get amountDecimalPlaces => _store.amountDecimalPlaces;
  bool get onboardingCompleted => _store.currentUser?.profile?.onboardingCompleted ?? false;

  @override
  void addListener(VoidCallback listener) => _store.addListener(listener);
  @override
  void removeListener(VoidCallback listener) => _store.removeListener(listener);

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    await Future.wait([
      _loadLocalPreferences(),
      _hydrateCachedProfile(),
    ]);
  }

  Future<void> _hydrateCachedProfile() async {
    final firebaseUser = fb.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return;

    final cachedProfile = await _localCache.loadProfile(firebaseUser.uid);
    _store.setUser(
      User.fromFirebaseUser(firebaseUser, profile: cachedProfile),
    );
  }

  /// Refreshes the profile from the backend without making startup/navigation
  /// wait for the network. Cached state remains visible if the refresh fails.
  Future<void> refreshUserProfileInBackground() async {
    final userId = fb.FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    await _refreshProfileFromRemote(userId);
  }

  Future<void> _loadLocalPreferences() async {
    if (_prefs == null) return;

    final themeIndex = _prefs!.getInt(_themeKey);
    final theme = themeIndex != null
        ? ThemeMode.values[themeIndex.clamp(0, ThemeMode.values.length - 1)]
        : ThemeMode.system;

    final languageCode = _prefs!.getString(_localeKey) ?? AppConstants.defaultLocale;
    final currency = _prefs!.getString(_currencyKey) ?? AppConstants.defaultCurrency;
    final amountDecimalPlaces = _prefs!.getInt(_amountDecimalPlacesKey) ?? 2;

    _store.setPreferences(
      themeMode: theme,
      locale: Locale(languageCode),
      currency: currency,
      amountDecimalPlaces: amountDecimalPlaces,
    );
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
          amountDecimalPlaces: profile.amountDecimalPlaces,
        );

        await _prefs?.setInt(_themeKey, serverTheme.index);
        await _prefs?.setString(_localeKey, profile.language);
        await _prefs?.setString(_currencyKey, profile.currency);
        await _prefs?.setInt(_amountDecimalPlacesKey, profile.amountDecimalPlaces);
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
    final firebaseUser = fb.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return;

    final cachedProfile = await _localCache.loadProfile(firebaseUser.uid);
    if (cachedProfile != null) {
      final localUser = User.fromFirebaseUser(
        firebaseUser,
        profile: cachedProfile,
      );
      _store.setUser(localUser);

      // A cached profile is sufficient for routing and UI. A forced refresh
      // still happens, but never blocks the caller when local data exists.
      unawaited(_refreshProfileFromRemote(firebaseUser.uid));
      return;
    }

    await _refreshProfileFromRemote(firebaseUser.uid);
  }

  /// Forces a fresh fetch of the current user's profile from the backend.
  ///
  /// Unlike [loadUserProfile], this always performs a network round-trip (it is
  /// not short-circuited by a local cache or a pending sync operation) and it
  /// propagates failures to the caller so the UI can surface an offline or
  /// network error instead of silently keeping stale data.
  Future<void> refreshFromServer() async {
    final firebaseUser = fb.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return;

    final user = await _authService
        .reloadCurrentUser()
        .timeout(const Duration(seconds: 8));
    if (user == null) return;

    _store.setUser(user);
    if (user.profile != null) {
      await _localCache.saveProfile(user.id, user.profile!);
    }
    await syncPreferencesWithServer(user);
  }

  /// Replays every pending local mutation (accounts, profile, categories).
  ///
  /// Returns `true` when the whole queue was flushed (i.e. the device is
  /// online and all local mutations reached the server), `false` when at least
  /// one operation is still pending (offline / server unreachable).
  static Future<bool> flushPendingMutations() async {
    await SyncManager.instance.flush();
    return (await SyncQueue.instance.all()).isEmpty;
  }

  Future<void> _refreshProfileFromRemote(String userId) async {
    if (fb.FirebaseAuth.instance.currentUser?.uid != userId ||
        await _syncQueue.hasPending(type: 'user_profiles', entityId: userId)) {
      return;
    }
    try {
      final user = await _authService
          .reloadCurrentUser()
          .timeout(const Duration(seconds: 8));
      if (user != null && fb.FirebaseAuth.instance.currentUser?.uid == userId) {
        _store.setUser(user);
        if (user.profile != null) {
          await _localCache.saveProfile(user.id, user.profile!);
        }
        await syncPreferencesWithServer(user);
      }
    } on AuthenticationException catch (e) {
      const invalidatingCodes = {
        'user-disabled',
        'user-not-found',
        'user-token-expired',
        'invalid-user-token',
      };
      if (invalidatingCodes.contains(e.code)) {
        await signOut();
        return;
      }
      AppLogger.debug('Remote profile refresh unavailable: $e');
    } catch (e) {
      AppLogger.debug('Remote profile refresh unavailable: $e');
    }
  }

  Future<void> updateUserName(String name) async {
    final user = _store.currentUser;
    if (user == null || user.profile == null) return;

    final updatedProfile = user.profile!.copyWith(fullName: name);
    _store.setUser(user.copyWith(profile: updatedProfile));
    await _localCache.saveProfile(user.id, updatedProfile);
    AnalyticsService.instance.track('profile_updated');

    await _enqueueProfileUpdate({'full_name': name});
  }

  Future<void> changePassword(String oldPassword, String newPassword) async {
    final user = await _authService.changePassword(oldPassword, newPassword);
    _store.setUser(user);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_store.themeMode == mode) return;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setInt(_themeKey, mode.index);
    _store.setPreferences(themeMode: mode);
    await _queueProfilePreferences();
  }

  Future<void> setLocale(Locale newLocale) async {
    if (_store.locale.languageCode == newLocale.languageCode) return;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_localeKey, newLocale.languageCode);
    _store.setPreferences(locale: newLocale);
    await _queueProfilePreferences();
  }

  Future<void> setCurrency(String newCurrency) async {
    if (_store.currency == newCurrency) return;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_currencyKey, newCurrency);
    _store.setPreferences(currency: newCurrency);
    await _queueProfilePreferences();
  }

  Future<void> setAmountDecimalPlaces(int decimalPlaces) async {
    final value = decimalPlaces.clamp(0, 2);
    if (_store.amountDecimalPlaces == value) return;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setInt(_amountDecimalPlacesKey, value);
    _store.setPreferences(amountDecimalPlaces: value);
    await _queueProfilePreferences();
  }

  Future<void> _queueProfilePreferences() async {
    final user = _store.currentUser;
    if (user == null || user.profile == null) return;

    final updatedProfile = user.profile!.copyWith(
      themeMode: _store.themeMode.name,
      language: _store.locale.languageCode,
      currency: _store.currency,
      amountDecimalPlaces: _store.amountDecimalPlaces,
    );
    _store.setUser(user.copyWith(profile: updatedProfile));
    await _localCache.saveProfile(user.id, updatedProfile);
    AnalyticsService.instance.track('profile_updated');

    await _enqueueProfileUpdate({
      'theme_mode': _store.themeMode.name,
      'language': _store.locale.languageCode,
      'currency': _store.currency,
      'amount_decimal_places': _store.amountDecimalPlaces,
    });
  }

  Future<void> _enqueueProfileUpdate(Map<String, dynamic> updates) async {
    final user = _store.currentUser;
    if (user == null) return;
    await _syncQueue.enqueue(
      id: 'profile:update:${user.id}',
      type: 'user_profiles',
      operation: 'update',
      payload: {'id': user.id, ...updates},
    );
    unawaited(SyncManager.instance.flush());
  }

  Future<void> _handlePendingSync(PendingSync operation) async {
    if (operation.operation != 'update') {
      throw StateError(
        'Unknown profile sync operation: ${operation.operation}',
      );
    }
    final payload = Map<String, dynamic>.from(operation.payload)
      ..remove('id');
    await _profileSupabase.updateProfile(
      operation.payload['id'] as String,
      payload,
    ).timeout(const Duration(seconds: 8));
  }

  Future<void> completeOnboarding() async {
    final user = _store.currentUser;
    if (user == null || user.profile?.onboardingCompleted == true) return;

    final updatedProfile = user.profile!.copyWith(onboardingCompleted: true);
    _store.setUser(user.copyWith(profile: updatedProfile));
    await _localCache.saveProfile(user.id, updatedProfile);
    AnalyticsService.instance.track('onboarding_completed');

    await _enqueueProfileUpdate({'onboarding_completed': true});
  }

  Future<void> signOut() async {
    await _authService.signOut();
    AccountsService.instance.clearLocalAccounts();
    CategoriesService.instance.invalidateCache();
    ExpensesService.instance.invalidateCache();
    AccountBudgetsService.instance.invalidateCache();
    _store.clear();
  }
}
