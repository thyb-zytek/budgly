import 'dart:async';

import 'package:budgly/src/core/auth/auth_exception.dart';
import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/models/user/user.dart';
import 'package:budgly/src/models/user/user_profile.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/auth/auth_service.dart';
import 'package:budgly/src/services/offline/local_cache.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:budgly/src/services/providers/supabase/user_profiles.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Owns the user's profile document and preferences (theme/locale/currency),
/// and orchestrates sign-out for *auth and sync* concerns only.
///
/// Deliberately does not know about accounts/categories/expenses/budgets:
/// invalidating their caches on logout is the composition root's job
/// (`ProfileSession.signOut`, which already has `ref` to reach every service
/// and every session notifier), not this service's. A previous version built
/// four other services here purely to call their `invalidateCache()` on
/// logout — a services-layer class orchestrating unrelated services is itself
/// a design smell, independent of the DI-fallback risk it also carried.
class ProfileService {
  final AuthService _authService;
  final UserProfileSupabase _profileSupabase;
  final LocalCache _localCache;
  final SyncQueue _syncQueue;
  final AnalyticsService _analytics;
  final SyncManager _syncManager;

  SharedPreferences? _prefs;
  Future<User?>? _loadProfileFuture;

  ProfileService({
    AuthService? authService,
    UserProfileSupabase? profileSupabase,
    required AnalyticsService analytics,
    required this._syncManager,
    required this._syncQueue,
    LocalCache? localCache,
  }) : _localCache = localCache ?? LocalCache(),
       // Production wires every dependency through Riverpod. The fallbacks
       // below only exist for tests that build the service directly.
       _authService = authService ?? AuthService(analytics: analytics),
       _profileSupabase = profileSupabase ?? UserProfileSupabase(),
       _analytics = analytics;

  void registerSyncHandler(SyncManager manager) {
    manager.registerHandler('user_profiles', _handlePendingSync);
  }

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// RL-01 §1.3 — fast local mirror of `UserProfile`'s preference fields,
  /// scoped to [uid] so a device shared by several accounts never paints one
  /// user's theme/locale/currency for another.
  ///
  /// [uid] is the Firebase uid of the locally signed-in user, or `null` when
  /// nobody is signed in (e.g. app restarted after sign-out): in that case
  /// system defaults are returned rather than whichever account's settings
  /// happened to be cached last, since there is no current owner for that
  /// cached data.
  Future<
    ({
      ThemeMode themeMode,
      Locale locale,
      String currency,
      int amountDecimalPlaces,
    })
  >
  loadLocalPreferences({required String? uid}) async {
    if (uid == null) {
      return (
        themeMode: ThemeMode.system,
        locale: const Locale(AppConstants.defaultLocale),
        currency: AppConstants.defaultCurrency,
        amountDecimalPlaces: 2,
      );
    }
    _prefs ??= await SharedPreferences.getInstance();
    final themeIndex = _prefs!.getInt(AppConstants.themeKey(uid));
    return (
      themeMode: themeIndex == null
          ? ThemeMode.system
          : ThemeMode.values[themeIndex.clamp(0, ThemeMode.values.length - 1)],
      locale: Locale(
        _prefs!.getString(AppConstants.localeKey(uid)) ??
            AppConstants.defaultLocale,
      ),
      currency:
          _prefs!.getString(AppConstants.currencyKey(uid)) ??
          AppConstants.defaultCurrency,
      amountDecimalPlaces:
          (_prefs!.getInt(AppConstants.amountDecimalPlacesKey(uid)) ?? 2).clamp(
            0,
            2,
          ),
    );
  }

  /// Write-through mirror of the profile-derived preferences into the local,
  /// per-[uid] cache used by [loadLocalPreferences] for the next cold start.
  /// Called whenever `ProfileSession` applies a fresh/cached `UserProfile`
  /// (not only from the explicit Preferences screen), so the local snapshot
  /// never lags behind what was last known about this user.
  Future<void> cacheLocalPreferences(
    String uid, {
    required ThemeMode themeMode,
    required Locale locale,
    required String currency,
    required int amountDecimalPlaces,
  }) async {
    _prefs ??= await SharedPreferences.getInstance();
    await Future.wait([
      _prefs!.setInt(AppConstants.themeKey(uid), themeMode.index),
      _prefs!.setString(AppConstants.localeKey(uid), locale.languageCode),
      _prefs!.setString(AppConstants.currencyKey(uid), currency),
      _prefs!.setInt(
        AppConstants.amountDecimalPlacesKey(uid),
        amountDecimalPlaces.clamp(0, 2),
      ),
    ]);
  }

  Future<User?> loadUserProfile({bool forceRefresh = false}) async {
    if (_loadProfileFuture != null) return _loadProfileFuture!;
    final user = _authService.firebaseUser;
    if (user == null) return null;
    final cached = await _localCache.loadProfile(user.uid);
    if (cached != null && !forceRefresh) {
      final localUser = User.fromFirebaseUser(user, profile: cached);
      unawaited(_refreshProfileFromRemote(user.uid));
      return localUser;
    }
    final future = _loadProfile(user.uid, cached);
    _loadProfileFuture = future;
    try {
      return await future;
    } finally {
      if (identical(_loadProfileFuture, future)) _loadProfileFuture = null;
    }
  }

  Future<User?> _loadProfile(String userId, UserProfile? cached) async {
    return _refreshProfileFromRemote(userId);
  }

  Future<User?> refreshFromServer() async {
    final user = await _authService.reloadCurrentUser().timeout(
      AppConstants.networkTimeout,
    );
    if (user == null) return null;
    if (user.profile != null) {
      await _localCache.saveProfile(user.id, user.profile!);
    }
    return user;
  }

  Future<User?> _refreshProfileFromRemote(String userId) async {
    if (_authService.firebaseUser?.uid != userId ||
        await _syncQueue.hasPending(type: 'user_profiles', entityId: userId)) {
      return null;
    }
    try {
      final user = await _authService.reloadCurrentUser().timeout(
        AppConstants.networkTimeout,
      );
      if (user != null &&
          _authService.firebaseUser?.uid == userId &&
          user.profile != null) {
        await _localCache.saveProfile(user.id, user.profile!);
      }
      return user;
    } on AuthenticationException catch (e) {
      const invalidatingCodes = {
        'user-disabled',
        'user-not-found',
        'user-token-expired',
        'invalid-user-token',
      };
      if (invalidatingCodes.contains(e.code)) await _authService.signOut();
      return null;
    } catch (e) {
      AppLogger.debug('Remote profile refresh unavailable: $e');
      return null;
    }
  }

  Future<User> updateUserName(User user, String name) async {
    final profile = user.profile;
    if (profile == null) return user;
    final updatedProfile = profile.copyWith(fullName: name);
    final updated = user.copyWith(profile: updatedProfile);
    await _enqueueProfileUpdate(user.id, {'full_name': name});
    await _mirrorProfile(user.id, updatedProfile);
    _analytics.track('profile_updated');
    return updated;
  }

  Future<User> changePassword(String oldPassword, String newPassword) =>
      _authService.changePassword(oldPassword, newPassword);

  Future<User> savePreferences(
    User user, {
    required ThemeMode themeMode,
    required Locale locale,
    required String currency,
    required int amountDecimalPlaces,
  }) async {
    final value = amountDecimalPlaces.clamp(0, 2);
    await cacheLocalPreferences(
      user.id,
      themeMode: themeMode,
      locale: locale,
      currency: currency,
      amountDecimalPlaces: value,
    );
    final profile = user.profile;
    if (profile == null) return user;
    final updatedProfile = profile.copyWith(
      themeMode: themeMode.name,
      language: locale.languageCode,
      currency: currency,
      amountDecimalPlaces: value,
    );
    final updated = user.copyWith(profile: updatedProfile);
    await _enqueueProfileUpdate(user.id, {
      'theme_mode': themeMode.name,
      'language': locale.languageCode,
      'currency': currency,
      'amount_decimal_places': value,
    });
    await _mirrorProfile(user.id, updatedProfile);
    _analytics.track('profile_updated');
    return updated;
  }

  Future<User> completeOnboarding(User user) async {
    final profile = user.profile;
    if (profile == null || profile.onboardingCompleted) return user;
    final updatedProfile = profile.copyWith(onboardingCompleted: true);
    final updated = user.copyWith(profile: updatedProfile);
    await _enqueueProfileUpdate(user.id, {'onboarding_completed': true});
    await _mirrorProfile(user.id, updatedProfile);
    _analytics.track('onboarding_completed');
    return updated;
  }

  /// Persists the patch in the durable queue (failures propagate: the caller
  /// must not present a change that was not persisted) and requests a replay.
  ///
  /// Successive patches for the same user are merged by [SyncQueue.enqueue],
  /// so `onboarding_completed` and a later preference change both reach the
  /// server.
  Future<void> _enqueueProfileUpdate(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    await _syncQueue.enqueue(
      id: 'profile:update:$userId',
      type: 'user_profiles',
      operation: 'update',
      payload: {'id': userId, ...updates},
    );
    unawaited(_syncManager.flush());
  }

  /// Best-effort cache mirror written *after* the durable queue entry.
  Future<void> _mirrorProfile(String userId, UserProfile profile) async {
    try {
      await _localCache.saveProfile(userId, profile);
    } catch (e, st) {
      AppLogger.error('Failed to mirror profile change to local cache', e, st);
    }
  }

  Future<void> _handlePendingSync(PendingSync operation) async {
    if (operation.operation != 'update') {
      throw StateError(
        'Unknown profile sync operation: ${operation.operation}',
      );
    }
    final payload = Map<String, dynamic>.from(operation.payload)..remove('id');
    await _profileSupabase
        .updateProfile(operation.payload['id'] as String, payload)
        .timeout(AppConstants.networkTimeout);
  }

  /// Bounded wait used before sign-out so the last local changes get a chance
  /// to reach the server while the session is still valid.
  static const _logoutFlushTimeout = Duration(seconds: 15);

  /// Replays the queue (ignoring backoff) and reports whether the current
  /// user has nothing left pending. Never throws on a slow or offline network.
  Future<bool> flushPendingMutations() async {
    try {
      await _syncManager.flush(forceRetry: true).timeout(_logoutFlushTimeout);
      await _syncManager.waitForIdle().timeout(_logoutFlushTimeout);
    } on TimeoutException {
      AppLogger.debug('Pending sync flush timed out before sign-out');
    }
    return await _pendingCountForCurrentUser() == 0;
  }

  Future<int> _pendingCountForCurrentUser() async =>
      (await _syncQueue.allForCurrentOwner()).length;

  /// Signs out **without** requiring an empty queue.
  ///
  /// A slow/offline network or an operation rejected by the server must not
  /// trap the user in the app. Nothing is lost: every queue entry carries the
  /// uid that created it, is only replayed for that user, and stays durable on
  /// the device until that user signs in again.
  Future<void> signOut() async {
    final synced = await flushPendingMutations();
    if (!synced) {
      final pending = await _pendingCountForCurrentUser();
      AppLogger.debug('Signing out with $pending pending sync operation(s)');
      _analytics.track('logout_with_pending_sync', {'count': pending});
    }
    await _authService.signOut();
  }
}
