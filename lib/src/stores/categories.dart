import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/category/category_icon.dart';
import 'package:flutter/material.dart';

class CategoriesStore extends ChangeNotifier {
  static CategoriesStore? _instance;

  static CategoriesStore get instance {
    _instance ??= CategoriesStore._();
    return _instance!;
  }

  Map<String, List<Category>> _categoriesByAccount = {};
  Map<String, bool> _hasLoadedByAccount = {};
  List<CategoryIcon> _availableIcons = [];
  bool _isLoading = false;
  bool _iconsLoaded = false;

  Map<String, List<Category>> get categoriesByAccount =>
      Map.unmodifiable(_categoriesByAccount);
  List<CategoryIcon> get availableIcons => List.unmodifiable(_availableIcons);
  bool get isLoading => _isLoading;
  bool get iconsLoaded => _iconsLoaded;

  CategoriesStore._();

  void setAvailableIcons(List<CategoryIcon> icons) {
    _availableIcons = List.from(icons);
    _iconsLoaded = true;
    notifyListeners();
  }

  void setCategoriesForAccount(String accountId, List<Category> categories) {
    _categoriesByAccount[accountId] = List.from(categories);
    _hasLoadedByAccount[accountId] = true;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  bool hasLoadedAccount(String accountId) {
    return _hasLoadedByAccount[accountId] == true;
  }

  List<Category> getCategoriesForAccount(String accountId) {
    return List.unmodifiable(_categoriesByAccount[accountId] ?? const []);
  }

  Category? getCategoryById(String categoryId) {
    for (final categories in _categoriesByAccount.values) {
      try {
        return categories.firstWhere((c) => c.id == categoryId);
      } catch (_) {
        continue;
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
    _categoriesByAccount.remove(accountId);
    _hasLoadedByAccount.remove(accountId);
    notifyListeners();
  }

  void clearAll() {
    _categoriesByAccount.clear();
    _hasLoadedByAccount.clear();
    notifyListeners();
  }
}