import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/category/category_icon.dart';
import 'package:budgly/src/services/categories/categories_service_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'categories_provider.g.dart';

class CategoriesSessionState {
  const CategoriesSessionState({
    required this.categoriesByAccount,
    required this.availableIcons,
    required this.iconsLoaded,
    required this.loadedAccounts,
  });
  final Map<String, List<Category>> categoriesByAccount;
  final List<CategoryIcon> availableIcons;
  final bool iconsLoaded;
  final Set<String> loadedAccounts;
}

@Riverpod(keepAlive: true)
class CategoriesSession extends _$CategoriesSession {
  @override
  CategoriesSessionState build() => const CategoriesSessionState(
    categoriesByAccount: {},
    availableIcons: [],
    iconsLoaded: false,
    loadedAccounts: {},
  );

  List<Category> getCategoriesForAccount(String accountId) =>
      state.categoriesByAccount[accountId] ?? const [];
  bool hasLoadedAccount(String accountId) =>
      state.loadedAccounts.contains(accountId);

  Future<void> loadIcons() async {
    final icons = await ref
        .read(categoriesServiceProvider)
        .loadAvailableIcons();
    state = CategoriesSessionState(
      categoriesByAccount: state.categoriesByAccount,
      availableIcons: icons,
      iconsLoaded: true,
      loadedAccounts: state.loadedAccounts,
    );
  }

  Future<List<Category>> load(
    String accountId, {
    bool forceRefresh = false,
  }) async {
    final categories = await ref
        .read(categoriesServiceProvider)
        .listCategoriesByAccount(
          accountId,
          forceRefresh: forceRefresh,
          // RL-01 §3.2: push a later background revalidation into the
          // session too, so listeners rebuild instead of staying stuck on
          // the cache-first snapshot returned below.
          onRevalidated: (remote) => _setAccountCategories(accountId, remote),
        );
    _setAccountCategories(accountId, categories);
    return categories;
  }

  void _setAccountCategories(String accountId, List<Category> categories) {
    final next = Map<String, List<Category>>.from(state.categoriesByAccount)
      ..[accountId] = List.unmodifiable(categories);
    state = CategoriesSessionState(
      categoriesByAccount: Map.unmodifiable(next),
      availableIcons: state.availableIcons,
      iconsLoaded: state.iconsLoaded,
      loadedAccounts: {...state.loadedAccounts, accountId},
    );
  }

  Future<Category> create(Category category) async {
    final created = await ref
        .read(categoriesServiceProvider)
        .createCategory(category);
    _upsert(created);
    return created;
  }

  Future<Category> update(Category category) async {
    final updated = await ref
        .read(categoriesServiceProvider)
        .updateCategory(category);
    _upsert(updated);
    return updated;
  }

  Future<bool> delete(String categoryId, {String? accountId}) async {
    final result = await ref
        .read(categoriesServiceProvider)
        .deleteCategory(categoryId, accountId: accountId);
    if (result) {
      final next = <String, List<Category>>{};
      for (final entry in state.categoriesByAccount.entries) {
        next[entry.key] = List.unmodifiable(
          entry.value.where((c) => c.id != categoryId),
        );
      }
      state = CategoriesSessionState(
        categoriesByAccount: Map.unmodifiable(next),
        availableIcons: state.availableIcons,
        iconsLoaded: state.iconsLoaded,
        loadedAccounts: state.loadedAccounts,
      );
    }
    return result;
  }

  void updateLocal(Category category) => _upsert(category);

  void invalidateAccount(String accountId) {
    final next = Map<String, List<Category>>.from(state.categoriesByAccount)
      ..remove(accountId);
    final loaded = {...state.loadedAccounts}..remove(accountId);
    state = CategoriesSessionState(
      categoriesByAccount: Map.unmodifiable(next),
      availableIcons: state.availableIcons,
      iconsLoaded: state.iconsLoaded,
      loadedAccounts: loaded,
    );
    ref.read(categoriesServiceProvider).invalidateAccountCache(accountId);
  }

  void clear() {
    state = const CategoriesSessionState(
      categoriesByAccount: {},
      availableIcons: [],
      iconsLoaded: false,
      loadedAccounts: {},
    );
    ref.read(categoriesServiceProvider).invalidateCache();
  }

  void _upsert(Category category) {
    final list = List<Category>.from(
      state.categoriesByAccount[category.accountId] ?? const [],
    );
    final index = list.indexWhere((c) => c.id == category.id);
    if (index == -1) {
      list.add(category);
    } else {
      list[index] = category;
    }
    final next = Map<String, List<Category>>.from(state.categoriesByAccount)
      ..[category.accountId] = List.unmodifiable(list);
    state = CategoriesSessionState(
      categoriesByAccount: Map.unmodifiable(next),
      availableIcons: state.availableIcons,
      iconsLoaded: state.iconsLoaded,
      loadedAccounts: {...state.loadedAccounts, category.accountId},
    );
  }
}
