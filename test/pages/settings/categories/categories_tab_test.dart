import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/category/category_icon.dart';
import 'package:budgly/src/pages/settings/categories/categories_settings_provider.dart';
import 'package:budgly/src/pages/settings/categories/tab.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/categories/categories_service.dart';
import 'package:budgly/src/services/categories/categories_service_provider.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:budgly/src/shared/domain/widgets/categories/category_icon_view.dart';
import 'package:budgly/src/state/accounts_provider.dart';
import 'package:budgly/src/state/categories_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../fixtures/builders.dart';
import '../../../helpers.dart';

/// Serves the category loads triggered by `selectAccount` without touching
/// any backend. A local sync pair on purpose: the shared test queue deadlocks
/// behind its internal lock in a fake-async widget zone (see the comment in
/// `accounts_tab_test.dart`).
class _FakeCategoriesService extends CategoriesService {
  _FakeCategoriesService()
    : super(
        analytics: AnalyticsService(),
        syncManager: SyncManager(
          queue: SyncQueue(),
          analytics: AnalyticsService(),
        ),
        syncQueue: SyncQueue(),
      );

  @override
  Future<List<CategoryIcon>> loadAvailableIcons() async => const [];

  @override
  Future<List<Category>> listCategoriesByAccount(
    String accountId, {
    bool forceRefresh = false,
    void Function(List<Category>)? onRevalidated,
  }) async => const [];
}

ProviderContainer _container({required List<Account> accounts}) {
  final service = _FakeCategoriesService();
  final container = ProviderContainer(
    overrides: [
      accountsSessionProvider.overrideWithValue(
        AccountsSessionState(accounts: accounts, hasLoaded: true),
      ),
      categoriesServiceProvider.overrideWithValue(service),
    ],
  );
  // The settings notifier keeps its own selection, exactly like on screen:
  // on sign-out the accounts session is cleared while this state still
  // points at the account selected before.
  container
      .read(categoriesSettingsProvider.notifier)
      .selectAccount(Fixtures.account(id: 'stale'));
  return container;
}

/// Seeds the shared categories session so the first account already counts as
/// loaded (no remote reload) and its persisted categories are rendered.
ProviderContainer _seededContainer({
  required List<Account> accounts,
  required Map<String, List<Category>> categoriesByAccount,
}) {
  return ProviderContainer(
    overrides: [
      accountsSessionProvider.overrideWithValue(
        AccountsSessionState(accounts: accounts, hasLoaded: true),
      ),
      categoriesServiceProvider.overrideWithValue(_FakeCategoriesService()),
      categoriesSessionProvider.overrideWithValue(
        CategoriesSessionState(
          categoriesByAccount: categoriesByAccount,
          availableIcons: const [],
          iconsLoaded: true,
          loadedAccounts: categoriesByAccount.keys.toSet(),
        ),
      ),
    ],
  );
}

Future<void> _pump(WidgetTester tester, ProviderContainer container) async {
  await pumpApp(
    tester,
    UncontrolledProviderScope(
      container: container,
      child: const CategoriesTab(),
    ),
  );
}

/// Taps the "new category" FAB and lets the async draft creation settle.
///
/// The draft form runs a looping pulse hint, so `pumpAndSettle` never returns;
/// bounded pumps are used instead.
Future<void> _tapAddCategory(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.add_rounded));
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets(
    'renders safely when the account list is empty while an account is '
    'still selected (sign-out)',
    (tester) async {
      final container = _container(accounts: const []);
      addTearDown(container.dispose);

      await _pump(tester, container);

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Aucun compte trouv'), findsOneWidget);
    },
  );

  testWidgets('shows the selected account when the session has accounts', (
    tester,
  ) async {
    final container = _container(
      accounts: [Fixtures.account(id: 'a1', name: 'Courant')],
    );
    addTearDown(container.dispose);

    await _pump(tester, container);

    expect(tester.takeException(), isNull);
    expect(find.text('Courant'), findsWidgets);
  });

  testWidgets('a new category form starts from its draft avatar', (
    tester,
  ) async {
    final container = _container(
      accounts: [Fixtures.account(id: 'a1', name: 'Courant')],
    );
    addTearDown(container.dispose);

    await _pump(tester, container);

    await _tapAddCategory(tester);

    final draft = container
        .read(categoriesSettingsProvider)
        .localCategories
        .single;
    final avatar = tester.widget<CategoryIconView>(
      find.byType(CategoryIconView),
    );

    // The draft carries the default icon and its own (random) colour; the tab
    // must render those instead of its stale placeholder fields.
    expect(avatar.icon, AppConstants.defaultCategoryIcon);
    expect(avatar.color, draft.color);
  });

  testWidgets('a new category ignores the icon of a previously opened form', (
    tester,
  ) async {
    final container = _container(
      accounts: [Fixtures.account(id: 'a1', name: 'Courant')],
    );
    addTearDown(container.dispose);

    await _pump(tester, container);

    // Open another form first (an edit): its icon must not leak into the
    // avatar of the next draft.
    final editedIcon = Fixtures.categoryIcon(
      iconName: 'restaurant',
      iconCode: 0xe56c,
    );
    container
        .read(categoriesSettingsProvider.notifier)
        .setEditingCategory(
          Category(
            id: 'cat-9',
            name: 'Resto',
            accountId: 'a1',
            icon: editedIcon,
            color: Colors.purple,
          ),
        );
    await tester.pump();

    await _tapAddCategory(tester);

    final avatar = tester.widget<CategoryIconView>(
      find.byType(CategoryIconView),
    );

    expect(avatar.icon, AppConstants.defaultCategoryIcon);
    expect(avatar.icon.iconCode, isNot(editedIcon.iconCode));
  });

  testWidgets('an opened edit form shows that category avatar', (tester) async {
    final existing = Fixtures.category(
      id: 'cat-9',
      accountId: 'a1',
      name: 'Resto',
      icon: Fixtures.categoryIcon(iconName: 'restaurant', iconCode: 0xe56c),
      color: Colors.purple,
    );
    final container = _seededContainer(
      accounts: [Fixtures.account(id: 'a1', name: 'Courant')],
      categoriesByAccount: {
        'a1': [existing],
      },
    );
    addTearDown(container.dispose);

    await _pump(tester, container);

    container
        .read(categoriesSettingsProvider.notifier)
        .setEditingCategory(existing);
    await tester.pump();

    final avatar = tester.widget<CategoryIconView>(
      find.byType(CategoryIconView),
    );

    expect(avatar.icon, existing.icon);
    expect(avatar.color, existing.color);
  });
}
