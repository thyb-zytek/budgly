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

  int _sessionRevision = 0;
  int _iconsLoadRevision = 0;
  final Map<String, int> _accountLoadRevisions = {};
  final Map<String, int> _accountMutationRevisions = {};

  int _accountLoadRevision(String accountId) =>
      _accountLoadRevisions[accountId] ?? 0;
  int _accountMutationRevision(String accountId) =>
      _accountMutationRevisions[accountId] ?? 0;

  List<Category> getCategoriesForAccount(String accountId) =>
      state.categoriesByAccount[accountId] ?? const [];
  bool hasLoadedAccount(String accountId) =>
      state.loadedAccounts.contains(accountId);

  Future<void> loadIcons() async {
    final sessionRevision = _sessionRevision;
    final loadRevision = ++_iconsLoadRevision;
    final icons = await ref
        .read(categoriesServiceProvider)
        .loadAvailableIcons();
    if (!ref.mounted ||
        sessionRevision != _sessionRevision ||
        loadRevision != _iconsLoadRevision) {
      return;
    }
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
    final sessionRevision = _sessionRevision;
    final loadRevision = _accountLoadRevision(accountId) + 1;
    _accountLoadRevisions[accountId] = loadRevision;
    final mutationRevision = _accountMutationRevision(accountId);

    bool canApply() =>
        ref.mounted &&
        sessionRevision == _sessionRevision &&
        loadRevision == _accountLoadRevision(accountId) &&
        mutationRevision == _accountMutationRevision(accountId);

    final categories = await ref
        .read(categoriesServiceProvider)
        .listCategoriesByAccount(
          accountId,
          forceRefresh: forceRefresh,
          // A later cache revalidation is accepted only if no newer account
          // load, local mutation or session clear superseded it.
          onRevalidated: (remote) {
            if (canApply()) _applyAccountCategories(accountId, remote);
          },
        );
    if (canApply()) _applyAccountCategories(accountId, categories);
    return categories;
  }

  void _applyAccountCategories(String accountId, List<Category> categories) {
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
    final sessionRevision = _sessionRevision;
    _accountMutationRevisions[category.accountId] =
        _accountMutationRevision(category.accountId) + 1;
    final created = await ref
        .read(categoriesServiceProvider)
        .createCategory(category);
    if (ref.mounted && sessionRevision == _sessionRevision) _upsert(created);
    return created;
  }

  Future<Category> update(Category category) async {
    final sessionRevision = _sessionRevision;
    _accountMutationRevisions[category.accountId] =
        _accountMutationRevision(category.accountId) + 1;
    final updated = await ref
        .read(categoriesServiceProvider)
        .updateCategory(category);
    if (ref.mounted && sessionRevision == _sessionRevision) _upsert(updated);
    return updated;
  }

  Future<bool> delete(String categoryId, {String? accountId}) async {
    final sessionRevision = _sessionRevision;
    final affectedAccounts = <String>{...state.categoriesByAccount.keys};
    if (accountId != null) affectedAccounts.add(accountId);
    for (final id in affectedAccounts) {
      _accountMutationRevisions[id] = _accountMutationRevision(id) + 1;
      _accountLoadRevisions[id] = _accountLoadRevision(id) + 1;
    }
    final result = await ref
        .read(categoriesServiceProvider)
        .deleteCategory(categoryId, accountId: accountId);
    if (result && ref.mounted && sessionRevision == _sessionRevision) {
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

  void updateLocal(Category category) {
    _accountMutationRevisions[category.accountId] =
        _accountMutationRevision(category.accountId) + 1;
    _upsert(category);
  }

  void invalidateAccount(String accountId) {
    _accountLoadRevisions[accountId] = _accountLoadRevision(accountId) + 1;
    _accountMutationRevisions[accountId] =
        _accountMutationRevision(accountId) + 1;
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
    _sessionRevision++;
    _iconsLoadRevision++;
    _accountLoadRevisions.clear();
    _accountMutationRevisions.clear();
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
