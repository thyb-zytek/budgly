import 'package:budgly/src/pages/settings/preferences/preferences_provider.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:budgly/src/stores/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeProfileService extends ProfileService {
  ThemeMode? lastTheme;
  Locale? lastLocale;
  String? lastCurrency;
  int? lastDecimalPlaces;
  int setThemeCalls = 0;
  int setLocaleCalls = 0;
  int setCurrencyCalls = 0;
  int setDecimalPlacesCalls = 0;

  FakeProfileService() : super(store: ProfileStore.instance);

  @override
  Future<void> setThemeMode(ThemeMode themeMode) async {
    setThemeCalls++;
    lastTheme = themeMode;
    ProfileStore.instance.setPreferences(themeMode: themeMode);
  }

  @override
  Future<void> setLocale(Locale locale) async {
    setLocaleCalls++;
    lastLocale = locale;
    ProfileStore.instance.setPreferences(locale: locale);
  }

  @override
  Future<void> setCurrency(String currency) async {
    setCurrencyCalls++;
    lastCurrency = currency;
    ProfileStore.instance.setPreferences(currency: currency);
  }

  @override
  Future<void> setAmountDecimalPlaces(int value) async {
    setDecimalPlacesCalls++;
    lastDecimalPlaces = value;
    ProfileStore.instance.setPreferences(amountDecimalPlaces: value);
  }
}

void main() {
  late FakeProfileService fake;
  late ProviderContainer container;

  setUp(() {
    fake = FakeProfileService();
    container = ProviderContainer(
      overrides: [profileServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
  });

  tearDown(() {
    ProfileStore.instance.clear();
  });

  test('mode, locale, currency and amountDecimalPlaces reflect the profile', () {
    final state = container.read(preferencesProvider);

    expect(state.mode, ProfileStore.instance.themeMode);
    expect(state.locale, ProfileStore.instance.locale);
    expect(state.currency, ProfileStore.instance.currency);
    expect(state.amountDecimalPlaces, 2);
  });

  test('changeTheme delegates to the profile service', () async {
    final notifier = container.read(preferencesProvider.notifier);

    await notifier.changeTheme(ThemeMode.dark);

    expect(fake.setThemeCalls, 1);
    expect(fake.lastTheme, ThemeMode.dark);
    expect(container.read(preferencesProvider).mode, ThemeMode.dark);
  });

  test('changeTheme ignores null', () async {
    final notifier = container.read(preferencesProvider.notifier);

    await notifier.changeTheme(null);

    expect(fake.setThemeCalls, 0);
  });

  test('changeLocale delegates to the profile service', () async {
    final notifier = container.read(preferencesProvider.notifier);

    await notifier.changeLocale(const Locale('en'));

    expect(fake.setLocaleCalls, 1);
    expect(fake.lastLocale, const Locale('en'));
  });

  test('changeLocale ignores null', () async {
    final notifier = container.read(preferencesProvider.notifier);

    await notifier.changeLocale(null);

    expect(fake.setLocaleCalls, 0);
  });

  test('changeCurrency delegates to the profile service', () async {
    final notifier = container.read(preferencesProvider.notifier);

    await notifier.changeCurrency('USD');

    expect(fake.setCurrencyCalls, 1);
    expect(fake.lastCurrency, 'USD');
  });

  test('changeCurrency ignores null', () async {
    final notifier = container.read(preferencesProvider.notifier);

    await notifier.changeCurrency(null);

    expect(fake.setCurrencyCalls, 0);
  });

  test('changeAmountDecimalPlaces delegates to the profile service', () async {
    final notifier = container.read(preferencesProvider.notifier);

    await notifier.changeAmountDecimalPlaces(0);

    expect(fake.setDecimalPlacesCalls, 1);
    expect(fake.lastDecimalPlaces, 0);
    expect(container.read(preferencesProvider).amountDecimalPlaces, 0);
  });

  test('service changes propagate to listeners', () {
    // Ensure the provider is alive (build() ran, listener registered)
    // before mutating the store from outside.
    container.read(preferencesProvider);

    var notified = false;
    container.listen(preferencesProvider, (previous, next) => notified = true);

    ProfileStore.instance.setPreferences(currency: 'GBP');

    expect(notified, isTrue);
    expect(container.read(preferencesProvider).currency, 'GBP');
  });

  test('disposing the container stops reacting to service changes', () {
    final localContainer = ProviderContainer(
      overrides: [profileServiceProvider.overrideWithValue(fake)],
    );
    localContainer.read(preferencesProvider);
    localContainer.dispose();

    // Must not throw: the Preferences notifier removed its listener from
    // the (still-singleton) ProfileService via ref.onDispose.
    expect(
      () => ProfileStore.instance.setPreferences(currency: 'GBP'),
      returnsNormally,
    );
  });
}
