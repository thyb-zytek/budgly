import 'package:budgly/src/models/user/user.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:budgly/src/stores/profile.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profile_providers.g.dart';

/// Riverpod-facing exposure of [ProfileService] / [ProfileStore] (issue M1b).
///
/// Neither class is rewritten here: both remain the app's `.instance`
/// singletons because they are read directly, outside any `ProviderScope`,
/// by `main.dart` (bootstrap, before `runApp`), `app.dart` (root
/// theme/locale), `app_router.dart` (`refreshListenable`) and
/// `route_guards.dart`, plus every ViewModel not yet migrated. Rewriting
/// those call sites belongs to #M4/#M5 (each is migrated together with the
/// page/router logic that owns it), not to this issue.
///
/// What this issue actually does: promote the page-local bridge introduced
/// in #M1 (`settings/preferences/preferences_provider.dart`) into a single
/// shared, `keepAlive` provider, so every feature migrated from now on
/// depends on the *same* provider instead of each declaring its own.
@Riverpod(keepAlive: true)
ProfileService profileService(Ref ref) => ProfileService.instance;

/// Immutable, Riverpod-observable mirror of [ProfileStore]'s state.
///
/// [ProfileStore] itself stays a `ChangeNotifier` singleton (still consumed
/// directly by `category_view.dart` and by [ProfileService]). This notifier
/// listens to it and republishes an immutable snapshot, so migrated
/// `Notifier`s can `ref.watch(profileSessionProvider.select(...))` instead
/// of each registering its own `addListener`/`removeListener` pair.
@immutable
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

  @override
  bool operator ==(Object other) =>
      other is ProfileSessionState &&
      other.currentUser == currentUser &&
      other.hasLoaded == hasLoaded &&
      other.themeMode == themeMode &&
      other.locale == locale &&
      other.currency == currency &&
      other.amountDecimalPlaces == amountDecimalPlaces;

  @override
  int get hashCode => Object.hash(
        currentUser,
        hasLoaded,
        themeMode,
        locale,
        currency,
        amountDecimalPlaces,
      );
}

@Riverpod(keepAlive: true)
class ProfileSession extends _$ProfileSession {
  ProfileStore get _store => ProfileStore.instance;

  @override
  ProfileSessionState build() {
    _store.addListener(_onStoreChanged);
    ref.onDispose(() => _store.removeListener(_onStoreChanged));
    return _readState();
  }

  ProfileSessionState _readState() => ProfileSessionState(
        currentUser: _store.currentUser,
        hasLoaded: _store.hasLoaded,
        themeMode: _store.themeMode,
        locale: _store.locale,
        currency: _store.currency,
        amountDecimalPlaces: _store.amountDecimalPlaces,
      );

  void _onStoreChanged() {
    state = _readState();
  }
}
