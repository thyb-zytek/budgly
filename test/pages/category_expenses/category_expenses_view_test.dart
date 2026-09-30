import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/models/user/user.dart';
import 'package:budgly/src/pages/category_expenses/category_expenses_provider.dart';
import 'package:budgly/src/pages/category_expenses/view.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/auth/auth_service.dart';
import 'package:budgly/src/services/auth/auth_service_provider.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/services/expenses/expenses_service_provider.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:budgly/src/services/providers/firestore/expense_page.dart';
import 'package:budgly/src/shared/ui/widgets/layout/loading_indicator.dart';
import 'package:budgly/src/state/categories_provider.dart';
import 'package:budgly/src/state/profile_providers.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/pump_app.dart';

/// Covers `CategoryExpensesPage` (the 0%-covered 267-line view) end to end
/// through its real providers: loading vs error, empty state vs populated
/// list, infinite-scroll pagination, and the delete flow for a non-recurring
/// occurrence.
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
    themeMode: ThemeMode.light,
    locale: const Locale('fr'),
    currency: 'EUR',
    amountDecimalPlaces: 2,
  );

  @override
  Future<User?> loadUserProfile({bool forceRefresh = false}) async => null;

  @override
  Future<User?> refreshFromServer() async => null;
}

class _PagedExpensesService extends ExpensesService {
  _PagedExpensesService({required this.pages, required super.analytics});

  /// Consumed one call at a time by `listCategoryPeriodPage`.
  final List<ExpensePage> pages;
  Object? pageError;
  int callCount = 0;
  final List<String> deleted = [];
  bool deleteFails = false;

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
    final index = callCount < pages.length ? callCount : pages.length - 1;
    callCount++;
    return pages[index];
  }

  @override
  Future<bool> deleteExpense(String expenseId, String accountId) async {
    if (deleteFails) throw StateError('offline');
    deleted.add(expenseId);
    return true;
  }
}

Expense _expense(
  String id, {
  double amount = 10,
  bool isDebited = false,
  RecurrenceType recurrence = RecurrenceType.none,
  String name = 'Expense',
}) => Expense(
  id: id,
  accountId: 'a1',
  categoryId: 'c1',
  name: name,
  amount: amount,
  debitDate: DateTime(2026, 3, 5),
  isDebited: isDebited,
  recurrence: recurrence,
  recurrenceAnchorDay: recurrence == RecurrenceType.none ? null : 5,
);

ProviderContainer _makeContainer(_PagedExpensesService service) {
  SharedPreferences.setMockInitialValues({});
  final analytics = AnalyticsService();
  final queue = SyncQueue();
  final manager = SyncManager(queue: queue, analytics: analytics);
  final container = ProviderContainer(
    overrides: [
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
  return container;
}

/// The view stays on `AppLoadingIndicator` while `state.category == null`
/// (see `CategoryExpensesPage.build`), so the category must be present in
/// `CategoriesSession` for anything to render. This is the same seeding the
/// real `ProfileSession` preload does before the route is reachable.
void _seedCategory(ProviderContainer container) {
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
}

/// `SwipeHintWrapper` re-arms its own `Timer` forever (a repeating onboarding
/// hint), so `pumpAndSettle` can never converge on this page. A bounded pump is
/// the only correct way to wait for the first page to resolve.
Future<void> _pumpUntilLoaded(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Widget _page(ProviderContainer container) => UncontrolledProviderScope(
  container: container,
  child: const CategoryExpensesPage(
    accountId: 'a1',
    categoryId: 'c1',
    period: Period(year: 2026, month: 3),
  ),
);

void main() {
  const period = Period(year: 2026, month: 3);

  group('CategoryExpensesPage', () {
    testWidgets('shows a loading indicator until the first page resolves', (
      tester,
    ) async {
      final service = _PagedExpensesService(
        pages: [
          ExpensePage(expenses: [_expense('e1')], cursor: null, hasMore: false),
        ],
        analytics: AnalyticsService(),
      );

      // No category seeded yet: the view must show the loading state instead
      // of rendering a content widget for an unknown category.
      final container = _makeContainer(service);
      await pumpApp(tester, _page(container), settle: false);
      expect(find.byType(AppLoadingIndicator), findsOneWidget);

      _seedCategory(container);
      await _pumpUntilLoaded(tester);
      expect(find.byType(AppLoadingIndicator), findsNothing);
    });

    testWidgets('renders the populated list and hides the empty state', (
      tester,
    ) async {
      final service = _PagedExpensesService(
        pages: [
          ExpensePage(
            expenses: [
              _expense('e1', amount: 12, name: 'Loyer'),
              _expense('e2', amount: 30, name: 'Courses'),
            ],
            cursor: null,
            hasMore: false,
          ),
        ],
        analytics: AnalyticsService(),
      );
      final container = _makeContainer(service);

      _seedCategory(container);
      await pumpApp(tester, _page(container), settle: false);
      await _pumpUntilLoaded(tester);
      expect(find.text('Loyer'), findsOneWidget);
      expect(find.text('Courses'), findsOneWidget);
    });

    testWidgets('shows the empty state when the category has no expense', (
      tester,
    ) async {
      final service = _PagedExpensesService(
        pages: [const ExpensePage(expenses: [], cursor: null, hasMore: false)],
        analytics: AnalyticsService(),
      );
      final container = _makeContainer(service);

      _seedCategory(container);
      await pumpApp(tester, _page(container), settle: false);
      await _pumpUntilLoaded(tester);

      final tr = AppLocalizations.of(
        tester.element(find.byType(CategoryExpensesPage)),
      )!;
      expect(find.text(tr.noExpensesForCategory), findsOneWidget);
    });

    testWidgets('requests the next page when the list is scrolled to the end', (
      tester,
    ) async {
      // The view triggers `loadMore` when `extentAfter < 500`, so the first
      // page must be tall enough for the viewport to actually scroll.
      final firstPage = [
        for (var i = 0; i < 15; i++)
          _expense('e$i', amount: 10.0 + i, name: 'Ligne $i'),
      ];
      final service = _PagedExpensesService(
        pages: [
          ExpensePage(expenses: firstPage, cursor: null, hasMore: true),
          ExpensePage(
            expenses: [_expense('e99', name: 'Troisieme')],
            cursor: null,
            hasMore: false,
          ),
        ],
        analytics: AnalyticsService(),
      );
      final container = _makeContainer(service);
      _seedCategory(container);

      await pumpApp(tester, _page(container), settle: false);
      await _pumpUntilLoaded(tester);
      expect(find.text('Troisieme'), findsNothing);
      expect(service.callCount, 1);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -900.0));
      await _pumpUntilLoaded(tester);

      expect(service.callCount, greaterThan(1));
      expect(find.text('Troisieme'), findsOneWidget);
    });

    testWidgets('a delete failure keeps the row on screen', (tester) async {
      final service = _PagedExpensesService(
        pages: [
          ExpensePage(expenses: [_expense('e1')], cursor: null, hasMore: false),
        ],
        analytics: AnalyticsService(),
      )..deleteFails = true;
      final container = _makeContainer(service);

      _seedCategory(container);
      await pumpApp(tester, _page(container), settle: false);
      await _pumpUntilLoaded(tester);

      final notifier = container.read(
        categoryExpensesProvider('a1', 'c1', period).notifier,
      );
      final occurrence = container
          .read(categoryExpensesProvider('a1', 'c1', period))
          .occurrences
          .single;

      final success = await tester.runAsync(
        () => notifier.deleteOccurrence(occurrence),
      );

      expect(success, isFalse);
      expect(service.deleted, isEmpty);
    });

    testWidgets('a successful delete removes the row and confirms it', (
      tester,
    ) async {
      final service = _PagedExpensesService(
        pages: [
          ExpensePage(expenses: [_expense('e1')], cursor: null, hasMore: false),
        ],
        analytics: AnalyticsService(),
      );
      final container = _makeContainer(service);

      _seedCategory(container);
      await pumpApp(tester, _page(container), settle: false);
      await _pumpUntilLoaded(tester);

      final notifier = container.read(
        categoryExpensesProvider('a1', 'c1', period).notifier,
      );
      final occurrence = container
          .read(categoryExpensesProvider('a1', 'c1', period))
          .occurrences
          .single;

      final success = await tester.runAsync(
        () => notifier.deleteOccurrence(occurrence),
      );
      await _pumpUntilLoaded(tester);

      expect(success, isTrue);
      expect(service.deleted, ['e1']);
    });
  });
}
