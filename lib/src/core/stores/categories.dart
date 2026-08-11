import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/category/category_icon.dart';
import 'package:budgly/src/services/categories.dart';
import 'package:budgly/src/services/category_icons.dart';
import 'package:flutter/material.dart';

class CategoriesStore extends ChangeNotifier {
  static CategoriesStore? _instance;

  static CategoriesStore get instance {
    _instance ??= CategoriesStore._();
    return _instance!;
  }

  final CategoriesService _categoriesService = CategoriesService.instance;
  final CategoryIconsService _categoryIconsService = CategoryIconsService.instance;

  Map<String, List<Category>> _categoriesByAccount = {};
  Map<String, bool> _hasLoadedByAccount = {};
  List<CategoryIcon> _availableIcons = [];
  bool _isLoading = false;
  bool _iconsLoaded = false;

  Map<String, List<Category>> get categoriesByAccount =>
      Map.unmodifiable(_categoriesByAccount);
  List<CategoryIcon> get availableIcons => List.unmodifiable(_availableIcons);
  bool get isLoading => _isLoading;

  CategoriesStore._();

  Future<void> loadAvailableIcons() async {
    if (_iconsLoaded) return;

    _availableIcons = await _categoryIconsService.getIcons();
    _iconsLoaded = true;
    notifyListeners();
  }

  Future<void> loadCategoriesForAccount(String accountId, {bool forceRefresh = false}) async {
    if (_hasLoadedByAccount[accountId] == true && !forceRefresh) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final categories = await _categoriesService.listCategoriesByAccount(accountId);

      if (!_iconsLoaded) {
        await loadAvailableIcons();
      }

      final categoriesWithIcons = <Category>[];
      for (final c in categories) {
        final iconCode = int.tryParse(c.iconCode ?? '0') ?? 0;
        CategoryIcon? icon;
        try {
          icon = _availableIcons.firstWhere((i) => i.iconCode == iconCode);
        } catch (_) {
          icon = _availableIcons.isNotEmpty ? _availableIcons.first : null;
        }
        categoriesWithIcons.add(c.copyWith(icon: icon));
      }

      _categoriesByAccount[accountId] = categoriesWithIcons;
      _hasLoadedByAccount[accountId] = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // List.unmodifiable évite une copie profonde de la liste (contrairement à
  // List.from) tout en empêchant les appelants de muter l'état interne du
  // store — ce getter est appelé à chaque build de l'UI qui écoute ce store.
  List<Category> getCategoriesForAccount(String accountId) {
    return List.unmodifiable(_categoriesByAccount[accountId] ?? const []);
  }

  Future<void> invalidateCache() async {
    _categoriesService.invalidateCache();
    final accountIds = List<String>.from(_hasLoadedByAccount.keys);
    for (final accountId in accountIds) {
      await loadCategoriesForAccount(accountId, forceRefresh: true);
    }
  }

  Future<void> invalidateAccountCache(String accountId) async {
    final wasLoaded = _hasLoadedByAccount[accountId] == true;
    _categoriesService.invalidateAccountCache(accountId);

    if (wasLoaded) {
      await loadCategoriesForAccount(accountId, forceRefresh: true);
    } else {
      _categoriesByAccount.remove(accountId);
      _hasLoadedByAccount.remove(accountId);
      notifyListeners();
    }
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
}