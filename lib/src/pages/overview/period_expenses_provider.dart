import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/state/action_status.dart';
import 'package:budgly/src/state/categories_provider.dart';
import 'package:budgly/src/state/expenses_provider.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/expense/category_expense_summary.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/expense_occurrence.dart';
import 'package:budgly/src/services/calculators/expense_occurrence_calculator.dart';
import 'package:budgly/src/services/calculators/expense_summary_calculator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'period_expenses_provider.g.dart';

class PeriodExpensesState {
  const PeriodExpensesState({
    required this.expenses,
    required this.occurrences,
    required this.categorySummaries,
    required this.isLoaded,
    required this.status,
  });

  final List<Expense> expenses;
  final List<ExpenseOccurrence> occurrences;
  final List<CategoryExpenseSummary> categorySummaries;
  final bool isLoaded;
  final ActionStatus status;
}

@riverpod
class PeriodExpenses extends _$PeriodExpenses {
  late final ExpenseOccurrenceCalculator _occurrenceCalculator;
  late final ExpenseSummaryCalculator _summaryCalculator;

  @override
  PeriodExpensesState build(String accountId, Period period) {
    _occurrenceCalculator = const ExpenseOccurrenceCalculator();
    _summaryCalculator = const ExpenseSummaryCalculator();

    // Sessions are the single source of truth. Keep this provider reactive to
    // session updates (including background cache revalidation), but let
    // `load()` perform its final recomputation after both sessions have loaded.
    // This avoids the old race where a stale snapshot captured before an
    // awaited load could overwrite freshly computed category summaries.
    ref.listen(expensesSessionProvider, (_, _) {
      if (ref.mounted) _recomputeFromSession();
    });
    ref.listen(categoriesSessionProvider, (_, _) {
      if (ref.mounted) _recomputeFromSession();
    });

    return _stateFromSession();
  }

  Future<void> load({bool forceRefresh = false}) async {
    state = PeriodExpensesState(
      expenses: state.expenses,
      occurrences: state.occurrences,
      categorySummaries: state.categorySummaries,
      isLoaded: state.isLoaded,
      status: state.status.loading(),
    );
    try {
      await ref
          .read(expensesSessionProvider.notifier)
          .loadPeriod(accountId, period, forceRefresh: forceRefresh);
      if (!ref.mounted) return;
      await ref
          .read(categoriesSessionProvider.notifier)
          .load(accountId, forceRefresh: forceRefresh);
      if (!ref.mounted) return;
      _recomputeFromSession();
    } catch (e) {
      if (!ref.mounted) return;
      AppLogger.debug('Background overview expense load unavailable: $e');
      state = PeriodExpensesState(
        expenses: state.expenses,
        occurrences: state.occurrences,
        categorySummaries: state.categorySummaries,
        isLoaded: state.isLoaded,
        status: state.status.failure(e).doneLoading(),
      );
      return;
    }
    if (!ref.mounted) return;
    // Read current state (after _recomputeFromSession updated it) to get fresh summaries
    final current = state;
    state = PeriodExpensesState(
      expenses: current.expenses,
      occurrences: current.occurrences,
      categorySummaries: current.categorySummaries,
      isLoaded: true,
      status: current.status.doneLoading(),
    );
  }

  Future<void> refresh() => load(forceRefresh: true);

  PeriodExpensesState _stateFromSession() {
    final expenses = _filter(
      ref.read(expensesSessionProvider).expensesByAccount[accountId] ??
          const [],
    );
    return _buildState(
      expenses,
      ref.read(expensesSessionProvider).loadedAccounts.contains(accountId),
      const ActionStatus.idle(),
    );
  }

  void _recomputeFromSession() {
    state = _buildStateFromSessionPreservingStatus();
  }

  PeriodExpensesState _buildStateFromSessionPreservingStatus() {
    final expenses = _filter(
      ref.read(expensesSessionProvider).expensesByAccount[accountId] ??
          const [],
    );
    final loaded = ref
        .read(expensesSessionProvider)
        .loadedAccounts
        .contains(accountId);
    return _buildState(expenses, loaded, state.status);
  }

  PeriodExpensesState _buildState(
    List<Expense> expenses,
    bool loaded,
    ActionStatus status,
  ) {
    final occurrences = _occurrenceCalculator.forPeriod(expenses, period);
    final categories =
        ref.read(categoriesSessionProvider).categoriesByAccount[accountId] ??
        const [];
    final categoriesById = <String, Category>{
      for (final category in categories)
        if (category.id != null) category.id!: category,
    };
    final summaries = _summaryCalculator.summarizeByCategory(
      occurrences: occurrences,
      resolveCategory: (id) => categoriesById[id],
    );
    return PeriodExpensesState(
      expenses: List.unmodifiable(expenses),
      occurrences: occurrences,
      categorySummaries: summaries,
      isLoaded: loaded,
      status: status,
    );
  }

  List<Expense> _filter(List<Expense> expenses) {
    final range = period.range;
    return expenses.where((expense) {
      if (!expense.isRecurring) return range.contains(expense.debitDate);
      final endExclusive = expense.endDateExclusive;
      return expense.debitDate.isBefore(range.endExclusive) &&
          (endExclusive == null || endExclusive.isAfter(range.start));
    }).toList();
  }
}
