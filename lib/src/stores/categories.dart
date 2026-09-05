import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/category/category_icon.dart';
import 'package:flutter/material.dart';

class CategoriesStore extends ChangeNotifier {
  static CategoriesStore? _instance;

  static CategoriesStore get instance {
    _instance ??= CategoriesStore._();
    return _instance!;
  }

  final Map<String, List<Category>> _categoriesByAccount = {};
  final Map<String, bool> _hasLoadedByAccount = {};
  List<CategoryIcon> _availableIcons = [];
  bool _iconsLoaded = false;

  Map<String, List<Category>> get categoriesByAccount =>
      Map.unmodifiable(_categoriesByAccount);
  List<CategoryIcon> get availableIcons => List.unmodifiable(_availableIcons);
  bool get iconsLoaded => _iconsLoaded;

  CategoriesStore._();

  void setAvailableIcons(List<CategoryIcon> icons) {
    if (_iconsLoaded && _availableIcons.length == icons.length) {
      var same = true;
      for (var i = 0; i < icons.length; i++) {
        if (_availableIcons[i] != icons[i]) {
          same = false;
          break;
        }
      }
      if (same) return;
    }

    _availableIcons = List.from(icons);
    _iconsLoaded = icons.isNotEmpty;
    notifyListeners();
  }

  void setCategoriesForAccount(String accountId, List<Category> categories) {
    final previous = _categoriesByAccount[accountId];
    if (_hasLoadedByAccount[accountId] == true &&
        previous != null &&
        _sameCategories(previous, categories)) {
      return;
    }
    _categoriesByAccount[accountId] = List.from(categories);
    _hasLoadedByAccount[accountId] = true;
    notifyListeners();
  }

  bool _sameCategories(List<Category> a, List<Category> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final left = a[i];
      final right = b[i];
      if (left.id != right.id ||
          left.name != right.name ||
          left.color != right.color ||
          left.iconCode != right.iconCode ||
          left.icon != right.icon ||
          left.accountId != right.accountId) {
        return false;
      }
    }
    return true;
  }

  bool hasLoadedAccount(String accountId) {
    return _hasLoadedByAccount[accountId] == true;
  }

  List<Category> getCategoriesForAccount(String accountId) {
    return List.unmodifiable(_categoriesByAccount[accountId] ?? const []);
  }

  Category? getCategoryById(String categoryId) {
    for (final categories in _categoriesByAccount.values) {
      for (final c in categories) {
        if (c.id == categoryId) return c;
      }
    }
    return null;
  }

  void addCategory(Category category) {
    final accountId = category.accountId;
    if (_categoriesByAccount[accountId] == null) {
      _categoriesByAccount[accountId] = [];
    }
    _categoriesByAccount[accountId]!.add(category);
    notifyListeners();
  }

  void updateCategory(Category category) {
    final accountId = category.accountId;
    if (_categoriesByAccount[accountId] != null) {
      final index = _categoriesByAccount[accountId]!.indexWhere((c) => c.id == category.id);
      if (index != -1) {
        _categoriesByAccount[accountId]![index] = category;
        notifyListeners();
      }
    }
  }

  void removeCategory(String categoryId) {
    for (final accountId in _categoriesByAccount.keys) {
      final categories = _categoriesByAccount[accountId]!;
      final initialLength = categories.length;
      categories.removeWhere((c) => c.id == categoryId);
      if (categories.length != initialLength) {
        notifyListeners();
        break;
      }
    }
  }

  void clearAccountCache(String accountId) {
    final removedCategories = _categoriesByAccount.remove(accountId);
    final removedLoaded = _hasLoadedByAccount.remove(accountId);
    if (removedCategories != null || removedLoaded != null) notifyListeners();
  }

  void clearAll() {
    if (_categoriesByAccount.isEmpty &&
        _hasLoadedByAccount.isEmpty &&
        _availableIcons.isEmpty &&
        !_iconsLoaded) {
      return;
    }
    _categoriesByAccount.clear();
    _hasLoadedByAccount.clear();
    _availableIcons = [];
    _iconsLoaded = false;
    notifyListeners();
  }
}
