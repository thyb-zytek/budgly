import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/pages/overview/overview_provider.dart';
import 'package:budgly/src/pages/overview/revenue_provider.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/budget/account_budgets_service.dart';
import 'package:budgly/src/services/budget/account_budgets_service_provider.dart';
import 'package:budgly/src/state/accounts_provider.dart';
import 'package:budgly/src/state/profile_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/builders.dart';
import '../../mocks/fakes.dart';

const _defaultProfile = ProfileSessionState(
  currentUser: null,
  hasLoaded: true,
  themeMode: ThemeMode.system,
  locale: Locale('fr'),
  currency: 'EUR',
  amountDecimalPlaces: 2,
);

ProviderContainer _container(FakeAccountBudgetProvider budgets) {
  final account = Fixtures.account(id: 'a1');
  return ProviderContainer(
    overrides: [
      accountBudgetsServiceProvider.overrideWithValue(
        AccountBudgetsService(provider: budgets, analytics: AnalyticsService()),
      ),
      accountsSessionProvider.overrideWithValue(
        AccountsSessionState(accounts: [account], hasLoaded: true),
      ),
      profileSessionProvider.overrideWithValue(_defaultProfile),
    ],
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const current = Period(year: 2026, month: 10);
  const next = Period(year: 2026, month: 11);

  Future<void> enterRevenueOnCurrentPeriod(
    ProviderContainer container,
    FakeAccountBudgetProvider budgets,
  ) async {
    // The summary and the revenue editor watch the current period, exactly
    // like OverviewContent does while the user fills in the form.
    final currentSub = container.listen(
      revenueProvider('a1', current),
      (_, _) {},
    );
    addTearDown(currentSub.close);

    await container.read(revenueProvider('a1', current).notifier).load();
    await container
        .read(revenueProvider('a1', current).notifier)
        .setRevenue(2000);
    expect(
      container.read(revenueProvider('a1', current)).revenue,
      2000,
      reason: 'the entered revenue is visible on the current period',
    );
    expect(
      budgets.store['a1_2026_10']?.revenue,
      2000,
      reason: 'the revenue is persisted for the current period',
    );
  }

  test(
    'service: the revenue written for October is the fallback for November',
    () async {
      final budgets = FakeAccountBudgetProvider();
      final service = AccountBudgetsService(
        provider: budgets,
        analytics: AnalyticsService(),
      );

      await service.setRevenue('a1', 2026, 10, 2000);
      await Future<void>.delayed(Duration.zero);

      final value = await service.getMostRecentRevenue('a1', before: next);

      expect(value, 2000);
    },
  );

  test('overview: revenue entered on the current period propagates to the next '
      'period after a period change', () async {
    final budgets = FakeAccountBudgetProvider();
    final container = _container(budgets);
    addTearDown(container.dispose);
    await enterRevenueOnCurrentPeriod(container, budgets);

    // The user taps the next-month chevron (or swipes): selectPeriod kicks
    // off the load while no widget watches the new period's provider yet.
    container.read(overviewProvider.notifier).selectPeriod(next);
    expect(container.read(overviewProvider).selectedPeriod, next);

    // The widget tree rebuilds on the following frame and then watches the
    // new period's provider, which is materialized anew at that point.
    await Future<void>.delayed(Duration.zero);
    final nextSub = container.listen(revenueProvider('a1', next), (_, _) {});
    addTearDown(nextSub.close);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final state = container.read(revenueProvider('a1', next));
    expect(
      state.isLoaded,
      isTrue,
      reason: 'the shared session recorded the target period load',
    );
    expect(
      state.isEstimated,
      isTrue,
      reason:
          'a period without its own revenue must inherit the most recent '
          'revenue of a strictly earlier period',
    );
    expect(state.effectiveRevenue, 2000);
  });

  test(
    'overview: a period watched right after the period change also inherits',
    () async {
      final budgets = FakeAccountBudgetProvider();
      final container = _container(budgets);
      addTearDown(container.dispose);
      await enterRevenueOnCurrentPeriod(container, budgets);

      container.read(overviewProvider.notifier).selectPeriod(next);
      final nextSub = container.listen(revenueProvider('a1', next), (_, _) {});
      addTearDown(nextSub.close);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(revenueProvider('a1', next));
      expect(state.isEstimated, isTrue);
      expect(state.effectiveRevenue, 2000);
    },
  );

  test(
    'overview: the target period never inherits from itself or a later one',
    () async {
      final budgets = FakeAccountBudgetProvider()
        ..store['a1_2026_12'] = Fixtures.budget(
          accountId: 'a1',
          period: const Period(year: 2026, month: 12),
          revenue: 999,
        );
      final container = _container(budgets);
      addTearDown(container.dispose);

      final sub = container.listen(revenueProvider('a1', next), (_, _) {});
      addTearDown(sub.close);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(revenueProvider('a1', next));
      expect(
        state.inheritedRevenue,
        isNull,
        reason: 'a revenue dated after the target period must never be used',
      );
    },
  );
}
