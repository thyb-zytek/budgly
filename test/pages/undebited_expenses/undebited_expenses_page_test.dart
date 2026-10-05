import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/user/user.dart';
import 'package:budgly/src/pages/undebited_expenses/view.dart';
import 'package:budgly/src/pages/undebited_expenses/undebited_expenses_provider.dart';
import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/accounts/accounts_service_provider.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/services/expenses/expenses_service_provider.dart';
import 'package:budgly/src/services/offline/local_cache.dart';
import 'package:budgly/src/services/offline/local_cache_provider.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:budgly/src/state/profile_providers.dart';
import 'package:budgly/src/state/accounts_provider.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers.dart';

class _FakeExpensesService extends ExpensesService {
  _FakeExpensesService(this.byAccount) : super(analytics: AnalyticsService());
  final Map<String, List<Expense>> byAccount;
  final List<(Expense, DateTime)> marks = [];
  final List<(Expense, DateTime, DateTime, bool)> moves = [];

  List<Expense> _for(String accountId) =>
      List.unmodifiable(byAccount[accountId] ?? const []);

  void _removeWhere(bool Function(Expense) test) {
    for (final expenses in byAccount.values) {
      expenses.removeWhere(test);
    }
  }

  @override
  List<Expense> getExpensesForAccount(String accountId) => _for(accountId);

  @override
  Future<List<Expense>> listExpensesForAccount(
    String accountId, {
    bool forceRefresh = false,
  }) async => _for(accountId);

  @override
  Future<Expense> markOccurrenceDebited(Expense expense, DateTime date) async {
    marks.add((expense, date));
    _removeWhere((e) => e.id == expense.id);
    return expense;
  }

  @override
  Future<Expense> moveOccurrenceToDate(
    Expense expense,
    DateTime occurrenceDate,
    DateTime targetDate, {
    required bool markDebited,
  }) async {
    moves.add((expense, occurrenceDate, targetDate, markDebited));
    _removeWhere((e) => e.id == expense.id);
    return expense;
  }
}

/// Records banner-dismissal writes so a test can prove the notifier goes
/// through the *shared* `localCacheProvider` instance rather than a private
/// `LocalCache()` (docs/AUDIT_PLAN.md, 2026-09-27 review).
class _RecordingLocalCache extends LocalCache {
  final List<String> dismissedAccountIds = [];

  @override
  Future<void> saveUndebitedBannerDismissedAt(
    String accountId, {
    required Period period,
    required DateTime value,
  }) async {
    dismissedAccountIds.add(accountId);
  }
}

class _FakeAccountsService extends AccountsService {
  _FakeAccountsService(this.values)
    : super(
        analytics: AnalyticsService(),
        syncManager: testSyncManager,
        syncQueue: testSyncQueue,
      );
  final List<Account> values;

  @override
  Future<List<Account>> loadAccounts({
    bool forceRefresh = false,
    void Function(List<Account>)? onRevalidated,
  }) async => values;
}

class _FakeProfileService extends ProfileService {
  _FakeProfileService()
    : super(
        analytics: AnalyticsService(),
        syncManager: testSyncManager,
        syncQueue: testSyncQueue,
      );
  @override
  Future<User?> loadUserProfile({bool forceRefresh = false}) async => null;

  @override
  Future<User?> refreshFromServer() async => null;
}

/// Locates the swipeable [Dismissible] wrapping the card whose title is
/// [name], so tests can drag it instead of tapping the old per-card buttons.
Finder _cardFor(String name) =>
    find.ancestor(of: find.text(name), matching: find.byType(Dismissible));

/// Swipes the card left (endToStart): triggers "debit on original period"
/// directly, without any confirmation sheet.
Future<void> _swipeLeft(WidgetTester tester, String name) async {
  await tester.fling(_cardFor(name), const Offset(-500, 0), 1000);
  await tester.pump();
  await tester.pumpAndSettle();
}

/// Swipes the card right (startToEnd): always snaps back and opens the
/// bottom sheet offering the two current-period actions.
///
/// Returns once the sheet's content is visible. Uses [useRootNavigator: true]
/// so the sheet lives in a separate overlay. We use a drag gesture (not fling)
/// to ensure the Dismissible properly triggers confirmDismiss, then pump
/// repeatedly until the sheet content appears.
///
/// The bottom sheet with [useRootNavigator: true] runs its transition in the
/// root navigator's overlay. The Dismissible's confirmDismiss awaits the sheet
/// Future, which prevents the main widget tree from scheduling frames.
/// We manually drive the binding's animation ticker to process the overlay's
/// transition frames until the sheet content appears.
Future<void> _swipeRight(WidgetTester tester, String name) async {
  final cardFinder = _cardFor(name);
  // Drag slowly past the dismiss threshold to ensure confirmDismiss is called
  await tester.drag(cardFinder, const Offset(300, 0));
  await tester.pump();

  // The bottom sheet uses useRootNavigator: true. Its builder runs as part of
  // the route transition animation. Since confirmDismiss awaits the sheet
  // Future, the main widget tree doesn't schedule frames. We pump frames
  // repeatedly with pumpAndSettle to process the root navigator's overlay
  // transition until the sheet content appears.
  for (var i = 0; i < 40; i++) {
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    // Check if sheet content (drag handle icon or title) has appeared
    if (find.byIcon(Icons.schedule_send_rounded).evaluate().isNotEmpty ||
        find.text('Choisir une action').evaluate().isNotEmpty) {
      // One more pump to ensure the frame is fully rendered
      await tester.pump();
      return;
    }
  }

  // Final fallback - pumpAndSettle to catch any remaining frames
  await tester.pumpAndSettle();
}

/// The reporting period the page targets: the *real* current calendar month
/// (`UndebitedExpensesService.currentPeriod`, fed by `Period.fromDate(now)` in
/// the notifier). Derived from the clock instead of hardcoded, so these
/// assertions keep expressing the contract instead of expiring every month.
final Period _currentPeriod = Period.fromDate(DateTime.now());

/// Target date both "carry to current period" and "debit in current period"
/// write to: the first day of [_currentPeriod].
DateTime get _currentPeriodStart => _currentPeriod.startOfMonth;

/// French labels of the two current-period actions, as rendered by the bulk
/// action bar and the swipe sheet (`carryToCurrentPeriod` /
/// `debitOnCurrentPeriod` interpolate the period label).
String get _carryToCurrentPeriodLabel =>
    'Reporter vers ${_currentPeriod.label('fr')}';
String get _debitOnCurrentPeriodLabel =>
    'Débiter en ${_currentPeriod.label('fr')}';

Account _account(String id, String name) =>
    Account(id: id, name: name, color: Colors.blueGrey);

Expense _expense({
  required String id,
  required String accountId,
  required String name,
  required double amount,
  required DateTime debitDate,
}) => Expense(
  id: id,
  accountId: accountId,
  categoryId: 'category-1',
  name: name,
  amount: amount,
  debitDate: debitDate,
);

ProviderContainer? _activeContainer;

Future<({UndebitedExpenses viewModel, _FakeExpensesService expenses})>
_buildLoadedViewModel({
  List<Account> accounts = const [],
  Map<String, List<Expense>> expensesByAccount = const {},
  LocalCache? localCache,
}) async {
  final expensesService = _FakeExpensesService(
    Map<String, List<Expense>>.from(expensesByAccount),
  );
  final container = ProviderContainer(
    overrides: [
      expensesServiceProvider.overrideWithValue(expensesService),
      accountsServiceProvider.overrideWithValue(_FakeAccountsService(accounts)),
      profileServiceProvider.overrideWithValue(_FakeProfileService()),
      if (localCache != null) localCacheProvider.overrideWithValue(localCache),
      profileSessionProvider.overrideWithValue(
        const ProfileSessionState(
          currentUser: null,
          hasLoaded: true,
          themeMode: ThemeMode.system,
          locale: Locale('fr'),
          currency: 'EUR',
          amountDecimalPlaces: 2,
        ),
      ),
    ],
  );
  _activeContainer = container;
  addTearDown(() {
    container.dispose();
    _activeContainer = null;
  });
  container.read(accountsSessionProvider.notifier).setAccounts(accounts);
  final subscription = container.listen(undebitedExpensesProvider, (_, _) {});
  addTearDown(subscription.close);
  final viewModel = container.read(undebitedExpensesProvider.notifier);
  await viewModel.ensureDataLoaded();
  return (viewModel: viewModel, expenses: expensesService);
}

Widget _page() => UncontrolledProviderScope(
  container: _activeContainer!,
  child: const UndebitedExpensesPage(),
);

/// Pumps a [MaterialApp] whose home is a placeholder and pushes the report
/// page on top, so the auto-close behavior can be asserted by checking that
/// the placeholder is revealed again after popping.
Future<void> _openReportPage(WidgetTester tester, {Size? size}) async {
  if (size != null) {
    await tester.binding.setSurfaceSize(size);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }
  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      locale: const Locale('fr'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('fr')],
      home: const Scaffold(body: Placeholder()),
    ),
  );
  navigatorKey.currentState!.push(
    MaterialPageRoute<void>(
      builder: (_) => UncontrolledProviderScope(
        container: _activeContainer!,
        child: const UndebitedExpensesPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'the bulk "debit on original period" button uses a generic label, not a '
    'specific period, since a selection can span several original periods',
    (tester) async {
      await _buildLoadedViewModel(
        accounts: [_account('account-1', 'Compte courant')],
        expensesByAccount: {
          'account-1': [
            _expense(
              id: 'march-rent',
              accountId: 'account-1',
              name: 'Loyer mars',
              amount: 500,
              debitDate: DateTime(2026, 3, 5),
            ),
            _expense(
              id: 'june-rent',
              accountId: 'account-1',
              name: 'Loyer juin',
              amount: 500,
              debitDate: DateTime(2026, 6, 5),
            ),
          ],
        },
      );

      await pumpApp(tester, _page(), size: const Size(400, 1200));

      await tester.longPress(find.text('Loyer mars').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tout sélectionner'));

      expect(
        find.text("Débiter sur la période d'origine"),
        findsOneWidget,
        reason:
            'the bulk action must not claim a specific original period '
            'when the selection spans several different ones',
      );
      final marchLabel = const Period(year: 2026, month: 3).label('fr');
      final juneLabel = const Period(year: 2026, month: 6).label('fr');
      expect(find.text('Débiter sur $marchLabel'), findsNothing);
      expect(find.text('Débiter sur $juneLabel'), findsNothing);
    },
  );

  testWidgets(
    'aggregates every account, groups by period and shows full dates',
    (tester) async {
      await _buildLoadedViewModel(
        accounts: [
          _account('account-1', 'Compte courant'),
          _account('account-2', 'Compte épargne'),
        ],
        expensesByAccount: {
          'account-1': [
            _expense(
              id: 'e1',
              accountId: 'account-1',
              name: 'Août long',
              amount: 100,
              debitDate: DateTime(2026, 8, 20),
            ),
            _expense(
              id: 'e3',
              accountId: 'account-1',
              name: 'Juin y',
              amount: 25,
              debitDate: DateTime(2026, 6, 1),
            ),
          ],
          'account-2': [
            _expense(
              id: 'e2',
              accountId: 'account-2',
              name: 'Juillet x',
              amount: 50,
              debitDate: DateTime(2026, 7, 10),
            ),
          ],
        },
      );

      await pumpApp(tester, _page(), size: const Size(400, 1500));

      expect(find.text('3 dépense(s) en attente'), findsOneWidget);
      expect(find.textContaining('175,00'), findsOneWidget);

      expect(find.text('Juin 2026'), findsOneWidget);
      expect(find.text('Juillet 2026'), findsOneWidget);
      expect(find.text('Août 2026'), findsOneWidget);

      expect(find.text('1 juin 2026'), findsOneWidget);
      expect(find.text('10 juillet 2026'), findsOneWidget);
      expect(find.text('20 août 2026'), findsOneWidget);

      final juinY = tester.getTopLeft(find.text('Juin 2026')).dy;
      final juilletY = tester.getTopLeft(find.text('Juillet 2026')).dy;
      final aoutY = tester.getTopLeft(find.text('Août 2026')).dy;
      expect(juinY, lessThan(juilletY));
      expect(juilletY, lessThan(aoutY));
    },
  );

  testWidgets('filters occurrences by the selected account', (tester) async {
    await _buildLoadedViewModel(
      accounts: [
        _account('account-1', 'Compte courant'),
        _account('account-2', 'Compte épargne'),
      ],
      expensesByAccount: {
        'account-1': [
          _expense(
            id: 'e1',
            accountId: 'account-1',
            name: 'Loyer',
            amount: 850,
            debitDate: DateTime(2026, 8, 5),
          ),
        ],
        'account-2': [
          _expense(
            id: 'e2',
            accountId: 'account-2',
            name: 'Internet',
            amount: 30,
            debitDate: DateTime(2026, 7, 10),
          ),
        ],
      },
    );

    await pumpApp(tester, _page(), size: const Size(400, 1200));

    expect(find.text('Loyer'), findsOneWidget);
    expect(find.text('Internet'), findsOneWidget);
    expect(find.text('2 dépense(s) en attente'), findsOneWidget);

    // Narrow down to the savings account.
    await tester.tap(find.text('Tous les comptes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compte épargne').last);
    await tester.pumpAndSettle();

    expect(find.text('Internet'), findsOneWidget);
    expect(find.text('Loyer'), findsNothing);
    expect(find.text('1 dépense(s) en attente'), findsOneWidget);

    // Back to the full view.
    await tester.tap(find.text('Compte épargne'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tous les comptes'));
    await tester.pumpAndSettle();

    expect(find.text('Loyer'), findsOneWidget);
    expect(find.text('Internet'), findsOneWidget);
    expect(find.text('2 dépense(s) en attente'), findsOneWidget);
  });

  testWidgets(
    'swiping right blocks the card and opens a sheet naming the current '
    'period for both actions',
    (tester) async {
      await _buildLoadedViewModel(
        accounts: [_account('account-1', 'Compte courant')],
        expensesByAccount: {
          'account-1': [
            _expense(
              id: 'e1',
              accountId: 'account-1',
              name: 'Loyer',
              amount: 850,
              debitDate: DateTime(2026, 8, 5),
            ),
          ],
        },
      );

      await pumpApp(tester, _page());

      // The old per-card buttons are gone; nothing is tappable until the
      // user swipes.
      expect(find.text(_carryToCurrentPeriodLabel), findsNothing);
      expect(find.text(_debitOnCurrentPeriodLabel), findsNothing);

      await _swipeRight(tester, 'Loyer');

      // The card is still there (right swipe never completes on its own)...
      expect(find.text('Loyer'), findsOneWidget);
      // The swipe background previews the same two actions as the sheet, so
      // the assertions target the sheet's buttons by their icons (text may be
      // truncated with ellipsis due to maxLines: 1).
      expect(
        find.ancestor(
          of: find.byIcon(Icons.schedule_send_rounded),
          matching: find.byType(FilledButton),
        ),
        findsOneWidget,
      );
      expect(
        find.ancestor(
          of: find.byIcon(Icons.check_circle_outline),
          matching: find.byType(FilledButton),
        ),
        findsOneWidget,
      );
      expect(find.text('Choisir une action'), findsOneWidget);
    },
  );

  testWidgets(
    'swiping right then choosing "report" carries the occurrence to the '
    'current period',
    (tester) async {
      final (
        viewModel: viewModel,
        expenses: expenses,
      ) = await _buildLoadedViewModel(
        accounts: [_account('account-1', 'Compte courant')],
        expensesByAccount: {
          'account-1': [
            _expense(
              id: 'e1',
              accountId: 'account-1',
              name: 'Loyer',
              amount: 850,
              debitDate: DateTime(2026, 8, 5),
            ),
          ],
        },
      );

      await pumpApp(tester, _page());
      await _swipeRight(tester, 'Loyer');
      await tester.tap(
        find.ancestor(
          of: find.byIcon(Icons.schedule_send_rounded),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pumpAndSettle();

      expect(viewModel.state.displayed, isEmpty);
      expect(expenses.moves, hasLength(1));
      expect(expenses.moves.single.$3, _currentPeriodStart);
      expect(expenses.moves.single.$4, isFalse);
    },
  );

  testWidgets('swiping right then choosing "debit now" moves and debits the '
      'occurrence on the current period', (tester) async {
    final (
      viewModel: viewModel,
      expenses: expenses,
    ) = await _buildLoadedViewModel(
      accounts: [_account('account-1', 'Compte courant')],
      expensesByAccount: {
        'account-1': [
          _expense(
            id: 'e1',
            accountId: 'account-1',
            name: 'Loyer',
            amount: 850,
            debitDate: DateTime(2026, 8, 5),
          ),
        ],
      },
    );

    await pumpApp(tester, _page());
    await _swipeRight(tester, 'Loyer');
    await tester.tap(
      find.ancestor(
        of: find.byIcon(Icons.check_circle_outline),
        matching: find.byType(FilledButton),
      ),
    );
    await tester.pumpAndSettle();

    expect(expenses.moves, hasLength(1));
    expect(expenses.moves.single.$3, _currentPeriodStart);
    expect(expenses.moves.single.$4, isTrue);
  });

  testWidgets(
    'swiping right and dismissing the sheet without a choice leaves the '
    'occurrence untouched',
    (tester) async {
      final (
        viewModel: viewModel,
        expenses: expenses,
      ) = await _buildLoadedViewModel(
        accounts: [_account('account-1', 'Compte courant')],
        expensesByAccount: {
          'account-1': [
            _expense(
              id: 'e1',
              accountId: 'account-1',
              name: 'Loyer',
              amount: 850,
              debitDate: DateTime(2026, 8, 5),
            ),
          ],
        },
      );

      await pumpApp(tester, _page());
      await _swipeRight(tester, 'Loyer');
      // Tap outside the sheet to dismiss it without picking an action.
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(find.text('Loyer'), findsOneWidget);
      expect(expenses.moves, isEmpty);
      expect(expenses.marks, isEmpty);
    },
  );

  testWidgets(
    'swiping left immediately debits the occurrence on its original period, '
    'with no sheet involved',
    (tester) async {
      final (
        viewModel: viewModel,
        expenses: expenses,
      ) = await _buildLoadedViewModel(
        accounts: [_account('account-1', 'Compte courant')],
        expensesByAccount: {
          'account-1': [
            _expense(
              id: 'e1',
              accountId: 'account-1',
              name: 'Loyer',
              amount: 850,
              debitDate: DateTime(2026, 8, 5),
            ),
          ],
        },
      );

      await pumpApp(tester, _page());
      await _swipeLeft(tester, 'Loyer');

      expect(find.text('Choisir une action'), findsNothing);
      expect(expenses.marks, hasLength(1));
      expect(expenses.marks.single.$2, DateTime(2026, 8, 5));
    },
  );

  testWidgets(
    'swipe is disabled in selection mode; tapping a card toggles it instead',
    (tester) async {
      final (
        viewModel: viewModel,
        expenses: expenses,
      ) = await _buildLoadedViewModel(
        accounts: [_account('account-1', 'Compte courant')],
        expensesByAccount: {
          'account-1': [
            _expense(
              id: 'e1',
              accountId: 'account-1',
              name: 'Loyer',
              amount: 850,
              debitDate: DateTime(2026, 8, 5),
            ),
          ],
        },
      );

      await pumpApp(tester, _page());
      await tester.longPress(find.text('Loyer'));
      await tester.pumpAndSettle();
      expect(viewModel.state.selectionMode, isTrue);

      final dismissible = tester.widget<Dismissible>(_cardFor('Loyer'));
      expect(dismissible.direction, DismissDirection.none);

      // A swipe attempt has no effect while selecting...
      await _swipeRight(tester, 'Loyer');
      expect(find.text('Choisir une action'), findsNothing);
      expect(expenses.moves, isEmpty);

      // ...but a plain tap toggles the card out of the selection.
      await tester.tap(find.text('Loyer'));
      await tester.pumpAndSettle();
      expect(
        viewModel.state.selected.contains(viewModel.state.displayed.single.key),
        isFalse,
      );
    },
  );

  testWidgets('sheet amounts always honor the profile decimal places', (
    tester,
  ) async {
    await _buildLoadedViewModel(
      accounts: [_account('account-1', 'Compte courant')],
      expensesByAccount: {
        'account-1': [
          _expense(
            id: 'e1',
            accountId: 'account-1',
            name: 'Loyer',
            amount: 850,
            debitDate: DateTime(2026, 8, 5),
          ),
        ],
      },
    );

    await pumpApp(tester, _page());

    // Even whole amounts are shown with the configured decimals.
    expect(find.textContaining('850,00'), findsWidgets);
  });

  testWidgets('long press enters selection mode and hides individual actions', (
    tester,
  ) async {
    await _buildLoadedViewModel(
      accounts: [_account('account-1', 'Compte courant')],
      expensesByAccount: {
        'account-1': [
          _expense(
            id: 'e1',
            accountId: 'account-1',
            name: 'Loyer',
            amount: 850,
            debitDate: DateTime(2026, 8, 5),
          ),
          _expense(
            id: 'e2',
            accountId: 'account-1',
            name: 'Internet',
            amount: 30,
            debitDate: DateTime(2026, 8, 10),
          ),
        ],
      },
    );

    await pumpApp(tester, _page(), size: const Size(400, 1400));
    await tester.longPress(find.text('Loyer'));
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
    expect(find.text('sélectionnées'), findsOneWidget);
    expect(find.text('Tout sélectionner'), findsOneWidget);
    expect(find.text('Tout désélectionner'), findsOneWidget);
    expect(find.text(_carryToCurrentPeriodLabel), findsOneWidget);
    expect(find.text('Débiter sur la période d\'origine'), findsOneWidget);
    // Individual card actions are hidden; only the sticky bulk actions remain.
    expect(find.byType(FilledButton), findsNWidgets(3));
  });

  testWidgets(
    'bulk action processes only selected expenses and exits selection mode',
    (tester) async {
      final (
        viewModel: viewModel,
        expenses: expenses,
      ) = await _buildLoadedViewModel(
        accounts: [_account('account-1', 'Compte courant')],
        expensesByAccount: {
          'account-1': [
            _expense(
              id: 'e1',
              accountId: 'account-1',
              name: 'Loyer',
              amount: 850,
              debitDate: DateTime(2026, 8, 5),
            ),
            _expense(
              id: 'e2',
              accountId: 'account-1',
              name: 'Internet',
              amount: 30,
              debitDate: DateTime(2026, 8, 10),
            ),
          ],
        },
      );

      await _openReportPage(tester, size: const Size(400, 1400));
      await tester.longPress(find.text('Loyer'));
      await tester.pump();
      await tester.tap(find.text('Internet'));
      await tester.pumpAndSettle();

      expect(find.text('2'), findsOneWidget);
      expect(find.text('sélectionnées'), findsOneWidget);
      await tester.tap(find.text(_carryToCurrentPeriodLabel));
      await tester.pumpAndSettle();

      expect(expenses.moves, hasLength(2));
      expect(
        expenses.moves.map((move) => move.$1.id),
        containsAll(<String?>['e1', 'e2']),
      );
      // Handling every undebited expense closes the report page.
      expect(find.text('Dépenses à traiter'), findsNothing);
      expect(find.byType(Placeholder), findsOneWidget);
    },
  );

  testWidgets('handling the last occurrence closes the report page', (
    tester,
  ) async {
    await _buildLoadedViewModel(
      accounts: [_account('account-1', 'Compte courant')],
      expensesByAccount: {
        'account-1': [
          _expense(
            id: 'e1',
            accountId: 'account-1',
            name: 'Loyer',
            amount: 850,
            debitDate: DateTime(2026, 8, 5),
          ),
        ],
      },
    );

    await _openReportPage(tester);

    expect(find.text('Dépenses à traiter'), findsOneWidget);
    await tester.longPress(find.text('Loyer'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Reporter vers'));
    await tester.pumpAndSettle();

    expect(find.text('Dépenses à traiter'), findsNothing);
    expect(find.byType(Placeholder), findsOneWidget);
  });

  testWidgets('shows an empty state when nothing is left to process', (
    tester,
  ) async {
    await _buildLoadedViewModel(
      accounts: [_account('account-1', 'Compte courant')],
    );

    await pumpApp(tester, _page());

    expect(find.text('0 dépense(s) en attente'), findsOneWidget);
    expect(find.text('Aucune dépense non débitée'), findsOneWidget);
  });

  testWidgets(
    'the gesture hint mentions swiping now that per-card buttons are gone',
    (tester) async {
      await _buildLoadedViewModel(
        accounts: [_account('account-1', 'Compte courant')],
        expensesByAccount: {
          'account-1': [
            _expense(
              id: 'e1',
              accountId: 'account-1',
              name: 'Loyer',
              amount: 850,
              debitDate: DateTime(2026, 8, 5),
            ),
          ],
        },
      );

      await pumpApp(tester, _page());

      expect(
        find.text(
          'Glissez une dépense pour des actions rapides, ou appuyez '
          "longuement pour en sélectionner plusieurs.",
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'selection mode shows a dedicated hint explaining swipe is disabled',
    (tester) async {
      await _buildLoadedViewModel(
        accounts: [_account('account-1', 'Compte courant')],
        expensesByAccount: {
          'account-1': [
            _expense(
              id: 'e1',
              accountId: 'account-1',
              name: 'Loyer',
              amount: 850,
              debitDate: DateTime(2026, 8, 5),
            ),
          ],
        },
      );

      await pumpApp(tester, _page());

      await tester.longPress(find.text('Loyer'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          "Appuyez sur une dépense pour l'ajouter ou la retirer de la "
          'sélection. Le glissement est désactivé pendant la sélection.',
        ),
        findsOneWidget,
      );
    },
  );

  test(
    'dismiss persists through the shared LocalCache, not a private instance',
    () async {
      final cache = _RecordingLocalCache();
      final previous = Period.fromDate(DateTime.now()).previous;
      final built = await _buildLoadedViewModel(
        accounts: [_account('a1', 'Main')],
        expensesByAccount: {
          'a1': [
            _expense(
              id: 'e1',
              accountId: 'a1',
              name: 'Rent',
              amount: 10,
              debitDate: DateTime(previous.year, previous.month, 5),
            ),
          ],
        },
        localCache: cache,
      );

      await built.viewModel.dismiss();

      expect(cache.dismissedAccountIds, ['a1']);
    },
  );
}
