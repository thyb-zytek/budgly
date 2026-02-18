import 'package:app/src/models/category/category.dart';
import 'package:app/src/services/supabase.dart';

class CategoriesService {
  static CategoriesService? _instance;

  static CategoriesService get instance {
    _instance ??= CategoriesService._();
    return _instance!;
  }

  final SupabaseService _supabaseService = SupabaseService();

  List<Category> _categories = [];
  Map<String, DateTime> _lastFetch = {};

  static const Duration _cacheValidity = Duration(minutes: 5);

  CategoriesService._();

  void invalidateCache() {
    _categories.clear();
    _lastFetch = {};
  }

  Future<List<Category>> listCategoriesByAccount(String accountId) async {
    if (_categories.isNotEmpty &&
        _lastFetch.isNotEmpty &&
        _lastFetch.containsKey(accountId) &&
        DateTime.now().difference(_lastFetch[accountId] ?? DateTime.now()) <
            _cacheValidity) {
      return _categories.where((c) => c.accountId == accountId).toList();
    }

    final freshCategories = await _supabaseService.getCategoriesByAccount(
      accountId,
    );

    if (freshCategories.isNotEmpty) {
      _categories.removeWhere((c) => c.accountId == accountId);
      _categories.addAll(freshCategories);
    }

    _lastFetch[accountId] = DateTime.now();
    return freshCategories;
  }

  Future<Category> createCategory(Category category) async {
    final created = await _supabaseService.createCategory(category);

    if (created != null) {
      _categories.add(created);
      return created;
    } else {
      throw Exception('Failed to create category');
    }
  }

  Future<Category> updateCategory(Category category) async {
    final success = await _supabaseService.updateCategory(category);

    if (success) {
      _categories =
          _categories.map((c) => c.id == category.id ? category : c).toList();
      return category;
    } else {
      throw Exception('Failed to update category');
    }
  }

  Future<bool> deleteCategory(String categoryId) async {
    final success = await _supabaseService.deleteCategory(categoryId);
    if (success) {
      _categories.removeWhere((c) => c.id == categoryId);
      return true;
    } else {
      throw Exception('Failed to delete category');
    }
  }

  Category? getCategoryById(String categoryId) {
    try {
      return _categories.firstWhere((c) => c.id == categoryId);
    } catch (e) {
      return null;
    }
  }
}
