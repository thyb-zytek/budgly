import 'dart:async';

import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/core/dependencies/backend_clients_provider.dart';
import 'package:budgly/src/services/providers/supabase/user_profiles.dart';
import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/models/user/user.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:budgly/src/services/analytics/analytics_service_provider.dart';
import 'package:budgly/src/services/auth/auth_service_provider.dart';
import 'package:budgly/src/services/offline/local_cache_provider.dart';
import 'package:budgly/src/services/offline/sync_manager_provider.dart';
import 'package:budgly/src/state/accounts_provider.dart';
import 'package:budgly/src/state/categories_provider.dart';
import 'package:budgly/src/state/expenses_provider.dart';
import 'package:budgly/src/state/account_budgets_provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profile_providers.g.dart';

@Riverpod(keepAlive: true)
ProfileService profileService(Ref ref) {
  final authService = ref.watch(authServiceProvider);
  return ProfileService(
    authService: authService,
    profileSupabase: UserProfileSupabase(
      client: ref.watch(supabaseClientProvider),
      auth: ref.watch(firebaseAuthClientProvider),
    ),
    analytics: ref.watch(analyticsServiceProvider),
    syncManager: ref.watch(syncManagerProvider),
    syncQueue: ref.watch(syncQueueProvider),
    localCache: ref.watch(localCacheProvider),
  );
}

class ProfileSessionState {
  const ProfileSessionState({
    required this.currentUser,
    required this.hasLoaded,
    required this.themeMode,
    required this.locale,
    required this.currency,
    required this.amountDecimalPlaces,
  });
  final User? currentUser;
  final bool hasLoaded;
  final ThemeMode themeMode;
  final Locale locale;
  final String currency;
  final int amountDecimalPlaces;
}

@Riverpod(keepAlive: true)
class ProfileSession extends _$ProfileSession {
  @override
  ProfileSessionState build() {
    final authService = ref.read(authServiceProvider);
    // Initialize from Firebase's synchronous currentUser before subscribing so
    // the stream's initial event is not mistaken for a new session transition.
    _observedAuthUserId = authService.firebaseUser?.uid;
    // A non-null synchronous currentUser establishes the initial identity.
    // When it is null, the first stream event is the authoritative startup
    // state and must not invalidate work that has not yet started for a user.
    _hasObservedAuthState = _observedAuthUserId != null;
    final authSubscription = authService.authStateChanges.listen(
      _handleAuthStateChanged,
    );
    ref.onDispose(authSubscription.cancel);

    unawaited(_initialize());
    return const ProfileSessionState(
      currentUser: null,
      hasLoaded: false,
      themeMode: ThemeMode.system,
      locale: Locale(AppConstants.defaultLocale),
      currency: AppConstants.defaultCurrency,
      amountDecimalPlaces: 2,
    );
  }

  int _sessionRevision = 0;
  bool _signOutInProgress = false;
  bool _hasObservedAuthState = false;
  String? _observedAuthUserId;

  void _handleAuthStateChanged(fb.User? firebaseUser) {
    if (!ref.mounted) return;

    final nextUserId = firebaseUser?.uid;
    if (!_hasObservedAuthState) {
      // Firebase's initial stream event can restore a persisted login after
      // currentUser was synchronously observed as null. Treat that as startup,
      // not logout/login churn. The explicit load is guarded by the same UID
      // and session revision contracts as the login path.
      _hasObservedAuthState = true;
      _observedAuthUserId = nextUserId;
      if (nextUserId != null) unawaited(_loadAfterAuthIdentityChange());
      return;
    }

    final previousUserId = _observedAuthUserId;
    _observedAuthUserId = nextUserId;

    // Keep the observed identity up to date during an explicit sign-out;
    // ProfileSession.signOut() already performs the actual reset.
    if (_signOutInProgress || previousUserId == nextUserId) return;

    // Only a previously authenticated identity can own stale in-memory data.
    // The ordinary null -> user login path is loaded by the auth/login flow;
    // a direct user-A -> user-B transition must reset and load the new user.
    if (previousUserId != null) {
      _resetSession();
      if (nextUserId != null) unawaited(_loadAfterAuthIdentityChange());
    }
  }

  Future<void> _loadAfterAuthIdentityChange() async {
    try {
      await load();
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to load profile after Firebase identity change',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _initialize() async {
    final revision = ++_sessionRevision;
    try {
      final service = ref.read(profileServiceProvider);
      final authUserId = ref.read(authServiceProvider).firebaseUser?.uid;
      final prefs = await service.loadLocalPreferences(uid: authUserId);
      if (!_isCurrentSession(revision, authUserId)) return;
      state = ProfileSessionState(
        currentUser: state.currentUser,
        hasLoaded: state.hasLoaded,
        themeMode: prefs.themeMode,
        locale: prefs.locale,
        currency: prefs.currency,
        amountDecimalPlaces: prefs.amountDecimalPlaces,
      );
      final user = await service.loadUserProfile();
      if (!_isCurrentSession(revision, authUserId)) return;
      if (user != null) {
        await _preloadReferenceData(user.id);
        if (!_isCurrentSession(revision, authUserId)) return;
        _setUser(user);
      }
      unawaited(_refreshInBackground(revision, authUserId));
    } catch (e, st) {
      AppLogger.error('Failed to initialize profile session', e, st);
    }
  }

  Future<void> _refreshInBackground(int revision, String? authUserId) async {
    final user = await ref.read(profileServiceProvider).refreshFromServer();
    if (!_isCurrentSession(revision, authUserId)) return;
    if (user != null) _setUser(user);
  }

  bool _isCurrentSession(int revision, String? authUserId) {
    if (!ref.mounted || revision != _sessionRevision) return false;
    return ref.read(authServiceProvider).firebaseUser?.uid == authUserId;
  }

  /// Loads the current authenticated profile and its required reference data.
  ///
  /// The returned future is the synchronization barrier for callers such as
  /// login: when it completes after a successful load, `state` already contains
  /// the loaded profile and reference sessions are initialized. It deliberately
  /// returns early when there is no authenticated user or when the session has
  /// become stale; `_sessionRevision` remains the stale-result guard until the
  /// broader session lifecycle refactor is completed.
  Future<void> load({bool forceRefresh = false}) async {
    final revision = _sessionRevision;
    final authUserId = ref.read(authServiceProvider).firebaseUser?.uid;
    final user = await ref
        .read(profileServiceProvider)
        .loadUserProfile(forceRefresh: forceRefresh);
    if (!_isCurrentSession(revision, authUserId) || user == null) return;
    await _preloadReferenceData(user.id, forceRefresh: forceRefresh);
    if (_isCurrentSession(revision, authUserId)) _setUser(user);
  }

  /// Loads the reference data required by every expense-oriented screen.
  ///
  /// Accounts and categories belong to the signed-in profile/session and must
  /// be ready before navigation can expose screens that depend on them.
  /// Expenses deliberately do not belong here: they are period/screen data
  /// and are loaded when Overview is entered.
  Future<void> _preloadReferenceData(
    String userId, {
    bool forceRefresh = false,
  }) async {
    if (!_isCurrentSession(_sessionRevision, userId)) return;

    final accountsNotifier = ref.read(accountsSessionProvider.notifier);
    await accountsNotifier.load(forceRefresh: forceRefresh);
    if (!_isCurrentSession(_sessionRevision, userId)) return;

    final accountIds = ref
        .read(accountsSessionProvider)
        .accounts
        .map((account) => account.id)
        .whereType<String>()
        .toList(growable: false);

    await Future.wait(
      accountIds.map(
        (accountId) => ref
            .read(categoriesSessionProvider.notifier)
            .load(accountId, forceRefresh: forceRefresh),
      ),
    );
  }

  Future<void> refresh() async {
    final revision = _sessionRevision;
    final authUserId = ref.read(authServiceProvider).firebaseUser?.uid;
    final user = await ref
        .read(profileServiceProvider)
        .refreshFromServer(rethrowErrors: true);
    if (_isCurrentSession(revision, authUserId) && user != null) _setUser(user);
  }

  Future<void> updateName(String name) async {
    final user = state.currentUser;
    if (user == null) return;
    final revision = _sessionRevision;
    final uid = user.id;
    final updated = await ref
        .read(profileServiceProvider)
        .updateUserName(user, name);
    if (_isCurrentSession(revision, uid)) _setUser(updated);
  }

  Future<void> changePassword(String oldPassword, String newPassword) async {
    final revision = _sessionRevision;
    final uid = ref.read(authServiceProvider).firebaseUser?.uid;
    final updated = await ref
        .read(profileServiceProvider)
        .changePassword(oldPassword, newPassword);
    if (_isCurrentSession(revision, uid) && updated.id == uid) {
      _setUser(updated);
    }
  }

  Future<void> savePreferences({
    ThemeMode? themeMode,
    Locale? locale,
    String? currency,
    int? amountDecimalPlaces,
  }) async {
    final revision = _sessionRevision;
    final uid = ref.read(authServiceProvider).firebaseUser?.uid;
    final nextTheme = themeMode ?? state.themeMode;
    final nextLocale = locale ?? state.locale;
    final nextCurrency = currency ?? state.currency;
    final nextPlaces = amountDecimalPlaces ?? state.amountDecimalPlaces;
    state = ProfileSessionState(
      currentUser: state.currentUser,
      hasLoaded: state.hasLoaded,
      themeMode: nextTheme,
      locale: nextLocale,
      currency: nextCurrency,
      amountDecimalPlaces: nextPlaces.clamp(0, 2),
    );
    final user = state.currentUser;
    if (user != null) {
      final updated = await ref
          .read(profileServiceProvider)
          .savePreferences(
            user,
            themeMode: nextTheme,
            locale: nextLocale,
            currency: nextCurrency,
            amountDecimalPlaces: nextPlaces,
          );
      if (_isCurrentSession(revision, uid) && updated.id == uid) {
        _setUser(updated);
      }
    }
  }

  Future<void> completeOnboarding() async {
    final user = state.currentUser;
    if (user == null) return;
    final revision = _sessionRevision;
    final uid = user.id;
    final updated = await ref
        .read(profileServiceProvider)
        .completeOnboarding(user);
    if (_isCurrentSession(revision, uid)) _setUser(updated);
  }

  Future<void> signOut() async {
    if (_signOutInProgress) return;

    _signOutInProgress = true;
    _resetSession();
    try {
      await ref.read(profileServiceProvider).signOut();
    } finally {
      _signOutInProgress = false;
    }
  }

  void _resetSession() {
    if (!ref.mounted) return;
    ++_sessionRevision;
    state = const ProfileSessionState(
      currentUser: null,
      hasLoaded: false,
      themeMode: ThemeMode.system,
      locale: Locale(AppConstants.defaultLocale),
      currency: AppConstants.defaultCurrency,
      amountDecimalPlaces: 2,
    );
    // Each session's clear() already invalidates its own service's cache
    // (see AccountsSession/CategoriesSession/ExpensesSession/
    // AccountBudgetsSession.clear()), so ProfileService no longer needs to
    // know about those services at all.
    ref.read(accountsSessionProvider.notifier).clear();
    ref.read(categoriesSessionProvider.notifier).clear();
    ref.read(expensesSessionProvider.notifier).clear();
    ref.read(accountBudgetsSessionProvider.notifier).clear();
  }

  void _setUser(User user) {
    final profile = user.profile;
    final themeMode = profile == null
        ? state.themeMode
        : _themeMode(profile.themeMode);
    final locale = profile == null ? state.locale : Locale(profile.language);
    final currency = profile == null ? state.currency : profile.currency;
    final amountDecimalPlaces = profile == null
        ? state.amountDecimalPlaces
        : profile.amountDecimalPlaces.clamp(0, 2);
    state = ProfileSessionState(
      currentUser: user,
      hasLoaded: true,
      themeMode: themeMode,
      locale: locale,
      currency: currency,
      amountDecimalPlaces: amountDecimalPlaces,
    );
    // RL-01 §1.3: keep the local per-uid preference mirror in sync with
    // whatever `UserProfile` snapshot was just applied (cache or remote), not
    // only with explicit changes made from the Preferences screen — so the
    // next cold start paints correctly before the profile has reloaded.
    if (profile != null) {
      unawaited(
        _cacheLocalPreferencesSafely(
          user.id,
          themeMode: themeMode,
          locale: locale,
          currency: currency,
          amountDecimalPlaces: amountDecimalPlaces,
        ),
      );
    }
  }

  Future<void> _cacheLocalPreferencesSafely(
    String uid, {
    required ThemeMode themeMode,
    required Locale locale,
    required String currency,
    required int amountDecimalPlaces,
  }) async {
    try {
      await ref
          .read(profileServiceProvider)
          .cacheLocalPreferences(
            uid,
            themeMode: themeMode,
            locale: locale,
            currency: currency,
            amountDecimalPlaces: amountDecimalPlaces,
          );
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to cache local profile preferences',
        error,
        stackTrace,
      );
    }
  }

  ThemeMode _themeMode(String value) => switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}
