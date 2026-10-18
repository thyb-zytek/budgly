import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/pages/undebited_expenses/undebited_expenses_provider.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/services/expenses/expenses_service_provider.dart';
import 'package:budgly/src/state/accounts_provider.dart';
import 'package:budgly/src/state/profile_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mirrors the real [ExpensesService]: its local store (`_periodData`) is
/// *period-scoped*. Only the periods that were explicitly queried are cached,
/// so a non-forced account load answers from that partial projection while a
/// forced load asks the server for the whole account history.
class _PeriodScopedExpensesService extends ExpensesService {
  _PeriodScopedExpensesService(this.serverExpenses)
    : super(analytics: AnalyticsService());

  /// The authoritative account history a forced (server) load would return.
  final Map<String, List<Expense>> serverExpenses;

  /// Periods already fetched into the local store (mirrors `_periodData`).
  final Set<Period> _cachedPeriods = {};

  List<Expense> _all(String accountId) =>
      List.unmodifiable(serverExpenses[accountId] ?? const []);

  List<Expense> _cached(String accountId) => List.unmodifiable([
    for (final expense in _all(accountId))
      if (_cachedPeriods.contains(Period.fromDate(expense.debitDate))) expense,
  ]);

  List<Expense> _period(String accountId, Period period) => List.unmodifiable([
    for (final expense in _all(accountId))
      if (Period.fromDate(expense.debitDate) == period) expense,
  ]);

  @override
  List<Expense> getExpensesForAccount(String accountId) => _cached(accountId);

  @override
  Future<List<Expense>> listExpensesForAccount(
    String accountId, {
    bool forceRefresh = false,
  }) async => forceRefresh ? _all(accountId) : _cached(accountId);

  @override
  Future<List<Expense>> listExpensesForAccountBefore(
    String accountId,
    DateTime endExclusive, {
    bool forceRefresh = false,
  }) async {
    final source = forceRefresh ? _all(accountId) : _cached(accountId);
    return source
        .where((expense) => expense.debitDate.isBefore(endExclusive))
        .toList(growable: false);
  }

  @override
  List<Expense>? cachedExpensesForPeriod(String accountId, Period period) =>
      _cachedPeriods.contains(period) ? _period(accountId, period) : null;

  @override
  Future<List<Expense>> listExpensesForPeriod(
    String accountId,
    Period period, {
    String? categoryId,
    bool forceRefresh = false,
    void Function(List<Expense>)? onRevalidated,
  }) async {
    _cachedPeriods.add(period);
    return _period(accountId, period);
  }

  @override
  Future<Expense> moveOccurrenceToDate(
    Expense expense,
    DateTime occurrenceDate,
    DateTime targetDate, {
    required bool markDebited,
  }) async {
    // Mirrors ExpensesService.moveOccurrenceToDate plus the optimistic update
    // of the period-scoped store: the expense leaves its original period and
    // is only visible again once the destination period has been queried.
    final updated = expense.copyWith(
      debitDate: targetDate,
      isDebited: markDebited,
    );
    final expenses = serverExpenses[expense.accountId]!;
    expenses[expenses.indexWhere((e) => e.id == expense.id)] = updated;
    return updated;
  }
}

const _profile = ProfileSessionState(
  currentUser: null,
  hasLoaded: true,
  themeMode: ThemeMode.system,
  locale: Locale('fr'),
  currency: 'EUR',
  amountDecimalPlaces: 2,
);

Account _account(String id) =>
    Account(id: id, name: 'Compte', color: Colors.blueGrey);

Expense _expenseIn(Period period, {required String id, required String name}) =>
    Expense(
      id: id,
      accountId: 'a1',
      categoryId: 'category-1',
      name: name,
      amount: 100,
      debitDate: DateTime(period.year, period.month, 10),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('reporting an occurrence keeps the other undebited occurrences of the '
      'account in the list', () async {
    final now = Period.fromDate(DateTime.now());
    final previous = now.previous;
    // An occurrence two months back: no caller caches that period, so the
    // local store cannot answer for it.
    final older = previous.previous;

    final service = _PeriodScopedExpensesService({
      'a1': [
        _expenseIn(older, id: 'older', name: 'Ancien loyer'),
        _expenseIn(previous, id: 'previous', name: 'Loyer précédent'),
      ],
    });
    final container = ProviderContainer(
      overrides: [
        expensesServiceProvider.overrideWithValue(service),
        accountsSessionProvider.overrideWithValue(
          AccountsSessionState(
            accounts: List.unmodifiable([_account('a1')]),
            hasLoaded: true,
          ),
        ),
        profileSessionProvider.overrideWithValue(_profile),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(undebitedExpensesProvider, (_, _) {});
    addTearDown(subscription.close);
    final viewModel = container.read(undebitedExpensesProvider.notifier);

    await viewModel.ensureDataLoaded();
    expect(
      viewModel.state.displayed.map((occurrence) => occurrence.expense.id),
      containsAll(<String>{'older', 'previous'}),
    );

    final handled = viewModel.state.allOccurrences.firstWhere(
      (occurrence) => occurrence.expense.id == 'previous',
    );
    await viewModel.carryToCurrentPeriod(handled);
    // The removal animation keeps the handled card for a short while.
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(
      viewModel.state.allOccurrences
          .map((occurrence) => occurrence.expense.id)
          .toSet(),
      {'older'},
      reason:
          'reloading the account from the period-scoped store would project '
          'only the Overview-cached periods over the shared session and '
          'silently drop the older undebited occurrence',
    );
    expect(
      viewModel.state.displayed.map((occurrence) => occurrence.expense.id),
      ['older'],
    );
  });
}
