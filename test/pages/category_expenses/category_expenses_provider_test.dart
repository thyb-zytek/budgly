import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/expense_occurrence.dart';
import 'package:budgly/src/models/user/user.dart';
import 'package:budgly/src/state/expenses_provider.dart';
import 'package:budgly/src/pages/category_expenses/category_expenses_provider.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/services/expenses/expenses_service_provider.dart';
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

/// Regression coverage for the bug where mutations made from the Category
/// Expenses screen only updated [ExpensesService]'s own cache and never
/// reached [ExpensesSession] — the shared state every other screen
/// (Overview, Undebited...) reads from. Every mutation below must be
/// reflected in [expensesSessionProvider] once it completes.
class _FakeAuthService extends AuthService {
  _FakeAuthService() : super(analytics: AnalyticsService());
  @override
  User? get currentUser => null;

  @override
  fb.User? get firebaseUser => null;
}

class _FakeExpensesService extends ExpensesService {
  _FakeExpensesService(this.values, {required super.analytics});

  final List<Expense> values;

  @override
  Future<List<Expense>> listExpensesForAccount(
    String accountId, {
    bool forceRefresh = false,
  }) async =>
      values.where((expense) => expense.accountId == accountId).toList();

  @override
  Future<Expense> toggleOccurrenceDebited(
    Expense expense,
    DateTime date,
  ) async {
    final updated = expense.copyWith(isDebited: !expense.isDebited);
    _replaceInValues(updated);
    return updated;
  }

  @override
  Future<bool> deleteExpense(String expenseId, String accountId) async {
    values.removeWhere((expense) => expense.id == expenseId);
    return true;
  }

  void _replaceInValues(Expense updated) {
    final index = values.indexWhere((expense) => expense.id == updated.id);
    if (index != -1) values[index] = updated;
  }
}

// build() also ref.listen()s profileSessionProvider (for onboarding/profile
// refresh side effects), which forces ProfileSession to build — and its real
// implementation reaches for Firebase. Fake it out the same way
// undebited_expenses_page_test.dart does, so the test stays offline.
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

Expense _expense(String id, String accountId, String categoryId) => Expense(
  id: id,
  accountId: accountId,
  categoryId: categoryId,
  name: id,
  amount: 10,
  debitDate: DateTime(2026, 3, 5),
);

ProviderContainer _makeContainer(ExpensesService expensesService) {
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
  test('toggleDebited propagates the change to ExpensesSession', () async {
    final expense = _expense('e1', 'a1', 'c1');
    final analytics = AnalyticsService();
    final service = _FakeExpensesService([expense], analytics: analytics);
    final container = _makeContainer(service);
    addTearDown(container.dispose);

    // Seed the shared session the way the rest of the app does.
    await container.read(expensesSessionProvider.notifier).loadAccount('a1');
    expect(
      container
          .read(expensesSessionProvider)
          .expensesByAccount['a1']!
          .single
          .isDebited,
      isFalse,
    );

    final notifier = container.read(
      categoryExpensesProvider(
        'a1',
        'c1',
        const Period(year: 2026, month: 3),
      ).notifier,
    );
    final occurrence = ExpenseOccurrence(
      expense: expense,
      date: DateTime(2026, 3, 5),
      isDebited: false,
    );
    final success = await notifier.toggleDebited(occurrence);

    expect(success, isTrue);
    final sessionExpense = container
        .read(expensesSessionProvider.notifier)
        .getExpenseById('e1');
    expect(sessionExpense, isNotNull);
    expect(sessionExpense!.isDebited, isTrue);
  });

  test('deleteOccurrence removes the expense from ExpensesSession', () async {
    final expense = _expense('e1', 'a1', 'c1');
    final analytics = AnalyticsService();
    final service = _FakeExpensesService([expense], analytics: analytics);
    final container = _makeContainer(service);
    addTearDown(container.dispose);

    await container.read(expensesSessionProvider.notifier).loadAccount('a1');
    expect(
      container.read(expensesSessionProvider.notifier).getExpenseById('e1'),
      isNotNull,
    );

    final notifier = container.read(
      categoryExpensesProvider(
        'a1',
        'c1',
        const Period(year: 2026, month: 3),
      ).notifier,
    );
    final occurrence = ExpenseOccurrence(
      expense: expense,
      date: DateTime(2026, 3, 5),
      isDebited: false,
    );
    final success = await notifier.deleteOccurrence(occurrence);

    expect(success, isTrue);
    expect(
      container.read(expensesSessionProvider.notifier).getExpenseById('e1'),
      isNull,
    );
  });
}
