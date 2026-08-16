import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/expense/category_expense_summary.dart';
import 'package:budgly/src/models/expense/expense_editing_data.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/services/accounts.dart';
import 'package:budgly/src/services/accounts_budget.dart';
import 'package:budgly/src/services/categories.dart';
import 'package:budgly/src/services/expenses.dart';
import 'package:budgly/src/services/profile.dart';
import 'package:budgly/src/core/extensions/currency.dart';
import 'package:budgly/src/core/view_models/base_view_model.dart';
import 'package:budgly/src/stores/accounts.dart';
import 'package:flutter/material.dart';

class OverviewViewModel extends BaseViewModel {
  final AccountsService _accountsService = AccountsService.instance;
  final CategoriesService _categoriesService = CategoriesService.instance;
  final ExpensesService _expensesService = ExpensesService.instance;
  final AccountBudgetsService _accountBudgetsService = AccountBudgetsService.instance;
  final ProfileService _profileService = ProfileService.instance;

  final AccountsStore _accountsStore = AccountsStore.instance;

  Account? _account;
  bool _isSaving = false;

  // Banner de revenu : visible tant que le revenu du compte + période
  // sélectionnés n'est pas configuré. Évaluée à chaque changement de
  // période ou de compte, une seule fois par couple (compte, période).
  bool _showRevenueEditor = false;
  String? _lastRevenueEvaluationKey;

  // Par défaut, la période correspond au mois courant.
  Period _selectedPeriod = Period.current();

  late final ExpenseEditingData editingData = ExpenseEditingData(
    nameController: TextEditingController(),
    amountController: TextEditingController(),
  );

  OverviewViewModel() {
    _accountsStore.addListener(_onServiceChanged);
    _categoriesService.addListener(_onServiceChanged);
    _expensesService.addListener(_onServiceChanged);
    _accountBudgetsService.addListener(_onServiceChanged);
    _profileService.addListener(_onServiceChanged);
  }

  void _onServiceChanged() {
    _syncSelectedAccount();
    _maybeShowRevenueEditor();
    if (!isDisposed) notifyListeners();
  }

  void _syncSelectedAccount() {
    final accounts = _accountsService.accounts;
    if (accounts.isEmpty) return;

    final currentId = _account?.id;
    final stillExists = currentId != null && accounts.any((a) => a.id == currentId);
    if (!stillExists) {
      account = accounts.first;
    }

    final formAccountId = editingData.account?.id;
    if (formAccountId != null && !accounts.any((a) => a.id == formAccountId)) {
      editingData.account = null;
      editingData.category = null;
    }
  }

  List<Account> get accounts => _accountsService.accounts;
  bool get hasAccountsLoaded => _accountsService.hasLoaded;
  String get currencyCode => _profileService.currency;
  String get localeName => _profileService.locale.languageCode;

  Future<void> loadAccounts({bool needLoading = true}) async {
    if (hasAccountsLoaded) return;
    if (needLoading) setLoading(true);
    await _accountsService.loadAccounts();
    setLoading(false);
    if (!isDisposed) notifyListeners();
  }

  Account? get account => _account;

  // Gère correctement le changement de compte pour rafraîchir les
  // données dépendantes (catégories, dépenses, revenu).
  set account(Account? value) {
    if (_account?.id == value?.id) return;
    _account = value;
    notifyListeners();

    if (value?.id == null) return;

    if (!_categoriesService.hasLoadedAccount(value!.id!)) {
      _categoriesService.listCategoriesByAccount(value.id!);
    }
    if (!hasExpensesLoaded) {
      loadExpenses();
    }
    _ensureRevenueLoaded();
    _maybeShowRevenueEditor();
  }

  // --- Période ---

  Period get selectedPeriod => _selectedPeriod;
  Period get minPeriod => Period.current().addMonths(-12);
  Period get maxPeriod => Period.current().addMonths(3);

  set selectedPeriod(Period value) {
    if (_selectedPeriod == value) return;
    _selectedPeriod = value;
    notifyListeners();
    _ensureRevenueLoaded();
    _maybeShowRevenueEditor();
  }

  void _ensureRevenueLoaded() {
    if (_account?.id == null) return;
    if (!_accountBudgetsService.hasLoaded(_account!.id!, _selectedPeriod.year, _selectedPeriod.month)) {
      _accountBudgetsService.loadRevenue(_account!.id!, _selectedPeriod.year, _selectedPeriod.month);
    }
  }

  // --- Banner de revenu ---

  bool get showRevenueEditor => _showRevenueEditor;

  void openRevenueEditor() {
    _showRevenueEditor = true;
    if (!isDisposed) notifyListeners();
  }

  void closeRevenueEditor() {
    _showRevenueEditor = false;
    if (!isDisposed) notifyListeners();
  }

  /// Affiche la banner tant que le revenu du compte + période
  /// sélectionnés n'est pas configuré. Attend le chargement asynchrone
  /// du revenu (via _onServiceChanged) et ne se rejoue qu'une fois par
  /// couple (compte, période).
  void _maybeShowRevenueEditor() {
    final accountId = _account?.id;
    if (accountId == null) return;
    if (!isRevenueLoaded) return;

    final key = '${accountId}_${_selectedPeriod.year}_${_selectedPeriod.month}';
    if (_lastRevenueEvaluationKey == key) return;
    _lastRevenueEvaluationKey = key;

    final shouldShow = revenue <= 0;
    if (_showRevenueEditor != shouldShow) {
      _showRevenueEditor = shouldShow;
      if (!isDisposed) notifyListeners();
    }
  }

  // --- Revenu (AccountBudget) ---

  String formatRevenue(double value) {
    return formatCurrency(
      amount: value,
      currencyCode: currencyCode,
      localeName: localeName,
    );
  }

  double get revenue {
    if (_account?.id == null) return 0;
    return _accountBudgetsService.getRevenue(_account!.id!, _selectedPeriod.year, _selectedPeriod.month);
  }

  bool get isRevenueLoaded {
    if (_account?.id == null) return false;
    return _accountBudgetsService.hasLoaded(_account!.id!, _selectedPeriod.year, _selectedPeriod.month);
  }

  Future<void> setRevenue(double value) async {
    if (_account?.id == null) return;
    await _accountBudgetsService.setRevenue(_account!.id!, _selectedPeriod.year, _selectedPeriod.month, value);
  }

  List<Expense> get expenses {
    if (_account?.id == null) return [];
    return _expensesService.getExpensesForAccount(_account!.id!);
  }

  List<Expense> get periodExpenses =>
      expenses.where((e) => _selectedPeriod.contains(e.debitDate)).toList();

  bool get hasExpensesLoaded =>
      _account?.id != null && _expensesService.hasLoadedAccount(_account!.id!);

  bool get isSaving => _isSaving;

  Future<void> loadExpenses({bool needLoading = true}) async {
    if (_account?.id == null) return;
    if (needLoading) setLoading(true);
    await _expensesService.listExpensesByAccount(_account!.id!);
    setLoading(false);
    if (!isDisposed) notifyListeners();
  }

  double get totalExpenses => periodExpenses.fold(0.0, (sum, e) => sum + e.amount);
  double get remaining => revenue - totalExpenses;

  // --- Budget par week-end ---

  /// Nombre de week-ends restants dans la période, uniquement pertinent
  /// pour le mois EN COURS → null sinon.
  int? get remainingWeekendsInPeriod {
    if (_selectedPeriod != Period.current()) return null;
    return _selectedPeriod.remainingWeekends();
  }

  /// Montant "à dépenser par week-end" pour tenir le reste du mois :
  /// reste / nombre de week-ends restants. Null si non applicable
  /// (période différente du mois en cours).
  double? get weeklyBudget {
    final weekends = remainingWeekendsInPeriod;
    if (weekends == null) return null;

    // On divise par 1 au minimum pour éviter la division par zéro s'il
    // ne reste aucun week-end.
    return remaining / (weekends > 0 ? weekends : 1);
  }

  List<CategoryExpenseSummary> get categorySummaries {
    final byCategory = <String, List<Expense>>{};
    for (final expense in periodExpenses) {
      byCategory.putIfAbsent(expense.categoryId, () => []).add(expense);
    }

    final summaries = <CategoryExpenseSummary>[];
    for (final entry in byCategory.entries) {
      final category = _categoriesService.getCategoryById(entry.key);
      if (category == null) continue;

      double debited = 0;
      double undebited = 0;
      int undebitedCount = 0;
      for (final expense in entry.value) {
        if (expense.isDebited == true) {
          debited += expense.amount;
        } else {
          undebited += expense.amount;
          undebitedCount++;
        }
      }

      summaries.add(CategoryExpenseSummary(
        category: category,
        total: debited + undebited,
        debited: debited,
        undebited: undebited,
        undebitedCount: undebitedCount,
      ));
    }

    summaries.sort((a, b) => b.total.compareTo(a.total));
    return summaries;
  }

  List<Category> categoriesForSelectedAccount() {
    final accountId = editingData.account?.id;
    if (accountId == null) return [];
    return _categoriesService.getCategoriesForAccount(accountId);
  }

  void startNewExpense() {
    editingData.nameController.clear();
    editingData.amountController.clear();
    editingData.account = _account;
    editingData.debitDate = DateTime.now();
    editingData.recurrence = RecurrenceType.none;
    editingData.showAdvancedOptions = false;

    final categories = categoriesForSelectedAccount();
    editingData.category = categories.isNotEmpty ? categories.first : null;

    notifyListeners();
  }

  Future<void> selectFormAccount(Account formAccount) async {
    if (editingData.account?.id == formAccount.id) return;

    editingData.account = formAccount;
    editingData.category = null;
    notifyListeners();

    if (formAccount.id != null &&
        !_categoriesService.hasLoadedAccount(formAccount.id!)) {
      await _categoriesService.listCategoriesByAccount(formAccount.id!);
    }

    final categories = categoriesForSelectedAccount();
    if (categories.isNotEmpty) {
      editingData.category = categories.first;
      if (!isDisposed) notifyListeners();
    }
  }

  void selectFormCategory(Category category) {
    editingData.category = category;
    notifyListeners();
  }

  void setDebitDate(DateTime date) {
    editingData.debitDate = date;
    notifyListeners();
  }

  void setRecurrence(RecurrenceType recurrence) {
    editingData.recurrence = recurrence;
    notifyListeners();
  }

  void toggleAdvancedOptions() {
    editingData.showAdvancedOptions = !editingData.showAdvancedOptions;
    notifyListeners();
  }

  String? validate(AppLocalizations tr) {
    if (editingData.account == null) return tr.accountRequired;
    if (editingData.category == null) return tr.categoryRequired;
    if (editingData.nameController.text.trim().isEmpty) return tr.nameRequired;

    final amount = double.tryParse(
      editingData.amountController.text.replaceAll(',', '.'),
    );
    if (amount == null || amount <= 0) return tr.amountInvalid;

    return null;
  }

  Future<bool> createExpense() async {
    final formAccount = editingData.account;
    final category = editingData.category;
    if (formAccount?.id == null || category?.id == null) return false;

    final amount = double.tryParse(
      editingData.amountController.text.replaceAll(',', '.'),
    );
    if (amount == null || amount <= 0) return false;

    _isSaving = true;
    notifyListeners();

    try {
      final expense = Expense(
        accountId: formAccount!.id!,
        categoryId: category!.id!,
        name: editingData.nameController.text.trim(),
        amount: amount,
        debitDate: editingData.debitDate,
        recurrence: editingData.recurrence,
      );

      await _expensesService.createExpense(expense);
      return true;
    } finally {
      _isSaving = false;
      if (!isDisposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _accountsStore.removeListener(_onServiceChanged);
    _categoriesService.removeListener(_onServiceChanged);
    _expensesService.removeListener(_onServiceChanged);
    _accountBudgetsService.removeListener(_onServiceChanged);
    editingData.nameController.dispose();
    editingData.amountController.dispose();
    super.dispose();
  }
}