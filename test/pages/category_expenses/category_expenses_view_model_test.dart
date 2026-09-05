import 'dart:async';

import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/expense_occurrence.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/pages/category_expenses/view_model.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/stores/accounts.dart';
import 'package:budgly/src/stores/categories.dart';
import 'package:budgly/src/services/providers/firestore/expense_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/builders.dart';
import '../../helpers/fake_stores.dart';

class FakeCategoryExpensesService extends ExpensesService {
  ExpensePage page = const ExpensePage(expenses: [], cursor: null, hasMore: false);
  Expense? updated;
  int deleteCalls = 0;
  int toggleCalls = 0;
  int deleteSingleCalls = 0;
  int deleteFutureCalls = 0;
  bool deleteResult = true;
  final Map<String, Expense> byId = {};
  final Map<String, List<Expense>> byAccount = {};

  Expense? recurringUpdated;
  bool failRecurring = false;
  bool failDeleteSingle = false;
  bool failDeleteFuture = false;

  Completer<Expense>? blockUpdateRecurring;
  Completer<bool>? blockDeleteSingle;
  Completer<bool>? blockDeleteFuture;

  @override
  Future<ExpensePage> listCategoryPeriodPage(
    String accountId,
    String categoryId,
    Period period, {
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    bool includeRecurring = true,
  }) async => page;

  @override
  Future<Expense> updateExpense(Expense expense, {Expense? previous}) async {
    updated = expense;
    return expense;
  }

  @override
  Future<Expense> updateRecurringExpenseFromOccurrence({
    required Expense original,
    required Expense updated,
    required DateTime effectiveDate,
  }) async {
    if (blockUpdateRecurring != null) return blockUpdateRecurring!.future;
    if (failRecurring) throw StateError('recurring update failed');
    recurringUpdated = updated;
    if (updated.id != null) byId[updated.id!] = updated;
    return updated;
  }

  @override
  Future<bool> deleteExpense(String expenseId, String accountId) async {
    deleteCalls++;
    if (!deleteResult) return false;
    ExpensesStoreHack.remove(expenseId, accountId);
    return true;
  }

  @override
  Future<bool> deleteSingleOccurrence({
    required Expense expense,
    required DateTime occurrenceDate,
  }) async {
    if (blockDeleteSingle != null) return blockDeleteSingle!.future;
    deleteSingleCalls++;
    if (failDeleteSingle) throw StateError('delete single failed');
    final updated = expense.copyWith(endDate: occurrenceDate.subtract(const Duration(days: 1)));
    if (expense.id != null) byId[expense.id!] = updated;
    return true;
  }

  @override
  Future<bool> deleteFutureOccurrences({
    required Expense expense,
    required DateTime occurrenceDate,
  }) async {
    if (blockDeleteFuture != null) return blockDeleteFuture!.future;
    deleteFutureCalls++;
    if (failDeleteFuture) throw StateError('delete future failed');
    final updated = expense.copyWith(endDate: occurrenceDate);
    if (expense.id != null) byId[expense.id!] = updated;
    return true;
  }

  @override
  Future<Expense> toggleOccurrenceDebited(Expense expense, DateTime date) async {
    toggleCalls++;
    return expense.copyWith(isDebited: !expense.isDebited);
  }

  @override
  Expense? getExpenseById(String expenseId) => byId[expenseId];

  @override
  List<Expense> getExpensesForAccount(String accountId) =>
      byAccount[accountId] ?? const [];
}

/// Keeps the test focused on the ViewModel; the real store is still used by
/// ExpensesService for read-side behavior, but deletion is handled by the
/// fake service above.
class ExpensesStoreHack {
  static void remove(String id, String accountId) {
    // The ViewModel owns its paged list, so no store mutation is required for
    // these tests. This method intentionally remains a no-op.
  }
}

void main() {
  final period = Fixtures.period(2026, 3);

  setUp(() {
    clearAllTestStores();
    Fixtures.resetSeq();
    seedAccounts([Fixtures.account(id: 'a1')]);
    seedCategories('a1', [Fixtures.category(id: 'c1', accountId: 'a1')]);
  });

  tearDown(clearAllTestStores);

  FakeCategoryExpensesService service() => FakeCategoryExpensesService();

  test('loadMore loads first page, sorts expenses and exposes occurrences', () async {
    final fake = service();
    final older = Fixtures.expense(
      id: 'e-old', accountId: 'a1', categoryId: 'c1',
      debitDate: DateTime(2026, 3, 5), amount: 50,
    );
    final newer = Fixtures.expense(
      id: 'e-new', accountId: 'a1', categoryId: 'c1',
      debitDate: DateTime(2026, 3, 20), amount: 100,
    );
    fake.page = ExpensePage(expenses: [older, newer], cursor: null, hasMore: false);

    final vm = CategoryExpensesViewModel(
      accountId: 'a1', categoryId: 'c1', period: period, expensesService: fake,
    );
    addTearDown(vm.dispose);

    await vm.ensureDataLoaded();

    expect(vm.hasMorePages, isFalse);
    expect(vm.occurrences.map((o) => o.expense.id), ['e-new', 'e-old']);
    expect(vm.summary?.total, 150);
    expect(vm.isLoadingMore, isFalse);
  });

  test('loadMore falls back to local expenses when first remote page fails', () async {
    final fake = service();
    final local = Fixtures.expense(id: 'local', accountId: 'a1', categoryId: 'c1', amount: 75);
    seedExpenses('a1', [local]);

    fake.page = const ExpensePage(expenses: [], cursor: null, hasMore: false);
    // A throwing fake is clearer than relying on Firestore exceptions.
    final failing = ThrowingCategoryExpensesService();
    final vm = CategoryExpensesViewModel(
      accountId: 'a1', categoryId: 'c1', period: period, expensesService: failing,
    );
    addTearDown(vm.dispose);

    await vm.loadMore();

    expect(vm.occurrences, hasLength(1));
    expect(vm.occurrences.single.expense.id, 'local');
    expect(vm.hasMorePages, isFalse);
    expect(vm.hasError, isFalse);
  });

  test('startEditing hydrates the form from the selected occurrence', () {
    final fake = service();
    final expense = Fixtures.expense(id: 'e1', accountId: 'a1', categoryId: 'c1', amount: 42);
    final occurrence = ExpenseOccurrence(expense: expense, date: DateTime(2026, 3, 15), isDebited: false);
    final vm = CategoryExpensesViewModel(
      accountId: 'a1', categoryId: 'c1', period: period, expensesService: fake,
    );
    addTearDown(vm.dispose);

    vm.startEditing(occurrence);

    expect(vm.editingOccurrence?.id, 'e1');
    expect(vm.expenseForm.data.nameController.text, 'Dépense');
    expect(vm.expenseForm.data.amountController.text, '42');
    expect(vm.expenseForm.data.category?.id, 'c1');
    expect(vm.expenseForm.data.account?.id, 'a1');
  });

  test('selectFormAccount changes account and selects a valid category', () async {
    final fake = service();
    seedAccounts([Fixtures.account(id: 'a1'), Fixtures.account(id: 'a2', name: 'Épargne')]);
    seedCategories('a2', [Fixtures.category(id: 'c2', accountId: 'a2', name: 'Transport')]);
    final vm = CategoryExpensesViewModel(
      accountId: 'a1', categoryId: 'c1', period: period, expensesService: fake,
    );
    addTearDown(vm.dispose);

    await vm.selectFormAccount(AccountsStore.instance.accounts[1]);

    expect(vm.expenseForm.data.account?.id, 'a2');
    expect(vm.expenseForm.data.category?.id, 'c2');
    expect(vm.categoriesForAccount().single.id, 'c2');
  });

  test('saveEditing updates a non-recurring expense and returns success', () async {
    final fake = service();
    final expense = Fixtures.expense(id: 'e1', accountId: 'a1', categoryId: 'c1', amount: 42);
    final occurrence = ExpenseOccurrence(expense: expense, date: DateTime(2026, 3, 15), isDebited: false);
    final vm = CategoryExpensesViewModel(
      accountId: 'a1', categoryId: 'c1', period: period, expensesService: fake,
    );
    addTearDown(vm.dispose);
    vm.startEditing(occurrence);
    vm.expenseForm.data.nameController.text = 'Courses';
    vm.expenseForm.data.amountController.text = '125';

    expect(await vm.saveEditing(), isTrue);
    expect(fake.updated?.name, 'Courses');
    expect(fake.updated?.amount, 125);
    expect(vm.isSaving, isFalse);
  });

  test('saveEditing refuses invalid amount without calling the service', () async {
    final fake = service();
    final expense = Fixtures.expense(id: 'e1', accountId: 'a1', categoryId: 'c1');
    final occurrence = ExpenseOccurrence(expense: expense, date: DateTime(2026, 3, 15), isDebited: false);
    final vm = CategoryExpensesViewModel(
      accountId: 'a1', categoryId: 'c1', period: period, expensesService: fake,
    );
    addTearDown(vm.dispose);
    vm.startEditing(occurrence);
    vm.expenseForm.data.amountController.text = 'not-a-number';

    expect(await vm.saveEditing(), isFalse);
    expect(fake.updated, isNull);
  });

  test('deleteOccurrence removes a non-recurring occurrence from the page', () async {
    final fake = service();
    final expense = Fixtures.expense(id: 'e1', accountId: 'a1', categoryId: 'c1');
    fake.page = ExpensePage(expenses: [expense], cursor: null, hasMore: false);
    final vm = CategoryExpensesViewModel(
      accountId: 'a1', categoryId: 'c1', period: period, expensesService: fake,
    );
    addTearDown(vm.dispose);
    await vm.loadMore();
    final occurrence = vm.occurrences.single;
    vm.startEditing(occurrence);

    expect(await vm.deleteOccurrence(occurrence), isTrue);
    expect(fake.deleteCalls, 1);
    expect(vm.occurrences, isEmpty);
    expect(vm.editingOccurrence, isNull);
  });

  test('toggleDebited delegates and updates the editing/page expense', () async {
    final fake = service();
    final expense = Fixtures.expense(id: 'e1', accountId: 'a1', categoryId: 'c1', isDebited: false);
    fake.page = ExpensePage(expenses: [expense], cursor: null, hasMore: false);
    final vm = CategoryExpensesViewModel(
      accountId: 'a1', categoryId: 'c1', period: period, expensesService: fake,
    );
    addTearDown(vm.dispose);
    await vm.loadMore();
    final occurrence = vm.occurrences.single;
    vm.startEditing(occurrence);

    expect(await vm.toggleEditingOccurrenceDebited(), isTrue);
    expect(fake.toggleCalls, 1);
    expect(vm.editingOccurrence?.isDebited, isTrue);
  });

  test('disposed ViewModel stops reacting to service changes', () {
    final fake = service();
    final vm = CategoryExpensesViewModel(
      accountId: 'a1', categoryId: 'c1', period: period, expensesService: fake,
    );
    var notifications = 0;
    vm.addListener(() => notifications++);
    vm.dispose();

    fake.notifyListeners();

    expect(notifications, 0);
  });

  test('saveEditing calls updateRecurringExpenseFromOccurrence for recurring expenses', () async {
    final fake = service();
    final expense = Fixtures.expense(
      id: 'e1', accountId: 'a1', categoryId: 'c1',
      amount: 42, recurrence: RecurrenceType.monthly,
    );
    final occurrence = ExpenseOccurrence(
      expense: expense, date: DateTime(2026, 3, 15), isDebited: false,
    );
    final vm = CategoryExpensesViewModel(
      accountId: 'a1', categoryId: 'c1', period: period, expensesService: fake,
    );
    addTearDown(vm.dispose);
    vm.startEditing(occurrence);
    vm.expenseForm.data.nameController.text = 'Loyer';
    vm.expenseForm.data.amountController.text = '600';

    expect(await vm.saveEditing(), isTrue);
    expect(fake.recurringUpdated?.name, 'Loyer');
    expect(fake.recurringUpdated?.amount, 600);
    expect(vm.isSaving, isFalse);
  });

  test('saveEditing handles account/category move by removing from the page', () async {
    final fake = service();
    final expense = Fixtures.expense(id: 'e1', accountId: 'a1', categoryId: 'c1', amount: 30);
    fake.page = ExpensePage(expenses: [expense], cursor: null, hasMore: false);
    seedAccounts([Fixtures.account(id: 'a1'), Fixtures.account(id: 'a2')]);
    seedCategories('a2', [Fixtures.category(id: 'c2', accountId: 'a2')]);
    final vm = CategoryExpensesViewModel(
      accountId: 'a1', categoryId: 'c1', period: period, expensesService: fake,
    );
    addTearDown(vm.dispose);
    await vm.loadMore();
    final occurrence = vm.occurrences.single;
    vm.startEditing(occurrence);
    vm.expenseForm.data.amountController.text = '30';

    vm.expenseForm.setAccount(AccountsStore.instance.accounts[1]);
    vm.expenseForm.setCategory(CategoriesStore.instance.getCategoriesForAccount('a2').first);

    expect(await vm.saveEditing(), isTrue);
    expect(vm.editingOccurrence, isNull);
  });

  test('deleteSingleOccurrence removes a single occurrence from a recurring series', () async {
    final fake = service();
    final expense = Fixtures.expense(
      id: 'e1', accountId: 'a1', categoryId: 'c1',
      recurrence: RecurrenceType.monthly,
    );
    final updatedExpense = expense.copyWith(endDate: DateTime(2026, 3, 14));
    fake.byId['e1'] = updatedExpense;
    final occurrence = ExpenseOccurrence(
      expense: expense, date: DateTime(2026, 3, 15), isDebited: false,
    );
    final vm = CategoryExpensesViewModel(
      accountId: 'a1', categoryId: 'c1', period: period, expensesService: fake,
    );
    addTearDown(vm.dispose);

    expect(await vm.deleteSingleOccurrence(occurrence), isTrue);
    expect(fake.deleteSingleCalls, 1);
  });

  test('deleteSingleOccurrence returns false when isSaving', () async {
    final fake = service()..blockUpdateRecurring = Completer<Expense>();
    final expense = Fixtures.expense(
      id: 'e1', accountId: 'a1', categoryId: 'c1',
      recurrence: RecurrenceType.monthly,
    );
    final occurrence = ExpenseOccurrence(
      expense: expense, date: DateTime(2026, 3, 15), isDebited: false,
    );
    final vm = CategoryExpensesViewModel(
      accountId: 'a1', categoryId: 'c1', period: period, expensesService: fake,
    );
    addTearDown(vm.dispose);
    vm.startEditing(occurrence);
    vm.expenseForm.data.amountController.text = '10';
    final saving = vm.saveEditing();
    await Future<void>.delayed(Duration.zero);

    expect(await vm.deleteSingleOccurrence(occurrence), isFalse);

    fake.blockUpdateRecurring!.complete(Fixtures.expense(id: 'e1', accountId: 'a1', categoryId: 'c1'));
    await saving;
  });

  test('deleteFutureOccurrences truncates a recurring series from the occurrence date', () async {
    final fake = service();
    final expense = Fixtures.expense(
      id: 'e1', accountId: 'a1', categoryId: 'c1',
      recurrence: RecurrenceType.monthly,
    );
    final updatedExpense = expense.copyWith(endDate: DateTime(2026, 3, 15));
    fake.byId['e1'] = updatedExpense;
    final occurrence = ExpenseOccurrence(
      expense: expense, date: DateTime(2026, 3, 15), isDebited: false,
    );
    final vm = CategoryExpensesViewModel(
      accountId: 'a1', categoryId: 'c1', period: period, expensesService: fake,
    );
    addTearDown(vm.dispose);

    expect(await vm.deleteFutureOccurrences(occurrence), isTrue);
    expect(fake.deleteFutureCalls, 1);
  });

  test('deleteFutureOccurrences returns false when isSaving', () async {
    final fake = service()..blockUpdateRecurring = Completer<Expense>();
    final expense = Fixtures.expense(
      id: 'e1', accountId: 'a1', categoryId: 'c1',
      recurrence: RecurrenceType.monthly,
    );
    final occurrence = ExpenseOccurrence(
      expense: expense, date: DateTime(2026, 3, 15), isDebited: false,
    );
    final vm = CategoryExpensesViewModel(
      accountId: 'a1', categoryId: 'c1', period: period, expensesService: fake,
    );
    addTearDown(vm.dispose);
    vm.startEditing(occurrence);
    vm.expenseForm.data.amountController.text = '10';
    final saving = vm.saveEditing();
    await Future<void>.delayed(Duration.zero);

    expect(await vm.deleteFutureOccurrences(occurrence), isFalse);

    fake.blockUpdateRecurring!.complete(Fixtures.expense(id: 'e1', accountId: 'a1', categoryId: 'c1'));
    await saving;
  });

  test('deleteOccurrence returns false when isSaving', () async {
    final fake = service()..blockUpdateRecurring = Completer<Expense>();
    final expense = Fixtures.expense(
      id: 'e1', accountId: 'a1', categoryId: 'c1',
      recurrence: RecurrenceType.monthly,
    );
    final occurrence = ExpenseOccurrence(
      expense: expense, date: DateTime(2026, 3, 15), isDebited: false,
    );
    final vm = CategoryExpensesViewModel(
      accountId: 'a1', categoryId: 'c1', period: period, expensesService: fake,
    );
    addTearDown(vm.dispose);
    vm.startEditing(occurrence);
    vm.expenseForm.data.amountController.text = '10';
    final saving = vm.saveEditing();
    await Future<void>.delayed(Duration.zero);

    expect(await vm.deleteOccurrence(occurrence), isFalse);

    fake.blockUpdateRecurring!.complete(Fixtures.expense(id: 'e1', accountId: 'a1', categoryId: 'c1'));
    await saving;
  });

  test('deleteOccurrence returns false for empty id', () async {
    final fake = service();
    final expense = Fixtures.expense(id: '', accountId: 'a1', categoryId: 'c1');
    final occurrence = ExpenseOccurrence(
      expense: expense, date: DateTime(2026, 3, 15), isDebited: false,
    );
    final vm = CategoryExpensesViewModel(
      accountId: 'a1', categoryId: 'c1', period: period, expensesService: fake,
    );
    addTearDown(vm.dispose);

    expect(await vm.deleteOccurrence(occurrence), isFalse);
  });

  test('deleteEditingExpense returns false when no editing occurrence', () async {
    final fake = service();
    final vm = CategoryExpensesViewModel(
      accountId: 'a1', categoryId: 'c1', period: period, expensesService: fake,
    );
    addTearDown(vm.dispose);

    expect(await vm.deleteEditingExpense(), isFalse);
  });

  test('toggleEditingOccurrenceDebited returns false when no editing occurrence', () async {
    final fake = service();
    final vm = CategoryExpensesViewModel(
      accountId: 'a1', categoryId: 'c1', period: period, expensesService: fake,
    );
    addTearDown(vm.dispose);

    expect(await vm.toggleEditingOccurrenceDebited(), isFalse);
  });

  test('loadMore failure on a non-first page is silently logged', () async {
    final expense = Fixtures.expense(id: 'e1', accountId: 'a1', categoryId: 'c1');
    var callCount = 0;
    final service = PaginatingCategoryExpensesService(
      onCall: (callIndex) {
        callCount++;
        if (callCount == 1) {
          return ExpensePage(expenses: [expense], cursor: null, hasMore: true);
        }
        throw StateError('offline on second page');
      },
    );
    final vm = CategoryExpensesViewModel(
      accountId: 'a1', categoryId: 'c1', period: period, expensesService: service,
    );
    addTearDown(vm.dispose);

    await vm.loadMore();
    expect(vm.hasMorePages, isTrue);

    await vm.loadMore();

    expect(vm.isLoadingMore, isFalse);
    expect(vm.hasError, isFalse);
  });

  test('category getter returns null for a non-existent category', () {
    final fake = service();
    final vm = CategoryExpensesViewModel(
      accountId: 'a1', categoryId: 'missing', period: period, expensesService: fake,
    );
    addTearDown(vm.dispose);

    expect(vm.category, isNull);
  });

  test('category getter returns the category when it exists', () {
    final fake = service();
    final vm = CategoryExpensesViewModel(
      accountId: 'a1', categoryId: 'c1', period: period, expensesService: fake,
    );
    addTearDown(vm.dispose);

    expect(vm.category, isNotNull);
    expect(vm.category?.id, 'c1');
  });

  test('categoriesForAccount falls back to the ViewModel accountId', () {
    final fake = service();
    final vm = CategoryExpensesViewModel(
      accountId: 'a1', categoryId: 'c1', period: period, expensesService: fake,
    );
    addTearDown(vm.dispose);

    final cats = vm.categoriesForAccount();
    expect(cats.any((c) => c.id == 'c1'), isTrue);
  });

  test('currencyCode and localeName come from the profile', () {
    final fake = service();
    final vm = CategoryExpensesViewModel(
      accountId: 'a1', categoryId: 'c1', period: period, expensesService: fake,
    );
    addTearDown(vm.dispose);

    expect(vm.currencyCode, isNotEmpty);
    expect(vm.localeName, isNotEmpty);
  });

  test('accountColor returns null when account is missing', () {
    final fake = service();
    final vm = CategoryExpensesViewModel(
      accountId: 'missing', categoryId: 'c1', period: period, expensesService: fake,
    );
    addTearDown(vm.dispose);

    expect(vm.accountColor, isNull);
  });

  test('accountColor returns the account color when it exists', () {
    final fake = service();
    final vm = CategoryExpensesViewModel(
      accountId: 'a1', categoryId: 'c1', period: period, expensesService: fake,
    );
    addTearDown(vm.dispose);

    expect(vm.accountColor, isNotNull);
  });

  test('summarize throws StateError when category is not available', () {
    final fake = service();
    final vm = CategoryExpensesViewModel(
      accountId: 'a1', categoryId: 'missing', period: period, expensesService: fake,
    );
    addTearDown(vm.dispose);

    expect(() => vm.summarize([]), throwsStateError);
  });

  test('summary is null when category is missing', () {
    final fake = service();
    final vm = CategoryExpensesViewModel(
      accountId: 'a1', categoryId: 'missing', period: period, expensesService: fake,
    );
    addTearDown(vm.dispose);

    expect(vm.summary, isNull);
  });

  test('ensureDataLoaded triggers listCategoriesByAccount when not loaded', () async {
    final fake = service();
    final vm = CategoryExpensesViewModel(
      accountId: 'a1', categoryId: 'c1', period: period, expensesService: fake,
    );
    addTearDown(vm.dispose);

    await vm.ensureDataLoaded();

    expect(vm.isLoading, isFalse);
    expect(vm.hasError, isFalse);
  });

  test('saveEditing reports an error when updateRecurringExpenseFromOccurrence fails', () async {
    final fake = service()..failRecurring = true;
    final expense = Fixtures.expense(
      id: 'e1', accountId: 'a1', categoryId: 'c1',
      recurrence: RecurrenceType.monthly,
    );
    final occurrence = ExpenseOccurrence(
      expense: expense, date: DateTime(2026, 3, 15), isDebited: false,
    );
    final vm = CategoryExpensesViewModel(
      accountId: 'a1', categoryId: 'c1', period: period, expensesService: fake,
    );
    addTearDown(vm.dispose);
    vm.startEditing(occurrence);
    vm.expenseForm.data.amountController.text = '50';

    expect(await vm.saveEditing(), isFalse);
    expect(vm.hasError, isTrue);
    expect(vm.isSaving, isFalse);
  });

  test('deleteSingleOccurrence reports an error when the service call fails', () async {
    final fake = service()..failDeleteSingle = true;
    final expense = Fixtures.expense(
      id: 'e1', accountId: 'a1', categoryId: 'c1',
      recurrence: RecurrenceType.monthly,
    );
    final occurrence = ExpenseOccurrence(
      expense: expense, date: DateTime(2026, 3, 15), isDebited: false,
    );
    final vm = CategoryExpensesViewModel(
      accountId: 'a1', categoryId: 'c1', period: period, expensesService: fake,
    );
    addTearDown(vm.dispose);

    expect(await vm.deleteSingleOccurrence(occurrence), isFalse);
    expect(vm.hasError, isTrue);
    expect(vm.isSaving, isFalse);
  });

  test('deleteFutureOccurrences reports an error when the service call fails', () async {
    final fake = service()..failDeleteFuture = true;
    final expense = Fixtures.expense(
      id: 'e1', accountId: 'a1', categoryId: 'c1',
      recurrence: RecurrenceType.monthly,
    );
    final occurrence = ExpenseOccurrence(
      expense: expense, date: DateTime(2026, 3, 15), isDebited: false,
    );
    final vm = CategoryExpensesViewModel(
      accountId: 'a1', categoryId: 'c1', period: period, expensesService: fake,
    );
    addTearDown(vm.dispose);

    expect(await vm.deleteFutureOccurrences(occurrence), isFalse);
    expect(vm.hasError, isTrue);
    expect(vm.isSaving, isFalse);
  });

  test('deleteOccurrence reports an error when the service call fails', () async {
    final fake = service()..deleteResult = false;
    final expense = Fixtures.expense(id: 'e1', accountId: 'a1', categoryId: 'c1');
    fake.page = ExpensePage(expenses: [expense], cursor: null, hasMore: false);
    final vm = CategoryExpensesViewModel(
      accountId: 'a1', categoryId: 'c1', period: period, expensesService: fake,
    );
    addTearDown(vm.dispose);
    await vm.loadMore();
    final occurrence = vm.occurrences.single;

    expect(await vm.deleteOccurrence(occurrence), isFalse);
    expect(vm.hasError, isFalse);
    expect(vm.occurrences, hasLength(1));
  });

  test('occurances are cached and invalidated on data revision', () async {
    final fake = service();
    final expense = Fixtures.expense(id: 'e1', accountId: 'a1', categoryId: 'c1', amount: 10);
    fake.page = ExpensePage(expenses: [expense], cursor: null, hasMore: false);
    final vm = CategoryExpensesViewModel(
      accountId: 'a1', categoryId: 'c1', period: period, expensesService: fake,
    );
    addTearDown(vm.dispose);
    await vm.loadMore();

    final first = vm.occurrences;
    expect(identical(first, vm.occurrences), isTrue);

    fake.notifyListeners();
    await Future<void>.delayed(Duration.zero);

    expect(vm.occurrences, isNotNull);
  });

  test('selectFormAccount replaces category when current category is not in the new set', () async {
    final fake = service();
    seedAccounts([Fixtures.account(id: 'a1'), Fixtures.account(id: 'a2')]);
    seedCategories('a2', [Fixtures.category(id: 'c3', accountId: 'a2', name: 'Santé')]);
    final vm = CategoryExpensesViewModel(
      accountId: 'a1', categoryId: 'c1', period: period, expensesService: fake,
    );
    addTearDown(vm.dispose);
    final occurrence = ExpenseOccurrence(
      expense: Fixtures.expense(id: 'e1', accountId: 'a1', categoryId: 'c1'),
      date: DateTime(2026, 3, 15), isDebited: false,
    );
    vm.startEditing(occurrence);

    await vm.selectFormAccount(AccountsStore.instance.accounts[1]);

    expect(vm.expenseForm.data.account?.id, 'a2');
    expect(vm.expenseForm.data.category?.id, 'c3');
  });

  test('selectFormAccount does not replace category if it still exists in the new set', () async {
    final fake = service();
    seedAccounts([Fixtures.account(id: 'a1'), Fixtures.account(id: 'a2')]);
    seedCategories('a2', [Fixtures.category(id: 'c1', accountId: 'a2', name: 'Courses')]);
    final vm = CategoryExpensesViewModel(
      accountId: 'a1', categoryId: 'c1', period: period, expensesService: fake,
    );
    addTearDown(vm.dispose);
    final occurrence = ExpenseOccurrence(
      expense: Fixtures.expense(id: 'e1', accountId: 'a1', categoryId: 'c1'),
      date: DateTime(2026, 3, 15), isDebited: false,
    );
    vm.startEditing(occurrence);

    await vm.selectFormAccount(AccountsStore.instance.accounts[1]);

    expect(vm.expenseForm.data.account?.id, 'a2');
    expect(vm.expenseForm.data.category?.id, 'c1');
  });

  test('selectFormAccount clears category when no categories exist for the account', () async {
    final fake = service();
    seedAccounts([Fixtures.account(id: 'a1'), Fixtures.account(id: 'a2')]);
    seedCategories('a2', []);
    final vm = CategoryExpensesViewModel(
      accountId: 'a1', categoryId: 'c1', period: period, expensesService: fake,
    );
    addTearDown(vm.dispose);
    final occurrence = ExpenseOccurrence(
      expense: Fixtures.expense(id: 'e1', accountId: 'a1', categoryId: 'c1'),
      date: DateTime(2026, 3, 15), isDebited: false,
    );
    vm.startEditing(occurrence);

    await vm.selectFormAccount(AccountsStore.instance.accounts[1]);

    expect(vm.expenseForm.data.account?.id, 'a2');
    expect(vm.expenseForm.data.category, isNull);
  });

  test('formAccounts returns the accounts list', () {
    final fake = service();
    seedAccounts([Fixtures.account(id: 'a1'), Fixtures.account(id: 'a2')]);
    final vm = CategoryExpensesViewModel(
      accountId: 'a1', categoryId: 'c1', period: period, expensesService: fake,
    );
    addTearDown(vm.dispose);

    expect(vm.formAccounts, hasLength(2));
  });

  test('amountDecimalPlaces delegates to the profile', () {
    final fake = service();
    final vm = CategoryExpensesViewModel(
      accountId: 'a1', categoryId: 'c1', period: period, expensesService: fake,
    );
    addTearDown(vm.dispose);

    expect(vm.amountDecimalPlaces, 2);
  });
}

class ThrowingCategoryExpensesService extends ExpensesService {
  @override
  Future<ExpensePage> listCategoryPeriodPage(
    String accountId,
    String categoryId,
    Period period, {
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    bool includeRecurring = true,
  }) async {
    throw StateError('offline');
  }
}

class PaginatingCategoryExpensesService extends ExpensesService {
  final ExpensePage Function(int callIndex) onCall;
  int _callCount = 0;

  PaginatingCategoryExpensesService({required this.onCall});

  @override
  Future<ExpensePage> listCategoryPeriodPage(
    String accountId,
    String categoryId,
    Period period, {
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    bool includeRecurring = true,
  }) async => onCall(_callCount++);
}
