import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/pages/undebited_expenses/view.dart';
import 'package:budgly/src/pages/undebited_expenses/view_model.dart';
import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/services/expenses/undebited_expenses_service.dart';
import 'package:budgly/src/services/offline/local_cache.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_stores.dart';
import '../../helpers/pump_app.dart';

class _FakeExpensesService extends ExpensesService {
  final Map<String, List<Expense>> byAccount;
  final List<(Expense, DateTime)> marks = [];
  final List<(Expense, DateTime, DateTime, bool)> moves = [];

  _FakeExpensesService(this.byAccount);

  List<Expense> _for(String accountId) =>
      List.unmodifiable(byAccount[accountId] ?? const []);

  void _removeWhere(bool Function(Expense) test) {
    for (final expenses in byAccount.values) {
      expenses.removeWhere(test);
    }
    notifyListeners();
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

class _FakeAccountsService extends AccountsService {
  final List<Account> values;
  _FakeAccountsService(this.values);

  @override
  List<Account> get accounts => values;

  @override
  bool get hasLoaded => true;

  @override
  Future<void> loadAccounts({bool forceRefresh = false}) async {}
}

class _FakeProfileService extends ProfileService {
  @override
  String get currency => 'EUR';

  @override
  int get amountDecimalPlaces => 2;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

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

Future<({UndebitedExpensesViewModel viewModel, _FakeExpensesService expenses})>
    _buildLoadedViewModel({
  List<Account> accounts = const [],
  Map<String, List<Expense>> expensesByAccount = const {},
  DateTime? now,
  VoidCallback? onResolved,
}) async {
  final expensesService = _FakeExpensesService(
    Map<String, List<Expense>>.from(expensesByAccount),
  );
  final clock = now == null ? DateTime.now : () => now;
  addTearDown(expensesService.dispose);

  final service = UndebitedExpensesService(
    expensesService: expensesService,
    localCache: LocalCache(),
    now: clock,
  );

  final viewModel = UndebitedExpensesViewModel(
    service: service,
    expensesService: expensesService,
    accountsService: _FakeAccountsService(accounts),
    profileService: _FakeProfileService(),
    now: clock,
    onResolved: onResolved,
  );
  addTearDown(viewModel.dispose);
  await viewModel.ensureDataLoaded();
  return (viewModel: viewModel, expenses: expensesService);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'the bulk "debit on original period" button uses a generic label, not a '
    'specific period, since a selection can span several original periods',
    (tester) async {
final (viewModel: viewModel, expenses: _) = await _buildLoadedViewModel(
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

      await pumpApp(
        tester,
        UndebitedExpensesPage(injectedViewModel: viewModel),
        size: const Size(400, 1200),
      );

      await tester.longPress(find.text('Loyer mars').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tout sélectionner'));

      expect(
        find.text("Débiter sur la période d'origine"),
        findsOneWidget,
        reason: 'the bulk action must not claim a specific original period '
            'when the selection spans several different ones',
      );
      final marchLabel = const Period(year: 2026, month: 3).label('fr');
      final juneLabel = const Period(year: 2026, month: 6).label('fr');
      expect(find.text('Débiter sur $marchLabel'), findsNothing);
      expect(find.text('Débiter sur $juneLabel'), findsNothing);
    },
  );

  testWidgets('aggregates every account, groups by period and shows full dates', (tester) async {
    final (viewModel: viewModel, expenses: _) = await _buildLoadedViewModel(
      accounts: [
        _account('account-1', 'Compte courant'),
        _account('account-2', 'Compte épargne'),
      ],
      expensesByAccount: {
        'account-1': [
          _expense(id: 'e1', accountId: 'account-1', name: 'Août long', amount: 100, debitDate: DateTime(2026, 8, 20)),
          _expense(id: 'e3', accountId: 'account-1', name: 'Juin y', amount: 25, debitDate: DateTime(2026, 6, 1)),
        ],
        'account-2': [
          _expense(id: 'e2', accountId: 'account-2', name: 'Juillet x', amount: 50, debitDate: DateTime(2026, 7, 10)),
        ],
      },
    );

    await pumpApp(
      tester,
      UndebitedExpensesPage(injectedViewModel: viewModel),
      size: const Size(400, 1500),
    );

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
  });

  testWidgets('filters occurrences by the selected account', (tester) async {
    final (viewModel: viewModel, expenses: _) = await _buildLoadedViewModel(
      accounts: [
        _account('account-1', 'Compte courant'),
        _account('account-2', 'Compte épargne'),
      ],
      expensesByAccount: {
        'account-1': [
          _expense(id: 'e1', accountId: 'account-1', name: 'Loyer', amount: 850, debitDate: DateTime(2026, 8, 5)),
        ],
        'account-2': [
          _expense(id: 'e2', accountId: 'account-2', name: 'Internet', amount: 30, debitDate: DateTime(2026, 7, 10)),
        ],
      },
    );

    await pumpApp(
      tester,
      UndebitedExpensesPage(injectedViewModel: viewModel),
      size: const Size(400, 1200),
    );

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

  testWidgets('carry action moves an occurrence to the current period', (tester) async {
    final (viewModel: viewModel, expenses: expenses) = await _buildLoadedViewModel(
      accounts: [_account('account-1', 'Compte courant')],
      expensesByAccount: {
        'account-1': [
          _expense(id: 'e1', accountId: 'account-1', name: 'Loyer', amount: 850, debitDate: DateTime(2026, 8, 5)),
        ],
      },
    );

    await pumpApp(
      tester,
      UndebitedExpensesPage(injectedViewModel: viewModel),
    );
    await tester.tap(find.text('Reporter vers Septembre 2026'));
    await tester.pumpAndSettle();

    expect(viewModel.occurrences, isEmpty);
    expect(expenses.moves, hasLength(1));
    expect(expenses.moves.single.$3, DateTime(2026, 9, 1));
    expect(expenses.moves.single.$4, isFalse);
  });

  testWidgets('debit on original period marks the historical occurrence', (tester) async {
    final (viewModel: viewModel, expenses: expenses) = await _buildLoadedViewModel(
      accounts: [_account('account-1', 'Compte courant')],
      expensesByAccount: {
        'account-1': [
          _expense(id: 'e1', accountId: 'account-1', name: 'Loyer', amount: 850, debitDate: DateTime(2026, 8, 5)),
        ],
      },
    );

    await pumpApp(
      tester,
      UndebitedExpensesPage(injectedViewModel: viewModel),
    );
    await tester.tap(find.text('Débiter sur Août 2026'));
    await tester.pumpAndSettle();

    expect(expenses.marks, hasLength(1));
    expect(expenses.marks.single.$2, DateTime(2026, 8, 5));
  });

  testWidgets('debit now moves and debits the occurrence on the current period', (tester) async {
    final (viewModel: viewModel, expenses: expenses) = await _buildLoadedViewModel(
      accounts: [_account('account-1', 'Compte courant')],
      expensesByAccount: {
        'account-1': [
          _expense(id: 'e1', accountId: 'account-1', name: 'Loyer', amount: 850, debitDate: DateTime(2026, 8, 5)),
        ],
      },
    );

    await pumpApp(
      tester,
      UndebitedExpensesPage(injectedViewModel: viewModel),
    );
    await tester.tap(find.text('Débiter en Septembre 2026'));
    await tester.pumpAndSettle();

    expect(expenses.moves, hasLength(1));
    expect(expenses.moves.single.$3, DateTime(2026, 9, 1));
    expect(expenses.moves.single.$4, isTrue);
  });

  testWidgets('action buttons target the origin and current periods by name', (tester) async {
    final (viewModel: viewModel, expenses: _) = await _buildLoadedViewModel(
      accounts: [_account('account-1', 'Compte courant')],
      expensesByAccount: {
        'account-1': [
          _expense(id: 'e1', accountId: 'account-1', name: 'Loyer', amount: 850, debitDate: DateTime(2026, 8, 5)),
        ],
      },
    );

    await pumpApp(
      tester,
      UndebitedExpensesPage(injectedViewModel: viewModel),
    );

    expect(find.text('Reporter vers Septembre 2026'), findsOneWidget);
    expect(find.text('Débiter sur Août 2026'), findsOneWidget);
    expect(find.text('Débiter en Septembre 2026'), findsOneWidget);
  });

  testWidgets('sheet amounts always honor the profile decimal places', (tester) async {
    final (viewModel: viewModel, expenses: _) = await _buildLoadedViewModel(
      accounts: [_account('account-1', 'Compte courant')],
      expensesByAccount: {
        'account-1': [
          _expense(id: 'e1', accountId: 'account-1', name: 'Loyer', amount: 850, debitDate: DateTime(2026, 8, 5)),
        ],
      },
    );

    await pumpApp(
      tester,
      UndebitedExpensesPage(injectedViewModel: viewModel),
    );

    // Even whole amounts are shown with the configured decimals.
    expect(find.textContaining('850,00'), findsWidgets);
  });

  testWidgets('long press enters selection mode and hides individual actions', (tester) async {
    final (viewModel: viewModel, expenses: _) = await _buildLoadedViewModel(
      accounts: [_account('account-1', 'Compte courant')],
      expensesByAccount: {
        'account-1': [
          _expense(id: 'e1', accountId: 'account-1', name: 'Loyer', amount: 850, debitDate: DateTime(2026, 8, 5)),
          _expense(id: 'e2', accountId: 'account-1', name: 'Internet', amount: 30, debitDate: DateTime(2026, 8, 10)),
        ],
      },
    );

    await pumpApp(
      tester,
      UndebitedExpensesPage(injectedViewModel: viewModel),
      size: const Size(400, 1400),
    );
    await tester.longPress(find.text('Loyer'));
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
    expect(find.text('sélectionnées'), findsOneWidget);
    expect(find.text('Tout sélectionner'), findsOneWidget);
    expect(find.text('Tout désélectionner'), findsOneWidget);
    expect(find.text('Reporter vers Septembre 2026'), findsOneWidget);
    expect(find.text('Débiter sur la période d\'origine'), findsOneWidget);
    // Individual card actions are hidden; only the sticky bulk actions remain.
    expect(find.byType(FilledButton), findsNWidgets(3));
  });

  testWidgets('bulk action processes only selected expenses and exits selection mode', (tester) async {
    final (viewModel: viewModel, expenses: expenses) = await _buildLoadedViewModel(
      accounts: [_account('account-1', 'Compte courant')],
      expensesByAccount: {
        'account-1': [
          _expense(id: 'e1', accountId: 'account-1', name: 'Loyer', amount: 850, debitDate: DateTime(2026, 8, 5)),
          _expense(id: 'e2', accountId: 'account-1', name: 'Internet', amount: 30, debitDate: DateTime(2026, 8, 10)),
        ],
      },
    );

    await pumpApp(
      tester,
      UndebitedExpensesPage(injectedViewModel: viewModel),
      size: const Size(400, 1400),
    );
    await tester.longPress(find.text('Loyer'));
    await tester.pump();
    await tester.tap(find.text('Internet'));
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);
    expect(find.text('sélectionnées'), findsOneWidget);
    await tester.tap(find.text('Reporter vers Septembre 2026'));
    await tester.pumpAndSettle();

    expect(expenses.moves, hasLength(2));
    expect(
      expenses.moves.map((move) => move.$1.id),
      containsAll(<String?>['e1', 'e2']),
    );
    expect(find.text('Aucune dépense non débitée'), findsOneWidget);
  });

  testWidgets('handling the last occurrence closes the report page', (tester) async {
    clearAllTestStores();
    seedAccounts([_account('account-1', 'Compte courant')]);
    seedExpenses('account-1', [
      _expense(id: 'e1', accountId: 'account-1', name: 'Loyer', amount: 850, debitDate: DateTime(2026, 8, 5)),
    ]);

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
      MaterialPageRoute<void>(builder: (_) => const UndebitedExpensesPage()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dépenses à traiter'), findsOneWidget);
    await tester.longPress(find.text('Loyer'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Reporter vers'));
    await tester.pumpAndSettle();

    expect(find.text('Dépenses à traiter'), findsNothing);
    expect(find.byType(Placeholder), findsOneWidget);
  });

  testWidgets('shows an empty state when nothing is left to process', (tester) async {
    final (viewModel: viewModel, expenses: _) = await _buildLoadedViewModel(
      accounts: [_account('account-1', 'Compte courant')],
    );

    await pumpApp(
      tester,
      UndebitedExpensesPage(injectedViewModel: viewModel),
    );

    expect(find.text('0 dépense(s) en attente'), findsOneWidget);
    expect(find.text('Aucune dépense non débitée'), findsOneWidget);
  });
}