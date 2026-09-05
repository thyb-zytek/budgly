import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/core/view_models/base_view_model.dart';
import 'package:budgly/src/pages/settings/preferences/view_model.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:budgly/src/stores/profile.dart';
import 'package:flutter/material.dart';
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

  setUp(() {
    fake = FakeProfileService();
  });

  tearDown(() {
    ProfileStore.instance.clear();
  });

  test('mode, locale, currency and amountDecimalPlaces delegate to the profile', () {
    final vm = PreferencesViewModel(profileService: fake);
    addTearDown(vm.dispose);

    expect(vm.mode, ProfileStore.instance.themeMode);
    expect(vm.locale, ProfileStore.instance.locale);
    expect(vm.currency, ProfileStore.instance.currency);
    expect(vm.amountDecimalPlaces, 2);
    expect(vm.supportedCurrencies, AppConstants.supportedCurrencies);
  });

  test('changeTheme delegates to the profile service', () async {
    final vm = PreferencesViewModel(profileService: fake);
    addTearDown(vm.dispose);

    await vm.changeTheme(ThemeMode.dark);

    expect(fake.setThemeCalls, 1);
    expect(fake.lastTheme, ThemeMode.dark);
    expect(vm.mode, ThemeMode.dark);
  });

  test('changeTheme ignores null', () async {
    final vm = PreferencesViewModel(profileService: fake);
    addTearDown(vm.dispose);

    await vm.changeTheme(null);

    expect(fake.setThemeCalls, 0);
  });

  test('changeLocale delegates to the profile service', () async {
    final vm = PreferencesViewModel(profileService: fake);
    addTearDown(vm.dispose);

    await vm.changeLocale(const Locale('en'));

    expect(fake.setLocaleCalls, 1);
    expect(fake.lastLocale, const Locale('en'));
  });

  test('changeLocale ignores null', () async {
    final vm = PreferencesViewModel(profileService: fake);
    addTearDown(vm.dispose);

    await vm.changeLocale(null);

    expect(fake.setLocaleCalls, 0);
  });

  test('changeCurrency delegates to the profile service', () async {
    final vm = PreferencesViewModel(profileService: fake);
    addTearDown(vm.dispose);

    await vm.changeCurrency('USD');

    expect(fake.setCurrencyCalls, 1);
    expect(fake.lastCurrency, 'USD');
  });

  test('changeCurrency ignores null', () async {
    final vm = PreferencesViewModel(profileService: fake);
    addTearDown(vm.dispose);

    await vm.changeCurrency(null);

    expect(fake.setCurrencyCalls, 0);
  });

  test('changeAmountDecimalPlaces delegates to the profile service', () async {
    final vm = PreferencesViewModel(profileService: fake);
    addTearDown(vm.dispose);

    await vm.changeAmountDecimalPlaces(0);

    expect(fake.setDecimalPlacesCalls, 1);
    expect(fake.lastDecimalPlaces, 0);
    expect(vm.amountDecimalPlaces, 0);
  });

  test('service changes propagate to listeners', () {
    final vm = PreferencesViewModel(profileService: fake);
    var notified = false;
    vm.addListener(() => notified = true);
    addTearDown(vm.dispose);

    ProfileStore.instance.setPreferences(currency: 'GBP');

    expect(notified, isTrue);
  });

  test('dispose stops reacting to service changes', () {
    final vm = PreferencesViewModel(profileService: fake);
    var count = 0;
    vm.addListener(() => count++);
    vm.dispose();

    ProfileStore.instance.setPreferences(currency: 'GBP');

    expect(count, 0);
  });

  test('view state is idle by default', () {
    final vm = PreferencesViewModel(profileService: fake);
    addTearDown(vm.dispose);

    expect(vm.viewState, ViewState.idle);
    expect(vm.isLoading, isFalse);
    expect(vm.hasError, isFalse);
  });
}
