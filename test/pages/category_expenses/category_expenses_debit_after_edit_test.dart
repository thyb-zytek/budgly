import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/expense_occurrence.dart';
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
import 'package:budgly/src/state/expenses_provider.dart';
import 'package:budgly/src/state/profile_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/builders.dart';
import '../../helpers.dart';

/// Regression coverage for the bug where an occurrence edited from the
/// Category Expenses screen could no longer be debited: the edit splits the
/// series (or writes an occurrence exception), and the debit then looked for
/// a mark on a document whose id or exceptions had changed.
///
/// The service-level half of the fix lives in
/// `test/services/expenses/recurring_series_service_test.dart`; these tests
/// drive the same paths through `CategoryExpenses` so the screen's own
/// orchestration (edit scope → save → toggle) stays covered.
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

ProviderContainer _makeContainer(ExpensesService service) {
  SharedPreferences.setMockInitialValues({});
  final analytics = AnalyticsService();
  final syncQueue = SyncQueue();
  final syncManager = SyncManager(queue: syncQueue, analytics: analytics);
  final container = ProviderContainer(
    overrides: [
      expensesServiceProvider.overrideWithValue(service),
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
  final target = DateTime(2026, 3, 15);

  Future<({ExpensesService service, ProviderContainer container})>
  setup() async {
    final firestore = RefreshAwareExpenseFirestore();
    final service = ExpensesService(
      expenseFirestore: firestore,
      analytics: AnalyticsService(),
    );
    await service.createExpense(
      Fixtures.expense(
        id: 'r1',
        accountId: 'a1',
        categoryId: 'c1',
        name: 'Loyer',
        amount: 50,
        debitDate: DateTime(2026, 1, 15),
        recurrence: RecurrenceType.monthly,
        recurrenceAnchorDay: 15,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    final container = _makeContainer(service);
    await container.read(expensesSessionProvider.notifier).loadAccount('a1');
    // Keep the autoDispose screen state alive across the awaits below.
    final subscription = container.listen(
      categoryExpensesProvider('a1', 'c1', period),
      (_, _) {},
    );
    addTearDown(subscription.close);
    return (service: service, container: container);
  }

  ExpenseOccurrence occurrenceAt(ProviderContainer container, DateTime date) =>
      container
          .read(categoryExpensesProvider('a1', 'c1', period))
          .occurrences
          .firstWhere((occurrence) => occurrence.date == date);

  /// Edits the target occurrence with the given scope through the screen's
  /// notifier, exactly like `CategoryExpensesPage` does.
  Future<void> editOccurrence(
    ProviderContainer container,
    RecurringEditScope scope,
  ) async {
    final notifier = container.read(
      categoryExpensesProvider('a1', 'c1', period).notifier,
    );
    await notifier.loadMore();
    notifier.startEditing(occurrenceAt(container, target));
    notifier.setRecurringEditScope(scope);
    final saved = await notifier.saveEditing(
      ExpenseEditFormData(
        name: 'Loyer',
        amount: 99,
        accountId: 'a1',
        categoryId: 'c1',
        debitDate: target,
        endDate: null,
        recurrence: RecurrenceType.monthly,
      ),
    );
    expect(saved, isTrue, reason: 'the edit itself must succeed');
    await Future<void>.delayed(Duration.zero);
  }

  for (final scope in [RecurringEditScope.single, RecurringEditScope.future]) {
    test(
      'the occurrence stays debitable after a ${scope.name}-scope edit',
      () async {
        final setupResult = await setup();
        final container = setupResult.container;
        await editOccurrence(container, scope);

        final edited = occurrenceAt(container, target);
        expect(edited.amount, 99, reason: 'the edit must be visible');

        final ok = await container
            .read(categoryExpensesProvider('a1', 'c1', period).notifier)
            .toggleDebited(edited);
        await Future<void>.delayed(Duration.zero);

        expect(ok, isTrue);
        expect(occurrenceAt(container, target).isDebited, isTrue);
        expect(
          container
              .read(expensesSessionProvider.notifier)
              .getExpenseById(edited.expense.id ?? '')
              ?.isDebitedAt(target),
          isTrue,
          reason: 'the debit must also reach the shared session state',
        );
      },
    );
  }

  test('the sheet toggle debits an occurrence re-opened after a future-scope '
      'edit', () async {
    final setupResult = await setup();
    final container = setupResult.container;
    await editOccurrence(container, RecurringEditScope.future);

    // Re-open the sheet on the modified occurrence and press the check
    // button: the sheet falls back on the occurrence it displays.
    final notifier = container.read(
      categoryExpensesProvider('a1', 'c1', period).notifier,
    );
    notifier.startEditing(occurrenceAt(container, target));
    final ok = await notifier.toggleEditingOccurrenceDebited();
    await Future<void>.delayed(Duration.zero);

    expect(ok, isTrue);
    expect(occurrenceAt(container, target).isDebited, isTrue);
  });
}
