import 'package:app/src/models/account/account.dart';
import 'package:app/src/models/category/category.dart';
import 'package:app/src/services/preferences_service.dart';
import 'package:flutter/material.dart';

class PreferencesViewModel extends ChangeNotifier {
  final PreferencesService _preferencesService = PreferencesService();

  ThemeMode get mode => _preferencesService.themeMode;
  Locale get locale => _preferencesService.locale;
  String get currency => _preferencesService.currency;

  List<String> get supportedCurrencies => PreferencesService.supportedCurrencies;

  Future<void> changeTheme(ThemeMode? themeMode) async {
    if (themeMode != null && themeMode != _preferencesService.themeMode) {
      await _preferencesService.setThemeMode(themeMode);
      notifyListeners();
    }
  }

  Future<void> changeLocale(Locale? locale) async {
    if (locale != null && locale != _preferencesService.locale) {
      await _preferencesService.setLocale(locale);
      notifyListeners();
    }
  }

  Future<void> changeCurrency(String? currency) async {
    if (currency != null && currency != _preferencesService.currency) {
      await _preferencesService.setCurrency(currency);
      notifyListeners();
    }
  }

  Future<void> loadInitialTheme() async {
    notifyListeners();
  }
}

abstract class BaseListViewModel<T> extends ChangeNotifier {
  final List<T> _items = [];

  List<T> get items => List.unmodifiable(_items);

  BaseListViewModel();

  T? _retrieve(String id, String Function(T) idSelector) {
    try {
      return _items.firstWhere((item) => idSelector(item) == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _add(T item) async {
    _items.add(item);
    notifyListeners();
  }

  Future<void> _remove(String id, String Function(T) idSelector) async {
    _items.removeWhere((item) => idSelector(item) == id);
    notifyListeners();
  }

  Future<void> _update(
    String id,
    T Function(T) updateFn,
    String Function(T) idSelector,
  ) async {
    final index = _items.indexWhere((item) => idSelector(item) == id);
    if (index != -1) {
      _items[index] = updateFn(_items[index]);
      notifyListeners();
    }
  }
}

class AccountsViewModel extends BaseListViewModel<Account> {
  AccountsViewModel() : super();

  Account? retrieve(String id) => _retrieve(id, (item) => item.id);

  Future<void> add(Account account) => _add(account);

  Future<void> remove(String id) => _remove(id, (item) => item.id);

  Future<void> update(String id, Account account) =>
      _update(id, (item) => account.copyWith(), (item) => item.id);
}

class CategoriesViewModel extends BaseListViewModel<Category> {
  CategoriesViewModel() : super();

  Category? retrieve(String id) => _retrieve(id, (item) => item.id);

  Future<void> add(Category category) => _add(category);

  Future<void> remove(String id) => _remove(id, (item) => item.id);

  Future<void> update(String id, Category category) =>
      _update(id, (item) => category.copyWith(), (item) => item.id);
}

class SettingsViewModel with ChangeNotifier {
  final PreferencesViewModel preferences = PreferencesViewModel();
  final AccountsViewModel accounts = AccountsViewModel();
  final CategoriesViewModel categories = CategoriesViewModel();

  bool _isLoading = false;

  bool get isLoading => _isLoading;

  @override
  void dispose() {
    accounts.dispose();
    categories.dispose();
    super.dispose();
  }
}
