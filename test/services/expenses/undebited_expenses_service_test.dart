import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/services/expenses/undebited_expenses_service.dart';
import 'package:budgly/src/services/offline/local_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeUndebitedExpensesService extends ExpensesService {
  List<Expense> accountExpenses = const [];
  final List<(Expense, DateTime, DateTime, bool)> moves = [];
  final List<(Expense, DateTime)> marks = [];

  @override
  Future<List<Expense>> listExpensesForAccount(
    String accountId, {
    bool forceRefresh = false,
  }) async => accountExpenses;

  @override
  Future<Expense> markOccurrenceDebited(Expense expense, DateTime date) async {
    marks.add((expense, date));
    return expense.copyWith(isDebited: true);
  }

  @override
  Future<Expense> moveOccurrenceToDate(
    Expense expense,
    DateTime occurrenceDate,
    DateTime targetDate, {
    required bool markDebited,
  }) async {
    moves.add((expense, occurrenceDate, targetDate, markDebited));
    return expense;
  }
}

/// Simulates a cold start: the account store already holds the current-period
/// expenses (so it is non-empty) but the previous period has never been loaded.
/// Loading the previous period mirrors the real [ExpensesService], which
/// upserts it into the store.
class ColdStartUndebitedExpensesService extends FakeUndebitedExpensesService {
  List<Expense> previousPeriodExpenses = const [];
  int previousPeriodLoads = 0;
  final Set<Period> _loadedPeriods = {};

  @override
  Future<List<Expense>> listExpensesForPeriod(
    String accountId,
    Period period, {
    String? categoryId,
    bool forceRefresh = false,
  }) async {
    previousPeriodLoads++;
    accountExpenses = [...accountExpenses, ...previousPeriodExpenses];
    _loadedPeriods.add(period);
    return List.unmodifiable(previousPeriodExpenses);
  }

  @override
  List<Expense>? cachedExpensesForPeriod(String accountId, Period period) {
    if (_loadedPeriods.contains(period)) {
      return List.unmodifiable(previousPeriodExpenses);
    }
    return null;
  }

  @override
  Future<List<Expense>> listExpensesForAccount(
    String accountId, {
    bool forceRefresh = false,
  }) async =>
      List.unmodifiable(accountExpenses);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Expense expense({
    String id = 'expense-1',
    String name = 'Rent',
    double amount = 900,
    DateTime? debitDate,
    DateTime? endDate,
    RecurrenceType recurrence = RecurrenceType.none,
    bool isDebited = false,
  }) => Expense(
        id: id,
        accountId: 'account-1',
        categoryId: 'category-1',
        name: name,
        amount: amount,
        debitDate: debitDate ?? DateTime(2026, 8, 15),
        endDate: endDate,
        recurrence: recurrence,
        isDebited: isDebited,
      );

  group('trigger', () {
    test('does not show before being initialized', () async {
      final service = UndebitedExpensesService(
        expensesService: FakeUndebitedExpensesService(),
      );
      expect(service.shouldShow, isFalse);
      service.dispose();
    });

    test('shows immediately after refresh when showImmediately is true', () async {
      final expenses = FakeUndebitedExpensesService()
        ..accountExpenses = [
          expense(name: 'Rent', debitDate: DateTime(2026, 8, 15)),
        ];
      final service = UndebitedExpensesService(expensesService: expenses);

      await service.refresh(
        accountId: 'account-1',
        current: const Period(year: 2026, month: 9),
        showImmediately: true,
      );

      expect(service.count, 1);
      expect(service.shouldShow, isTrue);

      service.dispose();
      expenses.dispose();
    });

    test('shows whenever pending expenses exist without a stored dismissal', () async {
      final expenses = FakeUndebitedExpensesService()
        ..accountExpenses = [
          expense(name: 'Rent', debitDate: DateTime(2026, 8, 15)),
        ];
      final service = UndebitedExpensesService(expensesService: expenses);

      await service.refresh(
        accountId: 'account-1',
        current: const Period(year: 2026, month: 9),
      );

      expect(service.count, 1);
      expect(service.shouldShow, isTrue);

      service.dispose();
      expenses.dispose();
    });

    test('dismiss hides the banner but re-arms for a new reporting month',
        () async {
      final expenses = FakeUndebitedExpensesService()
        ..accountExpenses = [
          expense(name: 'Rent', debitDate: DateTime(2026, 8, 15)),
        ];
      final cache = LocalCache();
      final service = UndebitedExpensesService(
        expensesService: expenses,
        localCache: cache,
      );

      await service.refresh(
        accountId: 'account-1',
        current: const Period(year: 2026, month: 9),
        showImmediately: true,
      );
      expect(service.shouldShow, isTrue);

      await service.dismiss();
      expect(service.shouldShow, isFalse);
      final persisted = await cache.loadUndebitedBannerDismissedAt('account-1');
      expect(persisted, isNotNull);
      expect(persisted!.period, const Period(year: 2026, month: 9));

      // Refreshing for the same month without showImmediately stays dismissed.
      await service.refresh(
        accountId: 'account-1',
        current: const Period(year: 2026, month: 9),
      );
      expect(service.shouldShow, isFalse);

      // A new reporting month re-arms the banner, without showImmediately.
      await service.refresh(
        accountId: 'account-1',
        current: const Period(year: 2026, month: 10),
      );
      expect(service.shouldShow, isTrue);

      service.dispose();
      expenses.dispose();
    });

    test('banner is hidden when no undebited expense remains', () async {
      final expenses = FakeUndebitedExpensesService();
      final service = UndebitedExpensesService(expensesService: expenses);

      await service.refresh(
        accountId: 'account-1',
        current: const Period(year: 2026, month: 9),
        showImmediately: true,
      );
      expect(service.shouldShow, isFalse);

      service.dispose();
      expenses.dispose();
    });
  });

  group('retrieval', () {
    test('collects undebited occurrences from every previous period', () async {
      final expenses = FakeUndebitedExpensesService()
        ..accountExpenses = [
          expense(name: 'August rent', debitDate: DateTime(2026, 8, 15)),
          expense(name: 'July rent', debitDate: DateTime(2026, 7, 2)),
          expense(name: 'Already debited', debitDate: DateTime(2026, 8, 20), isDebited: true),
          expense(
            name: 'Monthly gym',
            debitDate: DateTime(2026, 7, 10),
            recurrence: RecurrenceType.monthly,
            endDate: DateTime(2026, 7, 31),
          ),
        ];
      final service = UndebitedExpensesService(expensesService: expenses);

      await service.refresh(
        accountId: 'account-1',
        current: const Period(year: 2026, month: 9),
        showImmediately: true,
      );

      // July, July (gym), August occurrences are pending;
      // the debited one and the current-period projection are excluded.
      expect(service.count, 3);
      expect(service.occurrences.map((o) => o.name),
          ['July rent', 'Monthly gym', 'August rent']);
      expect(
        service.occurrences.where((o) => o.isDebited),
        isEmpty,
      );

      service.dispose();
      expenses.dispose();
    });

    test('keeps occurrences sorted by ascending date', () async {
      final expenses = FakeUndebitedExpensesService()
        ..accountExpenses = [
          expense(name: 'August rent', debitDate: DateTime(2026, 8, 25)),
          expense(name: 'June rent', debitDate: DateTime(2026, 6, 10)),
          expense(name: 'July rent', debitDate: DateTime(2026, 7, 4)),
          expense(name: 'Oldest', debitDate: DateTime(2026, 3, 1)),
        ];
      final service = UndebitedExpensesService(expensesService: expenses);

      await service.refresh(
        accountId: 'account-1',
        current: const Period(year: 2026, month: 9),
        showImmediately: true,
      );

      final dates = service.occurrences.map((o) => o.date).toList();
      expect(dates, List.of(dates)..sort());

      service.dispose();
      expenses.dispose();
    });

    test('uses the reporting current month as the cutoff, independent of a later Overview month', () async {
      final expenses = FakeUndebitedExpensesService()
        ..accountExpenses = [
          expense(name: 'August pending', debitDate: DateTime(2026, 8, 15)),
          expense(name: 'September pending', debitDate: DateTime(2026, 9, 15)),
          expense(name: 'October pending', debitDate: DateTime(2026, 10, 15)),
        ];
      final service = UndebitedExpensesService(expensesService: expenses);

      // The Overview may be browsing November, but the banner's reporting
      // target remains the real current month: September 2026.
      await service.refresh(
        accountId: 'account-1',
        current: const Period(year: 2026, month: 9),
        showImmediately: true,
      );

      expect(service.currentPeriod, const Period(year: 2026, month: 9));
      expect(service.occurrences.map((o) => o.name), ['August pending']);
      expect(service.shouldShow, isTrue);

      service.dispose();
      expenses.dispose();
    });

    test('ignores expenses that start after the current period', () async {
      final expenses = FakeUndebitedExpensesService()
        ..accountExpenses = [
          expense(name: 'Future', debitDate: DateTime(2026, 10, 1)),
        ];
      final service = UndebitedExpensesService(expensesService: expenses);

      await service.refresh(
        accountId: 'account-1',
        current: const Period(year: 2026, month: 9),
        showImmediately: true,
      );

      expect(service.count, 0);

      service.dispose();
      expenses.dispose();
    });

    test('reloads when the expenses service notifies', () async {
      final expenses = FakeUndebitedExpensesService()
        ..accountExpenses = [
          expense(name: 'Rent', debitDate: DateTime(2026, 8, 15)),
        ];
      final service = UndebitedExpensesService(expensesService: expenses);

      await service.refresh(
        accountId: 'account-1',
        current: const Period(year: 2026, month: 9),
        showImmediately: true,
      );
      expect(service.count, 1);

      expenses.accountExpenses = [];
      expenses.notifyListeners();
      await Future<void>.delayed(Duration.zero);
      expect(service.count, 0);

      service.dispose();
      expenses.dispose();
    });

    test('loads the previous period on cold start even when the store already has current-period data',
        () async {
      final expenses = ColdStartUndebitedExpensesService()
        ..accountExpenses = [
          expense(
            id: 'sep',
            name: 'Current',
            debitDate: DateTime(2026, 9, 3),
            isDebited: true,
          ),
        ]
        ..previousPeriodExpenses = [
          expense(name: 'Rent', debitDate: DateTime(2026, 8, 15)),
        ];
      final service = UndebitedExpensesService(expensesService: expenses);

      await service.refresh(
        accountId: 'account-1',
        current: const Period(year: 2026, month: 9),
        showImmediately: true,
      );

      // The store was non-empty (current month) but the previous period had
      // never been loaded: the banner must still detect the undebited rent.
      expect(expenses.previousPeriodLoads, 1);
      expect(service.count, 1);
      expect(service.occurrences.single.name, 'Rent');
      expect(service.shouldShow, isTrue);

      service.dispose();
      expenses.dispose();
    });

    test('does not reload the previous period once it is already loaded',
        () async {
      final expenses = ColdStartUndebitedExpensesService()
        ..accountExpenses = [
          expense(
            id: 'sep',
            name: 'Current',
            debitDate: DateTime(2026, 9, 3),
            isDebited: true,
          ),
        ]
        ..previousPeriodExpenses = [
          expense(name: 'Rent', debitDate: DateTime(2026, 8, 15)),
        ];
      final service = UndebitedExpensesService(expensesService: expenses);

      await service.refresh(
        accountId: 'account-1',
        current: const Period(year: 2026, month: 9),
        showImmediately: true,
      );
      expect(expenses.previousPeriodLoads, 1);

      // A store notification reloads the banner without re-fetching the
      // previous period, which is already cached.
      expenses.notifyListeners();
      await Future<void>.delayed(Duration.zero);

      expect(expenses.previousPeriodLoads, 1);
      expect(service.count, 1);

      service.dispose();
      expenses.dispose();
    });
  });

  group('actions', () {
    test('carries one occurrence to the current period without debiting', () async {
      final expenses = FakeUndebitedExpensesService()
        ..accountExpenses = [
          expense(id: 'expense-1', name: 'Rent', debitDate: DateTime(2026, 8, 15)),
        ];
      final service = UndebitedExpensesService(expensesService: expenses);

      await service.refresh(
        accountId: 'account-1',
        current: const Period(year: 2026, month: 9),
        showImmediately: true,
      );
      await service.carryOccurrenceToCurrentPeriod(service.occurrences.single);

      expect(expenses.moves, hasLength(1));
      final (moved, source, target, markDebited) = expenses.moves.single;
      expect(source, DateTime(2026, 8, 15));
      expect(target, DateTime(2026, 9, 1));
      expect(markDebited, isFalse);
      expect(moved.id, 'expense-1');

      service.dispose();
      expenses.dispose();
    });

    test('debits one occurrence on its original period', () async {
      final expenses = FakeUndebitedExpensesService()
        ..accountExpenses = [
          expense(id: 'expense-1', name: 'Rent', debitDate: DateTime(2026, 7, 5)),
        ];
      final service = UndebitedExpensesService(expensesService: expenses);

      await service.refresh(
        accountId: 'account-1',
        current: const Period(year: 2026, month: 9),
        showImmediately: true,
      );
      await service.debitOccurrenceOnOriginalPeriod(service.occurrences.single);

      expect(expenses.marks, hasLength(1));
      expect(expenses.marks.single.$1.id, 'expense-1');
      expect(expenses.marks.single.$2, DateTime(2026, 7, 5));

      service.dispose();
      expenses.dispose();
    });

    test('debits one occurrence on the current period', () async {
      final expenses = FakeUndebitedExpensesService()
        ..accountExpenses = [
          expense(id: 'expense-1', name: 'Rent', debitDate: DateTime(2026, 7, 5)),
        ];
      final service = UndebitedExpensesService(expensesService: expenses);

      await service.refresh(
        accountId: 'account-1',
        current: const Period(year: 2026, month: 9),
        showImmediately: true,
      );
      await service.debitOccurrenceOnCurrentPeriod(service.occurrences.single);

      expect(expenses.moves, hasLength(1));
      final (_, source, target, markDebited) = expenses.moves.single;
      expect(source, DateTime(2026, 7, 5));
      expect(target, DateTime(2026, 9, 1));
      expect(markDebited, isTrue);

      service.dispose();
      expenses.dispose();
    });

    test('carrying all moves every pending occurrence to the current period', () async {
      final expenses = FakeUndebitedExpensesService()
        ..accountExpenses = [
          expense(id: 'expense-1', name: 'Rent', debitDate: DateTime(2026, 8, 15)),
          expense(id: 'expense-2', name: 'Gym', debitDate: DateTime(2026, 7, 10)),
        ];
      final service = UndebitedExpensesService(expensesService: expenses);

      await service.refresh(
        accountId: 'account-1',
        current: const Period(year: 2026, month: 9),
        showImmediately: true,
      );
      await service.carryToCurrentPeriod();

      expect(expenses.moves, hasLength(2));
      expect(expenses.moves.every((m) => m.$3 == DateTime(2026, 9, 1)), isTrue);
      expect(expenses.moves.every((m) => m.$4 == false), isTrue);

      service.dispose();
      expenses.dispose();
    });

    test('debiting all on original period marks every pending occurrence', () async {
      final expenses = FakeUndebitedExpensesService()
        ..accountExpenses = [
          expense(id: 'expense-1', name: 'Rent', debitDate: DateTime(2026, 8, 15)),
          expense(id: 'expense-2', name: 'Gym', debitDate: DateTime(2026, 7, 10)),
        ];
      final service = UndebitedExpensesService(expensesService: expenses);

      await service.refresh(
        accountId: 'account-1',
        current: const Period(year: 2026, month: 9),
        showImmediately: true,
      );
      await service.debitOnOriginalPeriod();

      expect(expenses.marks, hasLength(2));
      expect(expenses.marks.map((m) => m.$1.id), containsAll(['expense-1', 'expense-2']));

      service.dispose();
      expenses.dispose();
    });

    test('debiting all on current period moves every pending occurrence', () async {
      final expenses = FakeUndebitedExpensesService()
        ..accountExpenses = [
          expense(id: 'expense-1', name: 'Rent', debitDate: DateTime(2026, 8, 15)),
          expense(id: 'expense-2', name: 'Gym', debitDate: DateTime(2026, 7, 10)),
        ];
      final service = UndebitedExpensesService(expensesService: expenses);

      await service.refresh(
        accountId: 'account-1',
        current: const Period(year: 2026, month: 9),
        showImmediately: true,
      );
      await service.debitOnCurrentPeriod();

      expect(expenses.moves, hasLength(2));
      expect(expenses.moves.every((m) => m.$3 == DateTime(2026, 9, 1)), isTrue);
      expect(expenses.moves.every((m) => m.$4 == true), isTrue);

      service.dispose();
      expenses.dispose();
    });
  });
}