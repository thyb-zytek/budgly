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
import 'package:budgly/src/state/accounts_provider.dart';
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

Future<void> _pump(WidgetTester tester, ProviderContainer container) async {
  await pumpApp(
    tester,
    UncontrolledProviderScope(
      container: container,
      child: const CategoriesTab(),
    ),
  );
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
}
