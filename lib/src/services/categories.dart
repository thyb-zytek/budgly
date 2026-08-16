import 'dart:ui';
import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/category/category_icon.dart';
import 'package:budgly/src/services/category_icons.dart';
import 'package:budgly/src/stores/categories.dart';
import 'providers/supabase/categories.dart';

class CategoriesService {
  static CategoriesService? _instance;

  static CategoriesService get instance {
    _instance ??= CategoriesService._();
    return _instance!;
  }

  final CategorySupabase _categorySupabase = CategorySupabase();
  final CategoryIconsService _categoryIconsService = CategoryIconsService.instance;
  
  final CategoriesStore _store = CategoriesStore.instance;

  final Map<String, DateTime> _lastFetch = {};
  static const Duration _cacheValidity = AppConstants.cacheValidityShort;

  CategoriesService._();

  List<CategoryIcon> get availableIcons => _store.availableIcons;
  Map<String, List<Category>> get categoriesByAccount => _store.categoriesByAccount;
  bool get isLoading => _store.isLoading;
  bool hasLoadedAccount(String accountId) => _store.hasLoadedAccount(accountId);
  List<Category> getCategoriesForAccount(String accountId) => _store.getCategoriesForAccount(accountId);

  void addListener(VoidCallback listener) {
    _store.addListener(listener);
  }

  void removeListener(VoidCallback listener) {
    _store.removeListener(listener);
  }

  void invalidateCache() {
    _lastFetch.clear();
    _store.clearAll();
  }

  void invalidateAccountCache(String accountId) {
    _lastFetch.remove(accountId);
    _store.clearAccountCache(accountId);
  }

  Future<void> loadAvailableIcons() async {
    if (_store.iconsLoaded) return;
    final icons = await _categoryIconsService.getIcons();
    _store.setAvailableIcons(icons);
  }

  Category _hydrateCategoryIcon(Category category) {
    if (category.icon != null) return category;

    CategoryIcon? resolvedIcon;
    final iconCode = int.tryParse(category.iconCode ?? '0') ?? 0;
    
    try {
      if (iconCode != 0) {
        resolvedIcon = _store.availableIcons.firstWhere((i) => i.iconCode == iconCode);
      }
    } catch (_) {
      resolvedIcon = null;
    }

    resolvedIcon ??= _store.availableIcons.isNotEmpty 
        ? _store.availableIcons.first 
        : const CategoryIcon(
            iconName: 'category',
            iconPack: 'material',
            iconCode: 0xf624,
            labels: {"en": "Category", "fr": "Catégorie"},
          );

    return category.copyWith(icon: resolvedIcon);
  }

  Future<List<Category>> listCategoriesByAccount(String accountId, {bool forceRefresh = false}) async {
    final hasValidCache = _store.hasLoadedAccount(accountId) &&
        _lastFetch.containsKey(accountId) &&
        DateTime.now().difference(_lastFetch[accountId]!) < _cacheValidity;

    if (hasValidCache && !forceRefresh) {
      return _store.getCategoriesForAccount(accountId);
    }

    _store.setLoading(true);

    try {
      if (!_store.iconsLoaded) {
        await loadAvailableIcons();
      }

      final freshCategories = await _categorySupabase.listByAccountId(accountId);
      
      final categoriesWithIcons = <Category>[];
      for (final c in freshCategories) {
        categoriesWithIcons.add(_hydrateCategoryIcon(c));
      }

      _store.setCategoriesForAccount(accountId, categoriesWithIcons);
      _lastFetch[accountId] = DateTime.now();

      return categoriesWithIcons;
    } finally {
      _store.setLoading(false);
    }
  }

  Future<Category> createCategory(Category category) async {
    final created = await _categorySupabase.create(category);

    if (created != null) {
      final hydratedCategory = _hydrateCategoryIcon(created);
      _store.addCategory(hydratedCategory);
      return hydratedCategory;
    }
    throw Exception('Failed to create category');
  }

  Future<Category> updateCategory(Category category) async {
    final success = await _categorySupabase.update(category);

    if (success) {
      final hydratedCategory = _hydrateCategoryIcon(category);
      _store.updateCategory(hydratedCategory);
      return hydratedCategory;
    }
    throw Exception('Failed to update category');
  }

  Future<bool> deleteCategory(String categoryId) async {
    final success = await _categorySupabase.delete(categoryId);
    if (success) {
      _store.removeCategory(categoryId);
      return true;
    }
    throw Exception('Failed to delete category');
  }

  Category? getCategoryById(String categoryId) {
    final category = _store.getCategoryById(categoryId);
    return category != null ? _hydrateCategoryIcon(category) : null;
  }
}