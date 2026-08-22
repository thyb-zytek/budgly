import 'dart:ui';
import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/services/cache/cache_controller.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/category/category_icon.dart';
import 'package:budgly/src/services/categories/category_icons_service.dart';
import 'package:budgly/src/stores/categories.dart';
import 'package:budgly/src/services/providers/supabase/categories.dart';

class CategoriesService {
  static CategoriesService? _instance;

  static CategoriesService get instance {
    _instance ??= CategoriesService._();
    return _instance!;
  }

  final CategorySupabase _categorySupabase;
  final CategoryIconsService _categoryIconsService;
  final CategoriesStore _store;

  final CacheController<String> _cache =
      CacheController<String>(ttl: AppConstants.cacheValidityShort);

  CategoriesService({
    CategorySupabase? categorySupabase,
    CategoryIconsService? categoryIconsService,
    CategoriesStore? store,
  })  : _categorySupabase = categorySupabase ?? CategorySupabase(),
        _categoryIconsService = categoryIconsService ?? CategoryIconsService.instance,
        _store = store ?? CategoriesStore.instance;

  CategoriesService._() : this();

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
    _cache.invalidate();
    _store.clearAll();
  }

  void invalidateAccountCache(String accountId) {
    _cache.invalidate(accountId);
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
    final rawIconCode = category.iconCode ?? '0';
    final iconCode = rawIconCode.toLowerCase().startsWith('0x')
        ? int.tryParse(rawIconCode.substring(2), radix: 16) ?? 0
        : int.tryParse(rawIconCode) ?? 0;
    
    try {
      if (iconCode != 0) {
        resolvedIcon = _store.availableIcons.firstWhere((i) => i.iconCode == iconCode);
      }
    } catch (_) {
      resolvedIcon = null;
    }

    resolvedIcon ??= _store.availableIcons.firstWhere(
      (i) => i.iconName == AppConstants.defaultCategoryIcon.iconName,
      orElse: () => AppConstants.defaultCategoryIcon,
    );

    return category.copyWith(icon: resolvedIcon);
  }

  Future<List<Category>> listCategoriesByAccount(String accountId, {bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _store.hasLoadedAccount(accountId) &&
        _cache.isFresh(accountId)) {
      return _store.getCategoriesForAccount(accountId);
    }

    final inFlight = _cache.inFlight(accountId);
    if (inFlight != null) {
      await inFlight;
      return _store.getCategoriesForAccount(accountId);
    }

    final future = _loadCategories(accountId);
    _cache.track(accountId, future);
    try {
      await future;
      return _store.getCategoriesForAccount(accountId);
    } finally {
      _cache.untrack(accountId, future);
    }
  }

  Future<List<Category>> _loadCategories(String accountId) async {
    final generation = _cache.generation;
    _store.beginLoading();
    try {
      if (!_store.iconsLoaded) await loadAvailableIcons();
      final freshCategories = await _categorySupabase.listByAccountId(accountId);
      final categoriesWithIcons = freshCategories
          .map(_hydrateCategoryIcon)
          .toList(growable: false);
      if (generation != _cache.generation) return categoriesWithIcons;
      _store.setCategoriesForAccount(accountId, categoriesWithIcons);
      _cache.markFresh(accountId);
      return categoriesWithIcons;
    } finally {
      _store.endLoading();
    }
  }

  Future<Category> createCategory(Category category) async {
    final generation = _cache.generation;
    final created = await _categorySupabase.create(category);

    if (created != null) {
      final hydratedCategory = _hydrateCategoryIcon(created);
      if (generation == _cache.generation) _store.addCategory(hydratedCategory);
      return hydratedCategory;
    }
    throw Exception('Failed to create category');
  }

  Future<Category> updateCategory(Category category) async {
    final generation = _cache.generation;
    final success = await _categorySupabase.update(category);

    if (success) {
      final hydratedCategory = _hydrateCategoryIcon(category);
      if (generation == _cache.generation) _store.updateCategory(hydratedCategory);
      return hydratedCategory;
    }
    throw Exception('Failed to update category');
  }

  Future<bool> deleteCategory(String categoryId) async {
    final generation = _cache.generation;
    final success = await _categorySupabase.delete(categoryId);
    if (success) {
      if (generation == _cache.generation) _store.removeCategory(categoryId);
      return true;
    }
    throw Exception('Failed to delete category');
  }

  Category? getCategoryById(String categoryId) {
    final category = _store.getCategoryById(categoryId);
    return category != null ? _hydrateCategoryIcon(category) : null;
  }
}