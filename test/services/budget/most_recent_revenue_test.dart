import 'package:budgly/src/models/budget/account_budget.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/services/budget/account_budgets_service.dart';
import 'package:budgly/src/services/providers/firestore/accounts_budget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeBudgetProvider extends AccountBudgetFirestore {
  final List<AccountBudget> budgets;
  int calls = 0;

  FakeBudgetProvider(this.budgets);

  @override
  Future<AccountBudget?> getMostRecentWithRevenue(
    String accountId, {
    required Period before,
    Source source = Source.server,
  }) async {
    calls++;
    return firstRevenueBefore(budgets, before);
  }
}

AccountBudget budget({
  required int year,
  required int month,
  required double revenue,
}) {
  return AccountBudget(
    accountId: 'a1',
    year: year,
    month: month,
    revenue: revenue,
  );
}

void main() {
  group('firstRevenueBefore', () {
    const aug = Period(year: 2026, month: 8);

    test('picks the most recent revenue strictly before the period', () {
      final budgets = [
        budget(year: 2026, month: 7, revenue: 500),
        budget(year: 2026, month: 6, revenue: 900),
        budget(year: 2026, month: 3, revenue: 300),
      ];

      final result = firstRevenueBefore(budgets, aug);

      expect(result?.revenue, 500);
    });

    test('is independent of the input order', () {
      final budgets = [
        budget(year: 2026, month: 3, revenue: 300),
        budget(year: 2026, month: 6, revenue: 900),
        budget(year: 2026, month: 9, revenue: 400),
        budget(year: 2026, month: 7, revenue: 500),
      ];

      final result = firstRevenueBefore(budgets, aug);

      expect(result?.revenue, 500);
    });

    test('never inherits from the selected period itself', () {
      final budgets = [
        budget(year: 2026, month: 7, revenue: 500),
        budget(year: 2026, month: 5, revenue: 300),
      ];

      final result = firstRevenueBefore(
        budgets,
        const Period(year: 2026, month: 7),
      );

      expect(result?.revenue, 300);
    });

    test('never inherits from a future period', () {
      final budgets = [
        budget(year: 2026, month: 9, revenue: 400),
        budget(year: 2026, month: 7, revenue: 500),
      ];

      final result = firstRevenueBefore(budgets, aug);

      expect(result?.revenue, 500, reason: 'September must not leak into August');
    });

    test('returns null when no earlier period carries revenue', () {
      final budgets = [
        budget(year: 2026, month: 3, revenue: 300),
        budget(year: 2026, month: 2, revenue: 200),
      ];

      final result = firstRevenueBefore(
        budgets,
        const Period(year: 2026, month: 2),
      );

      expect(result, isNull);
    });

    test('skips periods without revenue', () {
      final budgets = [
        budget(year: 2026, month: 7, revenue: 0),
        budget(year: 2026, month: 6, revenue: 900),
      ];

      final result = firstRevenueBefore(budgets, aug);

      expect(result?.revenue, 900);
    });
  });

  group('AccountBudgetsService.getMostRecentRevenue', () {
    test('delegates the strict past-window rule to the provider', () async {
      final provider = FakeBudgetProvider([
        budget(year: 2026, month: 7, revenue: 500),
        budget(year: 2026, month: 3, revenue: 300),
      ]);
      final service = AccountBudgetsService(provider: provider);

      final inherited = await service.getMostRecentRevenue(
        'a1',
        before: const Period(year: 2026, month: 8),
      );

      expect(inherited, 500);
    });

    test('caches the result per period', () async {
      final provider = FakeBudgetProvider([
        budget(year: 2026, month: 3, revenue: 300),
      ]);
      final service = AccountBudgetsService(provider: provider);

      await service.getMostRecentRevenue(
        'a1',
        before: const Period(year: 2026, month: 8),
      );
      await service.getMostRecentRevenue(
        'a1',
        before: const Period(year: 2026, month: 8),
      );

      expect(provider.calls, 1);
    });
  });
}