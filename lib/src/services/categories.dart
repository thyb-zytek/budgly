import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/models/category/category.dart';
import 'supabase/category_supabase.dart';

class CategoriesService {
  static CategoriesService? _instance;

  static CategoriesService get instance {
    _instance ??= CategoriesService._();
    return _instance!;
  }

  final CategorySupabase _categorySupabase = CategorySupabase();

  List<Category> _categories = [];
  Map<String, DateTime> _lastFetch = {};

  static const Duration _cacheValidity = AppConstants.cacheValidityShort;

  CategoriesService._();

  void invalidateCache() {
    // Reassign instead of clearing in place, so any list previously
    // handed out by listCategoriesByAccount() is never mutated after
    // the fact.
    _categories = [];
    _lastFetch = {};
  }

  /// Busts the cache for a single account only, without touching the
  /// other accounts' cached categories.
  void invalidateAccountCache(String accountId) {
    _categories = _categories.where((c) => c.accountId != accountId).toList();
    _lastFetch.remove(accountId);
  }

  Future<List<Category>> listCategoriesByAccount(String accountId) async {
    if (_categories.isNotEmpty &&
        _lastFetch.containsKey(accountId) &&
        DateTime.now().difference(_lastFetch[accountId]!) < _cacheValidity) {
      return _categories.where((c) => c.accountId == accountId).toList();
    }

    final freshCategories = await _categorySupabase.listByAccountId(accountId);

    _categories.removeWhere((c) => c.accountId == accountId);
    _categories.addAll(freshCategories);

    _lastFetch[accountId] = DateTime.now();
    // Defensive copy: never hand back a list a caller could mutate to
    // affect this service's own cache.
    return List<Category>.from(freshCategories);
  }

  Future<Category> createCategory(Category category) async {
    final created = await _categorySupabase.create(category);

    if (created != null) {
      _categories.add(created);
      return created;
    }
    throw Exception('Failed to create category');
  }

  Future<Category> updateCategory(Category category) async {
    final success = await _categorySupabase.update(category);

    if (success) {
      _categories =
          _categories.map((c) => c.id == category.id ? category : c).toList();
      return category;
    }
    throw Exception('Failed to update category');
  }

  Future<bool> deleteCategory(String categoryId) async {
    final success = await _categorySupabase.delete(categoryId);
    if (success) {
      _categories.removeWhere((c) => c.id == categoryId);
      return true;
    }
    throw Exception('Failed to delete category');
  }

  Category? getCategoryById(String categoryId) {
    try {
      return _categories.firstWhere((c) => c.id == categoryId);
    } catch (_) {
      return null;
    }
  }
}