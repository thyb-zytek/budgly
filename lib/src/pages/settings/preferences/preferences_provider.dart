import 'package:budgly/src/core/riverpod/profile_providers.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'preferences_provider.g.dart';

/// Immutable snapshot of the preferences relevant to [PreferencesTab].
class PreferencesState {
  const PreferencesState({
    required this.mode,
    required this.locale,
    required this.currency,
    required this.amountDecimalPlaces,
  });

  final ThemeMode mode;
  final Locale locale;
  final String currency;
  final int amountDecimalPlaces;

  @override
  bool operator ==(Object other) =>
      other is PreferencesState &&
      other.mode == mode &&
      other.locale == locale &&
      other.currency == currency &&
      other.amountDecimalPlaces == amountDecimalPlaces;

  @override
  int get hashCode => Object.hash(mode, locale, currency, amountDecimalPlaces);
}

@riverpod
class Preferences extends _$Preferences {
  ProfileService get _profileService => ref.read(profileServiceProvider);

  @override
  PreferencesState build() {
    final service = ref.watch(profileServiceProvider);
    service.addListener(_onServiceChanged);
    ref.onDispose(() => service.removeListener(_onServiceChanged));
    return _readState(service);
  }

  PreferencesState _readState(ProfileService service) => PreferencesState(
        mode: service.themeMode,
        locale: service.locale,
        currency: service.currency,
        amountDecimalPlaces: service.amountDecimalPlaces,
      );

  void _onServiceChanged() {
    state = _readState(_profileService);
  }

  Future<void> changeTheme(ThemeMode? themeMode) async {
    if (themeMode == null) return;
    await _profileService.setThemeMode(themeMode);
  }

  Future<void> changeLocale(Locale? locale) async {
    if (locale == null) return;
    await _profileService.setLocale(locale);
  }

  Future<void> changeCurrency(String? currency) async {
    if (currency == null) return;
    await _profileService.setCurrency(currency);
  }

  Future<void> changeAmountDecimalPlaces(int value) async {
    await _profileService.setAmountDecimalPlaces(value);
  }
}
