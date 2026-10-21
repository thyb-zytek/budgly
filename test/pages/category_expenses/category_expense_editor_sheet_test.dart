import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/models/user/user.dart';
import 'package:budgly/src/pages/category_expenses/view.dart';
import 'package:budgly/src/pages/category_expenses/widgets/category_expense_editor_sheet.dart';
import 'package:budgly/src/pages/settings/widgets/confirm_delete.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/auth/auth_service.dart';
import 'package:budgly/src/services/auth/auth_service_provider.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/services/expenses/expenses_service_provider.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:budgly/src/services/providers/firestore/expense_page.dart';
import 'package:budgly/src/state/accounts_provider.dart';
import 'package:budgly/src/state/categories_provider.dart';
import 'package:budgly/src/state/profile_providers.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/test_backend_client_overrides.dart';

/// `CategoryExpenseEditorSheet` is opened from `CategoryExpensesPage` when a
/// row is tapped. These tests drive it through the real page and providers and
/// lock the delete affordance of the sheet: the confirmation of a one-off
/// expense, the scope choice of a recurring one, and the rule that a debited
/// occurrence can never be deleted from the sheet.
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
    themeMode: ThemeMode.light,
    locale: const Locale('fr'),
    currency: 'EUR',
    amountDecimalPlaces: 2,
  );

  @override
  Future<User?> loadUserProfile({bool forceRefresh = false}) async => null;

  @override
  Future<User?> refreshFromServer({bool rethrowErrors = false}) async => null;
}

/// Serves a single expense and records which delete operation reached the
/// service, so a test can assert on the exact write the sheet triggered.
class _EditorExpensesService extends ExpensesService {
  _EditorExpensesService(this.expense, {required super.analytics});

  final Expense expense;
  final List<String> deleted = [];
  final List<DateTime> singleDeleted = [];
  final List<DateTime> futureDeleted = [];

  @override
  Future<List<Expense>> listExpensesForAccount(
    String accountId, {
    bool forceRefresh = false,
  }) async => [expense];

  @override
  Future<ExpensePage> listCategoryPeriodPage(
    String accountId,
    String categoryId,
    Period period, {
    int limit = 20,
    Object? startAfter,
    bool includeRecurring = true,
  }) async => ExpensePage(expenses: [expense], cursor: null, hasMore: false);

  @override
  Future<bool> deleteExpense(String expenseId, String accountId) async {
    deleted.add(expenseId);
    return true;
  }

  @override
  Future<bool> deleteSingleOccurrence({
    required Expense expense,
    required DateTime occurrenceDate,
  }) async {
    singleDeleted.add(occurrenceDate);
    return true;
  }

  @override
  Future<bool> deleteFutureOccurrences({
    required Expense expense,
    required DateTime occurrenceDate,
  }) async {
    futureDeleted.add(occurrenceDate);
    return true;
  }
}

Expense _expense({
  bool isDebited = false,
  RecurrenceType recurrence = RecurrenceType.none,
}) => Expense(
  id: 'e1',
  accountId: 'a1',
  categoryId: 'c1',
  name: 'Loyer',
  amount: 10,
  debitDate: DateTime(2026, 3, 5),
  isDebited: isDebited,
  recurrence: recurrence,
  recurrenceAnchorDay: recurrence == RecurrenceType.none ? null : 5,
);

ProviderContainer _makeContainer(_EditorExpensesService service) {
  SharedPreferences.setMockInitialValues({});
  final analytics = AnalyticsService();
  final queue = SyncQueue();
  final manager = SyncManager(queue: queue, analytics: analytics);
  final container = ProviderContainer(
    overrides: [
      // This container is mounted as the root scope by `pumpApp`: the editor
      // sheet and its confirmation sheets are pushed on the Navigator, so they
      // must resolve the same overrides as the page driving them.
      ...testBackendClientOverrides(),
      expensesServiceProvider.overrideWithValue(service),
      authServiceProvider.overrideWithValue(_FakeAuthService()),
      profileServiceProvider.overrideWithValue(
        _FakeProfileService(
          analytics: analytics,
          syncManager: manager,
          syncQueue: queue,
        ),
      ),
    ],
  );
  addTearDown(container.dispose);

  // Same seeding as the real profile preload: the page stays on its loading
  // indicator until the category exists in the session.
  container
      .read(accountsSessionProvider.notifier)
      .updateLocal(const Account(id: 'a1', name: 'Compte'));
  container
      .read(categoriesSessionProvider.notifier)
      .updateLocal(
        const Category(
          id: 'c1',
          accountId: 'a1',
          name: 'Alimentation',
          monthlyThreshold: 300,
        ),
      );
  return container;
}

/// `SwipeHintWrapper` re-arms its own `Timer` forever, so `pumpAndSettle`
/// never converges on this page: wait with bounded pumps instead.
Future<void> _pumpFor(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Opens the page, taps the only row and waits for the editor sheet.
Future<AppLocalizations> _openEditor(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await pumpApp(
    tester,
    const CategoryExpensesPage(
      accountId: 'a1',
      categoryId: 'c1',
      period: Period(year: 2026, month: 3),
    ),
    settle: false,
    container: container,
  );
  await _pumpFor(tester);

  await tester.tap(find.text('Loyer'));
  await _pumpFor(tester);
  expect(find.byType(CategoryExpenseEditorSheet), findsOneWidget);

  return AppLocalizations.of(
    tester.element(find.byType(CategoryExpenseEditorSheet)),
  )!;
}

Finder _inSheet(Finder matching) => find.descendant(
  of: find.byType(CategoryExpenseEditorSheet),
  matching: matching,
);

void main() {
  group('CategoryExpenseEditorSheet delete affordance', () {
    testWidgets('deletes a one-off expense after confirmation', (tester) async {
      final service = _EditorExpensesService(
        _expense(),
        analytics: AnalyticsService(),
      );
      final container = _makeContainer(service);
      final tr = await _openEditor(tester, container);

      await tester.tap(_inSheet(find.byIcon(Icons.delete_outline)));
      await _pumpFor(tester);

      // Nothing is deleted before the user confirms.
      expect(find.text(tr.confirmDeleteExpense('Loyer')), findsOneWidget);
      expect(service.deleted, isEmpty);

      // "Valider" also labels the editor sheet's submit button: confirm on the
      // confirmation sheet's own button only.
      await tester.tap(
        find.descendant(
          of: find.byType(ConfirmDelete),
          matching: find.text(tr.validate),
        ),
      );
      await _pumpFor(tester);

      expect(service.deleted, ['e1']);
      expect(find.byType(CategoryExpenseEditorSheet), findsNothing);
    });

    testWidgets('deletes only the chosen occurrence of a recurring expense', (
      tester,
    ) async {
      final service = _EditorExpensesService(
        _expense(recurrence: RecurrenceType.monthly),
        analytics: AnalyticsService(),
      );
      final container = _makeContainer(service);
      final tr = await _openEditor(tester, container);

      await tester.tap(_inSheet(find.byIcon(Icons.delete_outline)));
      await _pumpFor(tester);
      expect(service.singleDeleted, isEmpty);

      await tester.tap(find.text(tr.deleteSingleOccurrence));
      await _pumpFor(tester);

      expect(service.singleDeleted, [DateTime(2026, 3, 5)]);
      expect(service.futureDeleted, isEmpty);
      expect(service.deleted, isEmpty);
      expect(find.byType(CategoryExpenseEditorSheet), findsNothing);
    });

    testWidgets('deletes this and the following occurrences when asked', (
      tester,
    ) async {
      final service = _EditorExpensesService(
        _expense(recurrence: RecurrenceType.monthly),
        analytics: AnalyticsService(),
      );
      final container = _makeContainer(service);
      final tr = await _openEditor(tester, container);

      await tester.tap(_inSheet(find.byIcon(Icons.delete_outline)));
      await _pumpFor(tester);

      await tester.tap(find.text(tr.deleteFutureOccurrences));
      await _pumpFor(tester);

      expect(service.futureDeleted, [DateTime(2026, 3, 5)]);
      expect(service.singleDeleted, isEmpty);
      expect(service.deleted, isEmpty);
      expect(find.byType(CategoryExpenseEditorSheet), findsNothing);
    });

    testWidgets('never offers deletion for a debited occurrence', (
      tester,
    ) async {
      final service = _EditorExpensesService(
        _expense(isDebited: true),
        analytics: AnalyticsService(),
      );
      final container = _makeContainer(service);
      await _openEditor(tester, container);

      expect(_inSheet(find.byIcon(Icons.delete_outline)), findsNothing);
      expect(service.deleted, isEmpty);
    });
  });
}
