import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/category_expense_summary.dart';
import 'package:budgly/src/pages/overview/account_selection_provider.dart';
import 'package:budgly/src/pages/overview/ui_state.dart';
import 'package:budgly/src/pages/overview/widgets/collapsing_summary_header.dart';
import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/accounts/accounts_service_provider.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../fixtures/builders.dart';

class _FakeAccountsService extends AccountsService {
  _FakeAccountsService(this.values)
    : super(
        analytics: AnalyticsService(),
        syncManager: SyncManager(
          queue: SyncQueue(),
          analytics: AnalyticsService(),
        ),
        syncQueue: SyncQueue(),
      );

  final List<Account> values;
  void Function(List<Account>)? lastOnRevalidated;

  @override
  Future<List<Account>> loadAccounts({
    bool forceRefresh = false,
    void Function(List<Account>)? onRevalidated,
  }) async {
    lastOnRevalidated = onRevalidated;
    return List.of(values);
  }

  void revalidate(List<Account> serverAccounts) =>
      lastOnRevalidated?.call(serverAccounts);
}

/// Mirrors the production `_SummarySliver`: watches the same account-selection
/// record and builds the same `SliverPersistentHeader`/`CollapsingSummaryHeader`
/// delegate, so the whole rebuild chain is exercised.
class _SummaryHarness extends ConsumerWidget {
  const _SummaryHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(
      accountSelectionProvider.select(
        (state) =>
            (accounts: state.accounts, selectedAccount: state.selectedAccount),
      ),
    );
    const period = Period(year: 2026, month: 10);
    return CustomScrollView(
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: CollapsingSummaryHeader(
            accounts: accounts.accounts,
            account: accounts.selectedAccount,
            period: period,
            categorySummaries: const <CategoryExpenseSummary>[],
            revenue: const RevenueSummary(revenue: 0, inheritedRevenue: null),
            currencyCode: 'EUR',
            localeName: 'fr',
            amountDecimalPlaces: 2,
            onSelectAccount: (_) {},
            slideDirection: 1,
            revision: Object.hash(
              accounts.selectedAccount,
              period,
              const <CategoryExpenseSummary>[],
              0.0,
              null,
            ),
            theme: Theme.of(context),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 800)),
      ],
    );
  }
}

void main() {
  Future<void> pumpHarness(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('fr'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('en'), Locale('fr')],
          home: Scaffold(body: _SummaryHarness()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the summary header avatar shows the picture once the account '
      'revalidation resolves the signed URL', (tester) async {
    final service = _FakeAccountsService([
      Fixtures.account(id: 'a1', name: 'Alpha'),
    ]);
    final container = ProviderContainer(
      overrides: [accountsServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    await pumpHarness(tester, container);

    await container.read(accountSelectionProvider.notifier).load();
    await tester.pumpAndSettle();

    // No picture yet: the avatar renders the initial only.
    expect(_networkPictures(tester), isEmpty);

    // Background revalidation resolves the signed URL for the same account.
    service.revalidate([
      Fixtures.account(
        id: 'a1',
        name: 'Alpha',
        picture: 'pic.jpg',
        pictureUrl: 'https://example.test/pic.jpg',
      ),
    ]);
    await tester.pumpAndSettle();

    expect(
      _networkPictures(tester),
      contains('https://example.test/pic.jpg'),
      reason:
          'the header must rebuild and load the avatar image when a '
          'background revalidation resolves the signed URL',
    );
  });
}

List<String> _networkPictures(WidgetTester tester) {
  final urls = <String>[];
  for (final avatar in tester.widgetList<CircleAvatar>(
    find.byType(CircleAvatar),
  )) {
    final image = avatar.foregroundImage;
    if (image is NetworkImage) urls.add(image.url);
  }
  return urls;
}
