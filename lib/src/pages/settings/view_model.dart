import 'package:app/src/models/account/account.dart';
import 'package:app/src/models/category/category.dart';
import 'package:app/src/services/theme_service.dart';
import 'package:flutter/material.dart';


abstract class BaseListViewModel<T> extends ChangeNotifier {
  final List<T> _items = [];
  
  List<T> get items => List.unmodifiable(_items);
  
  T? retrieve(String id, String Function(T) idSelector) {
    try {
      return _items.firstWhere((item) => idSelector(item) == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> add(T item) async {
    _items.add(item);
    notifyListeners();
  }

  Future<void> remove(String id, String Function(T) idSelector) async {
    _items.removeWhere((item) => idSelector(item) == id);
    notifyListeners();
  }

  Future<void> update(
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

class ThemeViewModel extends ChangeNotifier {
  final ThemeService _themeService = ThemeService();

  ThemeMode get mode => _themeService.themeMode;

  ThemeViewModel() {
    _themeService.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => notifyListeners();

  Future<void> change(ThemeMode? themeMode) async {
    if (themeMode != null) {
      await _themeService.setThemeMode(themeMode);
      notifyListeners();
    }
  }
}

class AccountsViewModel extends BaseListViewModel<Account> {
  Future<void> removeAccount(String id) => remove(id, (item) => item.id);
  
  Future<void> updateAccount(
    String id,
    Account updates,
  ) => update(
    id,
    (item) => Account.fromJson({...item.toJson(), ...updates.toJson()}),
    (item) => item.id,
  );
}

class CategoriesViewModel extends BaseListViewModel<Category> {
  Future<void> removeCategory(String id) => remove(id, (item) => item.id);
  
  Future<void> updateCategory(
    String id,
    Category updates,
  ) => update(
    id,
    (item) => Category.fromJson({...item.toJson(), ...updates.toJson()}),
    (item) => item.id,
  );
}

class SettingsViewModel extends ChangeNotifier {
  final ThemeViewModel _theme = ThemeViewModel();
  final AccountsViewModel _accounts = AccountsViewModel();
  final CategoriesViewModel _categories = CategoriesViewModel();

  ThemeViewModel get theme => _theme;
  AccountsViewModel get accounts => _accounts;
  CategoriesViewModel get categories => _categories;

  @override
  void dispose() {
    _theme.dispose();
    _accounts.dispose();
    _categories.dispose();
    super.dispose();
  }
}
