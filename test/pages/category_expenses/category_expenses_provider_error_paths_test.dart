import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/expense_occurrence.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/models/user/user.dart';
import 'package:budgly/src/state/expenses_provider.dart';
import 'package:budgly/src/pages/category_expenses/category_expenses_provider.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/services/expenses/expenses_service_provider.dart';
import 'package:budgly/src/services/providers/firestore/expense_page.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:budgly/src/services/auth/auth_service.dart';
import 'package:budgly/src/services/auth/auth_service_provider.dart';
import 'package:budgly/src/state/profile_providers.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Complements `category_expenses_provider_test.dart` (success paths only)
/// with the branches that file leaves untested: `loadMore`'s two distinct
/// failure branches (first page with/without a local fallback, and a later
/// page), the error/"moved" paths of `saveEditing`, and the error paths of
/// `deleteOccurrence`/`_deleteRecurring`/`toggleDebited`.

class _FakeAuthService extends AuthService {
  _FakeAuthService() : super(analytics: AnalyticsService());
  @override
  User? get currentUser => null;
  @override
  fb.User? get firebaseUser => null;
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
  Future<User?> refreshFromServer() async => null;
}

/// A configurable fake: each method either succeeds (using [values] as the
/// backing store, like `listExpensesForAccount` does) or throws, controlled
/// per-test. `updateExpense` backs `saveEditing`'s non-recurring path and, for
/// a recurring [Expense], also backs `modifySingleOccurrence`/
/// `deleteSingleOccurrence` (both delegate to it — see ExpensesService).
class _ScriptedExpensesService extends ExpensesService {
  _ScriptedExpensesService(this.values, {required super.analytics});

  final List<Expense> values;

  ExpensePage Function()? pageResult;
  Object? pageError;

  bool failUpdate = false;
  bool failDelete = false;
  bool failToggle = false;

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
  }) async {
    if (pageError != null) throw pageError!;
    return pageResult!();
  }

  @override
  Future<Expense> updateExpense(Expense expense, {Expense? previous}) async {
    if (failUpdate) throw StateError('offline');
    _replaceInValues(expense);
    return expense;
  }

  @override
  Future<bool> deleteExpense(String expenseId, String accountId) async {
    if (failDelete) throw StateError('offline');
    values.removeWhere((expense) => expense.id == expenseId);
    return true;
  }

  @override
  Future<Expense> toggleOccurrenceDebited(
    Expense expense,
    DateTime date,
  ) async {
    if (failToggle) throw StateError('offline');
    final updated = expense.copyWith(isDebited: !expense.isDebited);
    _replaceInValues(updated);
    return updated;
  }

  void _replaceInValues(Expense updated) {
    final index = values.indexWhere((expense) => expense.id == updated.id);
    if (index != -1) values[index] = updated;
  }
}

Expense _expense(
  String id,
  String accountId,
  String categoryId, {
  RecurrenceType recurrence = RecurrenceType.none,
}) => Expense(
  id: id,
  accountId: accountId,
  categoryId: categoryId,
  name: id,
  amount: 10,
  debitDate: DateTime(2026, 3, 5),
  recurrence: recurrence,
  recurrenceAnchorDay: recurrence == RecurrenceType.none ? null : 5,
);

ProviderContainer _makeContainer(_ScriptedExpensesService expensesService) {
  SharedPreferences.setMockInitialValues({});
  final analytics = AnalyticsService();
  final syncQueue = SyncQueue();
  final syncManager = SyncManager(queue: syncQueue, analytics: analytics);
  return ProviderContainer(
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
}

void main() {
  const period = Period(year: 2026, month: 3);

  group('loadMore', () {
    test(
      'a successful first page publishes occurrences and stops loading',
      () async {
        final expense = _expense('e1', 'a1', 'c1');
        final service =
            _ScriptedExpensesService([], analytics: AnalyticsService())
              ..pageResult = () => ExpensePage(
                expenses: [expense],
                cursor: null,
                hasMore: false,
              );
        final container = _makeContainer(service);
        addTearDown(container.dispose);

        final notifier = container.read(
          categoryExpensesProvider('a1', 'c1', period).notifier,
        );
        await notifier.loadMore();

        final state = container.read(
          categoryExpensesProvider('a1', 'c1', period),
        );
        expect(state.occurrences, hasLength(1));
        expect(state.isLoadingMore, isFalse);
        expect(state.hasMorePages, isFalse);
        expect(state.status.isLoading, isFalse);
      },
    );

    test(
      'a first-page failure with no local fallback reports a failure status',
      () async {
        final service = _ScriptedExpensesService(
          [],
          analytics: AnalyticsService(),
        )..pageError = StateError('offline');
        final container = _makeContainer(service);
        addTearDown(container.dispose);

        final notifier = container.read(
          categoryExpensesProvider('a1', 'c1', period).notifier,
        );
        await notifier.loadMore();

        final state = container.read(
          categoryExpensesProvider('a1', 'c1', period),
        );
        expect(state.status.hasError, isTrue);
        expect(state.occurrences, isEmpty);
        expect(state.isLoadingMore, isFalse);
      },
    );

    test(
      'a first-page failure falls back to whatever ExpensesSession already has locally',
      () async {
        final expense = _expense('e1', 'a1', 'c1');
        final service = _ScriptedExpensesService([
          expense,
        ], analytics: AnalyticsService())..pageError = StateError('offline');
        final container = _makeContainer(service);
        addTearDown(container.dispose);

        // Seed ExpensesSession the way the rest of the app does before the
        // category screen's own (failing) page request runs.
        await container
            .read(expensesSessionProvider.notifier)
            .loadAccount('a1');

        final notifier = container.read(
          categoryExpensesProvider('a1', 'c1', period).notifier,
        );
        await notifier.loadMore();

        final state = container.read(
          categoryExpensesProvider('a1', 'c1', period),
        );
        expect(state.status.hasError, isFalse);
        expect(state.occurrences, hasLength(1));
        expect(state.hasMorePages, isFalse);
      },
    );

    test(
      'a failure on a later page just logs and keeps the already-loaded occurrences',
      () async {
        final expense = _expense('e1', 'a1', 'c1');
        final service =
            _ScriptedExpensesService([], analytics: AnalyticsService())
              ..pageResult = () =>
                  ExpensePage(expenses: [expense], cursor: null, hasMore: true);
        final container = _makeContainer(service);
        addTearDown(container.dispose);

        final notifier = container.read(
          categoryExpensesProvider('a1', 'c1', period).notifier,
        );
        await notifier.loadMore(); // first page succeeds, hasMore: true

        service
          ..pageResult = null
          ..pageError = StateError('offline');
        await notifier.loadMore(); // second page fails

        final state = container.read(
          categoryExpensesProvider('a1', 'c1', period),
        );
        // Unlike a first-page failure, this must not surface as a screen-level
        // error: the user already has data on screen.
        expect(state.status.hasError, isFalse);
        expect(state.occurrences, hasLength(1));
      },
    );
  });

  group('saveEditing', () {
    /// Seeds the page's own paginated list before editing, the way the screen
    /// does in production. `startEditing` only records the occurrence under
    /// edit; it does not populate `_expenses`, so without this the subsequent
    /// `_replaceExpense` would silently match nothing.
    Future<ProviderContainer> withEditingOccurrence(
      _ScriptedExpensesService service,
      ExpenseOccurrence occurrence,
    ) async {
      service.pageResult ??= () => ExpensePage(
        expenses: [occurrence.expense],
        cursor: null,
        hasMore: false,
      );
      final container = _makeContainer(service);
      final notifier = container.read(
        categoryExpensesProvider('a1', 'c1', period).notifier,
      );
      await notifier.loadMore();
      notifier.startEditing(occurrence);
      return container;
    }

    test(
      'a successful non-recurring edit is published and clears isSaving',
      () async {
        final expense = _expense('e1', 'a1', 'c1');
        final occurrence = ExpenseOccurrence(
          expense: expense,
          date: DateTime(2026, 3, 5),
          isDebited: false,
        );
        final service = _ScriptedExpensesService([
          expense,
        ], analytics: AnalyticsService());
        final container = await withEditingOccurrence(service, occurrence);
        addTearDown(container.dispose);

        final notifier = container.read(
          categoryExpensesProvider('a1', 'c1', period).notifier,
        );
        final success = await notifier.saveEditing(
          ExpenseEditFormData(
            name: 'Renamed',
            amount: 20,
            categoryId: 'c1',
            debitDate: DateTime(2026, 3, 5),
            endDate: null,
            recurrence: RecurrenceType.none,
          ),
        );

        expect(success, isTrue);
        final state = container.read(
          categoryExpensesProvider('a1', 'c1', period),
        );
        expect(state.isSaving, isFalse);
        expect(state.occurrences.single.name, 'Renamed');
      },
    );

    test(
      'moving an expense to another category drops it from this page',
      () async {
        final expense = _expense('e1', 'a1', 'c1');
        final occurrence = ExpenseOccurrence(
          expense: expense,
          date: DateTime(2026, 3, 5),
          isDebited: false,
        );
        final service = _ScriptedExpensesService([
          expense,
        ], analytics: AnalyticsService());
        final container = await withEditingOccurrence(service, occurrence);
        addTearDown(container.dispose);

        final notifier = container.read(
          categoryExpensesProvider('a1', 'c1', period).notifier,
        );
        final success = await notifier.saveEditing(
          ExpenseEditFormData(
            name: 'Renamed',
            amount: 20,
            categoryId: 'c2', // different category
            debitDate: DateTime(2026, 3, 5),
            endDate: null,
            recurrence: RecurrenceType.none,
          ),
        );

        expect(success, isTrue);
        final state = container.read(
          categoryExpensesProvider('a1', 'c1', period),
        );
        expect(state.occurrences, isEmpty);
        expect(state.editingOccurrence, isNull);
      },
    );

    test(
      'a failed edit reports a failure status and clears isSaving',
      () async {
        final expense = _expense('e1', 'a1', 'c1');
        final occurrence = ExpenseOccurrence(
          expense: expense,
          date: DateTime(2026, 3, 5),
          isDebited: false,
        );
        final service = _ScriptedExpensesService([
          expense,
        ], analytics: AnalyticsService())..failUpdate = true;
        final container = await withEditingOccurrence(service, occurrence);
        addTearDown(container.dispose);

        final notifier = container.read(
          categoryExpensesProvider('a1', 'c1', period).notifier,
        );
        final success = await notifier.saveEditing(
          ExpenseEditFormData(
            name: 'Renamed',
            amount: 20,
            categoryId: 'c1',
            debitDate: DateTime(2026, 3, 5),
            endDate: null,
            recurrence: RecurrenceType.none,
          ),
        );

        expect(success, isFalse);
        final state = container.read(
          categoryExpensesProvider('a1', 'c1', period),
        );
        expect(state.status.hasError, isTrue);
        expect(state.isSaving, isFalse);
      },
    );
  });

  group('deleteOccurrence', () {
    test(
      'a failed delete reports a failure status and clears isSaving',
      () async {
        final expense = _expense('e1', 'a1', 'c1');
        final service = _ScriptedExpensesService([
          expense,
        ], analytics: AnalyticsService())..failDelete = true;
        final container = _makeContainer(service);
        addTearDown(container.dispose);

        final notifier = container.read(
          categoryExpensesProvider('a1', 'c1', period).notifier,
        );
        final occurrence = ExpenseOccurrence(
          expense: expense,
          date: DateTime(2026, 3, 5),
          isDebited: false,
        );
        final success = await notifier.deleteOccurrence(occurrence);

        expect(success, isFalse);
        final state = container.read(
          categoryExpensesProvider('a1', 'c1', period),
        );
        expect(state.status.hasError, isTrue);
        expect(state.isSaving, isFalse);
      },
    );
  });

  group('deleteSingleOccurrence (recurring, routed through _deleteRecurring)', () {
    test(
      'a successful deletion refreshes ExpensesSession and republishes occurrences',
      () async {
        final expense = _expense(
          'e1',
          'a1',
          'c1',
          recurrence: RecurrenceType.monthly,
        );
        final service = _ScriptedExpensesService([
          expense,
        ], analytics: AnalyticsService());
        final container = _makeContainer(service);
        addTearDown(container.dispose);

        final notifier = container.read(
          categoryExpensesProvider('a1', 'c1', period).notifier,
        );
        final occurrence = ExpenseOccurrence(
          expense: expense,
          date: DateTime(2026, 3, 5),
          isDebited: false,
        );
        final success = await notifier.deleteSingleOccurrence(occurrence);

        expect(success, isTrue);
        final state = container.read(
          categoryExpensesProvider('a1', 'c1', period),
        );
        expect(state.isSaving, isFalse);
        // The occurrence is now excepted (deleted) rather than removed from the
        // series itself, so it must no longer appear in this period's list.
        expect(
          state.occurrences.any((o) => o.date == DateTime(2026, 3, 5)),
          isFalse,
        );
      },
    );

    test(
      'a failed deletion reports a failure status and clears isSaving',
      () async {
        final expense = _expense(
          'e1',
          'a1',
          'c1',
          recurrence: RecurrenceType.monthly,
        );
        final service = _ScriptedExpensesService([
          expense,
        ], analytics: AnalyticsService())..failUpdate = true;
        final container = _makeContainer(service);
        addTearDown(container.dispose);

        final notifier = container.read(
          categoryExpensesProvider('a1', 'c1', period).notifier,
        );
        final occurrence = ExpenseOccurrence(
          expense: expense,
          date: DateTime(2026, 3, 5),
          isDebited: false,
        );
        final success = await notifier.deleteSingleOccurrence(occurrence);

        expect(success, isFalse);
        final state = container.read(
          categoryExpensesProvider('a1', 'c1', period),
        );
        expect(state.status.hasError, isTrue);
        expect(state.isSaving, isFalse);
      },
    );
  });

  group('toggleDebited', () {
    test(
      'a failed toggle reports a failure status and clears isSaving',
      () async {
        final expense = _expense('e1', 'a1', 'c1');
        final service = _ScriptedExpensesService([
          expense,
        ], analytics: AnalyticsService())..failToggle = true;
        final container = _makeContainer(service);
        addTearDown(container.dispose);

        final notifier = container.read(
          categoryExpensesProvider('a1', 'c1', period).notifier,
        );
        final occurrence = ExpenseOccurrence(
          expense: expense,
          date: DateTime(2026, 3, 5),
          isDebited: false,
        );
        final success = await notifier.toggleDebited(occurrence);

        expect(success, isFalse);
        final state = container.read(
          categoryExpensesProvider('a1', 'c1', period),
        );
        expect(state.status.hasError, isTrue);
        expect(state.isSaving, isFalse);
      },
    );
  });
}
