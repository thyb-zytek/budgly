import 'package:budgly/src/models/budget/account_budget.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/budget/account_budgets_service.dart';
import 'package:budgly/src/services/providers/firestore/accounts_budget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Returns a scripted response per call, so a test can distinguish a
/// background revalidation's result from a later explicit refresh's result.
/// The Firestore `Source` parameter is ignored: the fake always answers, the
/// same way the real `AccountBudgetFirestore` does whether or not the local
/// persistence layer happens to have a cached document.
class ScriptedAccountBudgetFirestore extends AccountBudgetFirestore {
  final List<AccountBudget?> responses;
  int calls = 0;

  ScriptedAccountBudgetFirestore(this.responses);

  @override
  Future<AccountBudget?> get(
    String accountId,
    int year,
    int month, {
    Source source = Source.server,
  }) async {
    final response = responses[calls.clamp(0, responses.length - 1)];
    calls++;
    return response;
  }
}

void main() {
  AccountBudget budget(double revenue) =>
      AccountBudget(accountId: 'a1', year: 2026, month: 3, revenue: revenue);

  AccountBudgetsService service(ScriptedAccountBudgetFirestore provider) =>
      AccountBudgetsService(provider: provider, analytics: AnalyticsService());

  test(
    'a cache-hit background revalidation reaches onRevalidated instead of being silently dropped',
    () async {
      final provider = ScriptedAccountBudgetFirestore([
        budget(1000),
        budget(1500),
      ]);
      final svc = service(provider);

      final revalidated = <AccountBudget?>[];
      final cached = await svc.loadRevenue(
        'a1',
        2026,
        3,
        onRevalidated: revalidated.add,
      );
      expect(cached?.revenue, 1000);

      await Future<void>.delayed(Duration.zero);
      expect(provider.calls, 2);
      expect(revalidated, hasLength(1));
      expect(revalidated.single?.revenue, 1500);
    },
  );

  test(
    'RL-01 §3.2: a background revalidation does not leak the in-flight guard '
    'and block a later forced refresh',
    () async {
      final provider = ScriptedAccountBudgetFirestore([
        budget(1000), // first cache-hit call
        budget(1000), // its background revalidation
        budget(2000), // explicit forceRefresh afterwards
      ]);
      final svc = service(provider);

      await svc.loadRevenue('a1', 2026, 3);
      await Future<void>.delayed(Duration.zero);
      expect(
        provider.calls,
        2,
        reason: 'the background revalidation must actually run',
      );

      final forced = await svc.loadRevenue('a1', 2026, 3, forceRefresh: true);
      expect(provider.calls, 3);
      expect(forced?.revenue, 2000);
    },
  );
}
