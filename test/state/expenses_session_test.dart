import 'package:budgly/src/state/expenses_provider.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/services/expenses/expenses_service_provider.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class _FakeExpensesService extends ExpensesService {
  _FakeExpensesService(this.values) : super(analytics: AnalyticsService());

  final List<Expense> values;
  int listPeriodCalls = 0;
  int listAccountCalls = 0;

  @override
  Future<List<Expense>> listExpensesForAccount(
    String accountId, {
    bool forceRefresh = false,
  }) async {
    listAccountCalls++;
    return values.where((expense) => expense.accountId == accountId).toList();
  }

  void Function(List<Expense>)? _lastOnRevalidated;

  @override
  Future<List<Expense>> listExpensesForPeriod(
    String accountId,
    Period period, {
    String? categoryId,
    bool forceRefresh = false,
    void Function(List<Expense>)? onRevalidated,
  }) async {
    listPeriodCalls++;
    _lastOnRevalidated = onRevalidated;
    return values.where((expense) => expense.accountId == accountId).toList();
  }

  /// Invokes the `onRevalidated` callback the session passed on the most
  /// recent `listExpensesForPeriod` call, as `ExpensesService` itself would
  /// once its background revalidation completes.
  void simulateBackgroundRevalidation(List<Expense> serverExpenses) {
    _lastOnRevalidated?.call(serverExpenses);
  }
}

Expense _expense(String id, String accountId, DateTime debitDate) => Expense(
  id: id,
  accountId: accountId,
  categoryId: 'category',
  name: id,
  amount: 10,
  debitDate: debitDate,
);

void main() {
  test('loadPeriod merges into the account cache without duplicates', () async {
    final first = _expense('e1', 'a1', DateTime(2026, 8, 1));
    final second = _expense('e2', 'a1', DateTime(2026, 8, 2));
    final service = _FakeExpensesService([first, second]);
    final container = ProviderContainer(
      overrides: [expensesServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    final session = container.read(expensesSessionProvider.notifier);
    await session.loadPeriod('a1', const Period(year: 2026, month: 8));
    await session.loadPeriod('a1', const Period(year: 2026, month: 8));

    final state = container.read(expensesSessionProvider);
    expect(state.loadedAccounts, contains('a1'));
    expect(state.expensesByAccount['a1']!.map((e) => e.id), ['e2', 'e1']);
    expect(state.expensesByAccount['a1'], hasLength(2));
    expect(session.getExpenseById('e2'), same(second));
    expect(service.listPeriodCalls, 2);
  });

  test('RL-01 §3.2: a background revalidation reported by the service updates '
      'the shared state so listeners (Overview, ...) rebuild', () async {
    final first = _expense('e1', 'a1', DateTime(2026, 8, 1));
    final service = _FakeExpensesService([first]);
    final container = ProviderContainer(
      overrides: [expensesServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    final session = container.read(expensesSessionProvider.notifier);
    await session.loadPeriod('a1', const Period(year: 2026, month: 8));
    expect(
      container
          .read(expensesSessionProvider)
          .expensesByAccount['a1']!
          .map((e) => e.id),
      ['e1'],
    );

    final second = _expense('e2', 'a1', DateTime(2026, 8, 3));
    service.simulateBackgroundRevalidation([first, second]);

    expect(
      container
          .read(expensesSessionProvider)
          .expensesByAccount['a1']!
          .map((e) => e.id),
      containsAll(['e1', 'e2']),
      reason:
          'the session must reflect the server-confirmed data, not stay '
          'frozen on the first cached snapshot',
    );
  });

  test('getExpenseById searches every cached account', () async {
    final first = _expense('e1', 'a1', DateTime(2026, 8, 1));
    final second = _expense('e2', 'a2', DateTime(2026, 8, 2));
    final service = _FakeExpensesService([first, second]);
    final container = ProviderContainer(
      overrides: [expensesServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    final session = container.read(expensesSessionProvider.notifier);
    await session.loadAccount('a1');
    await session.loadAccount('a2');

    expect(session.getExpenseById('e2'), same(second));
    expect(session.getExpenseById('missing'), isNull);
    expect(service.listAccountCalls, 2);
  });
}
