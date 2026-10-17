import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/expense_occurrence.dart';
import 'package:budgly/src/models/expense/expense_occurrence_exception.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/models/user/user.dart';
import 'package:budgly/src/pages/category_expenses/category_expenses_provider.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/services/expenses/expenses_service_provider.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:budgly/src/services/auth/auth_service.dart';
import 'package:budgly/src/services/auth/auth_service_provider.dart';
import 'package:budgly/src/services/providers/firestore/expense_page.dart';
import 'package:budgly/src/state/profile_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Occurrence-scoped recurring mutations must edit the *series* values, never
/// the projected occurrence. `ExpenseOccurrence.expense` carries the persisted
/// per-occurrence exception overrides (name, amount, category) when one
/// exists, so writing those fields back at the series level would silently
/// rewrite every other occurrence of the series.

class _FakeAuthService extends AuthService {
  _FakeAuthService() : super(analytics: AnalyticsService());
  @override
  User? get currentUser => null;
  @override
  fb.User? get firebaseUser => null;

  @override
  Stream<fb.User?> get authStateChanges => const Stream<fb.User?>.empty();
}

class _FakeProfileService extends ProfileService {
  _FakeProfileService({
    required super.analytics,
    required super.syncManager,
    required super.syncQueue,
  });

  @override
  Future<
    ({
      ThemeMode themeMode,
      Locale locale,
      String currency,
      int amountDecimalPlaces,
    })
  >
  loadLocalPreferences({required String? uid}) async => (
    themeMode: ThemeMode.system,
    locale: const Locale('fr'),
    currency: 'EUR',
    amountDecimalPlaces: 2,
  );

  @override
  Future<User?> loadUserProfile({bool forceRefresh = false}) async => null;

  @override
  Future<User?> refreshFromServer({bool rethrowErrors = false}) async => null;
}

/// Records every write so a test can assert on the exact series document that
/// would be persisted. `modifyFutureOccurrences` is intercepted (the real one
/// splits through Firestore) but is given the same `original` the production
/// call receives, which is the contract under test.
class _RecordingExpensesService extends ExpensesService {
  _RecordingExpensesService(this.values, {required super.analytics});

  final List<Expense> values;

  Expense? lastUpdated;
  Expense? lastFutureOriginal;

  @override
  Future<List<Expense>> listExpensesForAccount(
    String accountId, {
    bool forceRefresh = false,
  }) async =>
      values.where((expense) => expense.accountId == accountId).toList();

  @override
  Future<ExpensePage> listCategoryPeriodPage(
    String accountId,
    String categoryId,
    Period period, {
    int limit = 20,
    Object? startAfter,
    bool includeRecurring = true,
  }) async =>
      ExpensePage(expenses: values.toList(), cursor: null, hasMore: false);

  @override
  Future<Expense> updateExpense(Expense expense, {Expense? previous}) async {
    lastUpdated = expense;
    final index = values.indexWhere((item) => item.id == expense.id);
    if (index != -1) values[index] = expense;
    return expense;
  }

  @override
  Future<Expense> modifyFutureOccurrences({
    required Expense original,
    required DateTime effectiveDate,
    required Expense updated,
  }) async {
    lastFutureOriginal = original;
    return updated;
  }
}

ExpenseOccurrenceException _exception({
  required String expenseId,
  required DateTime date,
  double? amount,
  String? name,
  String? categoryId,
}) => ExpenseOccurrenceException(
  key: '$expenseId@${Expense.isoDate(date)}',
  amount: amount,
  name: name,
  categoryId: categoryId,
);

ProviderContainer _makeContainer(_RecordingExpensesService expensesService) {
  SharedPreferences.setMockInitialValues({});
  final analytics = AnalyticsService();
  final syncQueue = SyncQueue();
  final syncManager = SyncManager(queue: syncQueue, analytics: analytics);
  final container = ProviderContainer(
    overrides: [
      expensesServiceProvider.overrideWithValue(expensesService),
      authServiceProvider.overrideWithValue(_FakeAuthService()),
      profileServiceProvider.overrideWithValue(
        _FakeProfileService(
          analytics: analytics,
          syncManager: syncManager,
          syncQueue: syncQueue,
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  const period = Period(year: 2026, month: 3);

  /// A monthly series (5th of each month) whose 2026-03-05 occurrence was
  /// already edited once: the exception overrides amount, name and category.
  Expense series() => Expense(
    id: 'e1',
    accountId: 'a1',
    categoryId: 'c1',
    name: 'Loyer',
    amount: 10,
    debitDate: DateTime(2026, 1, 5),
    recurrence: RecurrenceType.monthly,
    recurrenceAnchorDay: 5,
    occurrenceExceptions: [
      _exception(
        expenseId: 'e1',
        date: DateTime(2026, 3, 5),
        amount: 99,
        name: 'Loyer special',
        categoryId: 'c2',
      ),
    ],
  );

  /// The occurrence as the category list presents it: projected through its
  /// exception, exactly like `ExpenseOccurrenceCalculator` does.
  ExpenseOccurrence editedOccurrence() => ExpenseOccurrence(
    expense: series().copyWith(
      amount: 99,
      name: 'Loyer special',
      categoryId: 'c2',
    ),
    date: DateTime(2026, 3, 5),
    isDebited: false,
    sourceDate: DateTime(2026, 3, 5),
  );

  ExpenseOccurrenceException? exceptionFor(Expense expense) {
    for (final item in expense.occurrenceExceptions) {
      if (item.key == 'e1@2026-03-05') return item;
    }
    return null;
  }

  group('single-occurrence edit of a recurring series', () {
    test('editing an occurrence that already carries an exception keeps the '
        'series base values untouched', () async {
      final expense = series();
      final service = _RecordingExpensesService([
        expense,
      ], analytics: AnalyticsService());
      final container = _makeContainer(service);

      final notifier = container.read(
        categoryExpensesProvider('a1', 'c1', period).notifier,
      );
      await notifier.loadMore();
      notifier.startEditing(editedOccurrence());
      notifier.setRecurringEditScope(RecurringEditScope.single);

      final success = await notifier.saveEditing(
        ExpenseEditFormData(
          name: 'Loyer special',
          amount: 99,
          accountId: 'a1',
          categoryId: 'c3', // the user assigns another category
          debitDate: DateTime(2026, 3, 5),
          endDate: null,
          recurrence: RecurrenceType.monthly,
        ),
      );

      expect(success, isTrue);
      final written = service.lastUpdated!;
      // The series document keeps its own values: only the exception of the
      // edited occurrence may carry the new ones.
      expect(written.categoryId, 'c1');
      expect(written.amount, 10);
      expect(written.name, 'Loyer');
      final exception = exceptionFor(written)!;
      expect(exception.categoryId, 'c3');
    });

    test(
      'editing a clean occurrence still writes the change as an exception',
      () async {
        final expense = Expense(
          id: 'e1',
          accountId: 'a1',
          categoryId: 'c1',
          name: 'Loyer',
          amount: 10,
          debitDate: DateTime(2026, 1, 5),
          recurrence: RecurrenceType.monthly,
          recurrenceAnchorDay: 5,
        );
        final service = _RecordingExpensesService([
          expense,
        ], analytics: AnalyticsService());
        final container = _makeContainer(service);

        final notifier = container.read(
          categoryExpensesProvider('a1', 'c1', period).notifier,
        );
        await notifier.loadMore();
        notifier.startEditing(
          ExpenseOccurrence(
            expense: expense,
            date: DateTime(2026, 3, 5),
            isDebited: false,
          ),
        );
        notifier.setRecurringEditScope(RecurringEditScope.single);

        final success = await notifier.saveEditing(
          ExpenseEditFormData(
            name: 'Loyer',
            amount: 42,
            accountId: 'a1',
            categoryId: 'c1',
            debitDate: DateTime(2026, 3, 5),
            endDate: null,
            recurrence: RecurrenceType.monthly,
          ),
        );

        expect(success, isTrue);
        final written = service.lastUpdated!;
        expect(written.amount, 10);
        final exception = exceptionFor(written)!;
        expect(exception.amount, 42);
      },
    );

    test(
      'splitting future occurrences also starts from the series base values',
      () async {
        final expense = series();
        final service = _RecordingExpensesService([
          expense,
        ], analytics: AnalyticsService());
        final container = _makeContainer(service);

        final notifier = container.read(
          categoryExpensesProvider('a1', 'c1', period).notifier,
        );
        await notifier.loadMore();
        notifier.startEditing(editedOccurrence());
        notifier.setRecurringEditScope(RecurringEditScope.future);

        final success = await notifier.saveEditing(
          ExpenseEditFormData(
            name: 'Loyer special',
            amount: 99,
            accountId: 'a1',
            categoryId: 'c3',
            debitDate: DateTime(2026, 3, 5),
            endDate: null,
            recurrence: RecurrenceType.monthly,
          ),
        );

        expect(success, isTrue);
        // The truncated previous version is built from `original`: it must
        // carry the series values so past occurrences stay unchanged.
        final splitBase = service.lastFutureOriginal!;
        expect(splitBase.categoryId, 'c1');
        expect(splitBase.amount, 10);
        expect(splitBase.name, 'Loyer');
      },
    );
  });
}
