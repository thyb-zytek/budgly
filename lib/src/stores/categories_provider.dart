import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/category/category_icon.dart';
import 'package:budgly/src/stores/categories.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'categories_provider.g.dart';

/// Riverpod-observable mirror of [CategoriesStore] (issue M2).
///
/// Same pattern as `AccountsSession`: [CategoriesStore] is not rewritten,
/// its only consumer today is `CategoriesService`
/// (`lib/src/services/categories/categories_service.dart`), not yet
/// migrated (issue M3).
class CategoriesSessionState {
  const CategoriesSessionState({
    required this.categoriesByAccount,
    required this.availableIcons,
    required this.iconsLoaded,
  });

  final Map<String, List<Category>> categoriesByAccount;
  final List<CategoryIcon> availableIcons;
  final bool iconsLoaded;
}

@Riverpod(keepAlive: true)
class CategoriesSession extends _$CategoriesSession {
  CategoriesStore get _store => CategoriesStore.instance;

  @override
  CategoriesSessionState build() {
    _store.addListener(_onStoreChanged);
    ref.onDispose(() => _store.removeListener(_onStoreChanged));
    return _readState();
  }

  CategoriesSessionState _readState() => CategoriesSessionState(
        categoriesByAccount: _store.categoriesByAccount,
        availableIcons: _store.availableIcons,
        iconsLoaded: _store.iconsLoaded,
      );

  void _onStoreChanged() {
    state = _readState();
  }
}
