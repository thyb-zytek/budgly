import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/expense/category_expense_summary.dart';
import 'package:budgly/src/models/expense/expense_editing_data.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/expense_occurrence.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/budget/account_budgets_service.dart';
import 'package:budgly/src/services/categories/categories_service.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:budgly/src/core/extensions/currency.dart';
import 'package:budgly/src/core/view_models/base_view_model.dart';
import 'package:flutter/material.dart';

class OverviewViewModel extends BaseViewModel {
  final AccountsService _accountsService;
  final CategoriesService _categoriesService;
  final ExpensesService _expensesService;
  final AccountBudgetsService _accountBudgetsService;
  final ProfileService _profileService;

  Account? _account;
  bool _isSaving = false;

  bool _showRevenueEditor = false;
  String? _lastRevenueEvaluationKey;

  Period _selectedPeriod = Period.current();
  List<ExpenseOccurrence>? _cachedPeriodOccurrences;
  String? _periodOccurrencesCacheKey;

  late final ExpenseEditingData editingData = ExpenseEditingData(
    nameController: TextEditingController(),
    amountController: TextEditingController(),
  );

  OverviewViewModel({
    AccountsService? accountsService,
    CategoriesService? categoriesService,
    ExpensesService? expensesService,
    AccountBudgetsService? accountBudgetsService,
    ProfileService? profileService,
  })  : _accountsService = accountsService ?? AccountsService.instance,
        _categoriesService = categoriesService ?? CategoriesService.instance,
        _expensesService = expensesService ?? ExpensesService.instance,
        _accountBudgetsService =
            accountBudgetsService ?? AccountBudgetsService.instance,
        _profileService = profileService ?? ProfileService.instance {
    _accountsService.changeNotifier.addListener(_onServiceChanged);
    _categoriesService.addListener(_onServiceChanged);
    _expensesService.addListener(_onServiceChanged);
    _accountBudgetsService.addListener(_onServiceChanged);
    _profileService.addListener(_onServiceChanged);
  }

  void _onServiceChanged() {
    _syncSelectedAccount();
    _invalidatePeriodOccurrencesCache();
    _maybeShowRevenueEditor();
    if (!isDisposed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!isDisposed) notifyListeners();
      });
    }
  }

  void _syncSelectedAccount() {
    final accounts = _accountsService.accounts;
    if (accounts.isEmpty) return;

    final currentId = _account?.id;
    Account? match;
    if (currentId != null) {
      for (final a in accounts) {
        if (a.id == currentId) {
          match = a;
          break;
        }
      }
    }

    if (match == null) {
      account = accounts.first;
    } else if (!identical(match, _account)) {

      _account = match;
      _invalidatePeriodOccurrencesCache();
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
    try {
      await _accountsService.loadAccounts();
    } finally {
      if (needLoading) setLoading(false);
      if (!isDisposed) notifyListeners();
    }
  }

  Future<void> refreshAll() async {
    final accountId = _account?.id;

    await _accountsService.loadAccounts(forceRefresh: true);

    if (accountId != null) {
      await Future.wait([
        _categoriesService.listCategoriesByAccount(accountId, forceRefresh: true),
        _expensesService.listExpensesByAccount(accountId, forceRefresh: true),
        _accountBudgetsService.loadRevenue(
          accountId,
          _selectedPeriod.year,
          _selectedPeriod.month,
          forceRefresh: true,
        ),
      ]);
      _inheritedRevenueByAccount.remove(accountId);
      await _ensureInheritedRevenueLoaded();
    }

    _invalidatePeriodOccurrencesCache();
    _lastRevenueEvaluationKey = null;
    if (!isDisposed) notifyListeners();
  }

  Account? get account => _account;

  set account(Account? value) {
    if (_account?.id == value?.id) return;
    _account = value;
    _invalidatePeriodOccurrencesCache();
    if (!isDisposed) notifyListeners();

    if (value?.id == null) return;

    if (!_categoriesService.hasLoadedAccount(value!.id!)) {
      _categoriesService.listCategoriesByAccount(value.id!);
    }
    if (!hasExpensesLoaded) {
      loadExpenses();
    }
    _ensureRevenueLoaded();
    _ensureInheritedRevenueLoaded();
    _maybeShowRevenueEditor();
  }

  Period get selectedPeriod => _selectedPeriod;
  Period get minPeriod => Period.current().addMonths(-12);
  Period get maxPeriod =>
      Period.fromDate(DateTime.now().add(const Duration(days: AppConstants.maxFutureExpenseDays)));

  set selectedPeriod(Period value) {
    if (_selectedPeriod == value) return;
    _selectedPeriod = value;
    _invalidatePeriodOccurrencesCache();
    if (!isDisposed) notifyListeners();
    _ensureRevenueLoaded();
    _ensureInheritedRevenueLoaded();
    _maybeShowRevenueEditor();
  }

  void _ensureRevenueLoaded() {
    if (_account?.id == null) return;
    if (!_accountBudgetsService.hasLoaded(_account!.id!, _selectedPeriod.year, _selectedPeriod.month)) {
      _accountBudgetsService.loadRevenue(_account!.id!, _selectedPeriod.year, _selectedPeriod.month);
    }
  }

  final Map<String, double?> _inheritedRevenueByAccount = {};

  Future<void> _ensureInheritedRevenueLoaded() async {
    final accountId = _account?.id;
    if (accountId == null) return;
    if (_inheritedRevenueByAccount.containsKey(accountId)) return;

    final value = await _accountBudgetsService.getMostRecentRevenue(accountId);
    if (isDisposed || _account?.id != accountId) return;
    _inheritedRevenueByAccount[accountId] = value;
    notifyListeners();
  }

  bool get showRevenueEditor => _showRevenueEditor;

  void openRevenueEditor() {
    _showRevenueEditor = true;
    if (!isDisposed) notifyListeners();
  }

  void closeRevenueEditor() {
    _showRevenueEditor = false;
    if (!isDisposed) notifyListeners();
  }

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

  bool get hasRevenue => revenue > 0;

  double? get inheritedRevenue => _inheritedRevenueByAccount[_account?.id];

  bool get isRevenueEstimated => !hasRevenue && (inheritedRevenue ?? 0) > 0;

  double get effectiveRevenue => hasRevenue ? revenue : (inheritedRevenue ?? 0);

  Future<void> setRevenue(double value) async {
    if (_account?.id == null) return;
    await _accountBudgetsService.setRevenue(_account!.id!, _selectedPeriod.year, _selectedPeriod.month, value);
    _inheritedRevenueByAccount.remove(_account!.id);
    _ensureInheritedRevenueLoaded();
  }

  List<Expense> get expenses {
    if (_account?.id == null) return [];
    return _expensesService.getExpensesForAccount(_account!.id!);
  }

  void _invalidatePeriodOccurrencesCache() {
    _cachedPeriodOccurrences = null;
    _periodOccurrencesCacheKey = null;
  }

  String get _currentPeriodCacheKey =>
      '${_account?.id}_${_selectedPeriod.year}_${_selectedPeriod.month}';

  List<ExpenseOccurrence> get periodOccurrences {
    if (_account?.id == null) return [];
    final key = _currentPeriodCacheKey;
    if (_cachedPeriodOccurrences != null && _periodOccurrencesCacheKey == key) {
      return _cachedPeriodOccurrences!;
    }
    final result = <ExpenseOccurrence>[];
    for (final expense in expenses) {
      result.addAll(expandExpenseOccurrences(expense, _selectedPeriod));
    }
    result.sort((a, b) {
      if (a.isDebited != b.isDebited) return a.isDebited ? 1 : -1;
      return a.date.compareTo(b.date);
    });
    _cachedPeriodOccurrences = result;
    _periodOccurrencesCacheKey = key;
    return result;
  }

  bool get hasExpensesLoaded =>
      _account?.id != null && _expensesService.hasLoadedAccount(_account!.id!);

  bool get isSaving => _isSaving;

  Future<void> loadExpenses({bool needLoading = true}) async {
    if (_account?.id == null) return;
    if (needLoading) setLoading(true);
    try {
      await _expensesService.listExpensesByAccount(_account!.id!);
      _invalidatePeriodOccurrencesCache();
    } finally {
      if (needLoading) setLoading(false);
      if (!isDisposed) notifyListeners();
    }
  }

  double get totalExpenses =>
      periodOccurrences.fold(0.0, (sum, occurrence) => sum + occurrence.amount);

  double get pendingExpenses => periodOccurrences
      .where((occurrence) => !occurrence.isDebited)
      .fold(0.0, (sum, occurrence) => sum + occurrence.amount);

  double get remaining => effectiveRevenue - totalExpenses;

  int? get remainingWeekendsInPeriod {
    if (_selectedPeriod.isBefore(Period.current())) return null;
    if (_selectedPeriod == Period.current()) return _selectedPeriod.remainingWeekends();
    return _selectedPeriod.totalWeekends();
  }

  double? get weeklyBudget {
    final weekends = remainingWeekendsInPeriod;
    if (weekends == null) return null;

    return remaining / (weekends > 0 ? weekends : 1);
  }

  List<CategoryExpenseSummary> get categorySummaries {
    final byCategory = <String, List<ExpenseOccurrence>>{};
    for (final occurrence in periodOccurrences) {
      byCategory.putIfAbsent(occurrence.categoryId, () => []).add(occurrence);
    }

    final summaries = <CategoryExpenseSummary>[];
    for (final entry in byCategory.entries) {
      final category = _categoriesService.getCategoryById(entry.key);
      if (category == null) continue;

      double debited = 0;
      double undebited = 0;
      int undebitedCount = 0;
      for (final occurrence in entry.value) {
        if (occurrence.isDebited) {
          debited += occurrence.amount;
        } else {
          undebited += occurrence.amount;
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

    if (!isDisposed) notifyListeners();
  }

  Future<void> selectFormAccount(Account formAccount) async {
    if (editingData.account?.id == formAccount.id) return;

    editingData.account = formAccount;
    editingData.category = null;
    if (!isDisposed) notifyListeners();

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
    if (!isDisposed) notifyListeners();
  }

  void setDebitDate(DateTime date) {
    editingData.debitDate = date;
    if (!isDisposed) notifyListeners();
  }

  void setRecurrence(RecurrenceType recurrence) {
    editingData.recurrence = recurrence;
    if (!isDisposed) notifyListeners();
  }

  void toggleAdvancedOptions() {
    editingData.showAdvancedOptions = !editingData.showAdvancedOptions;
    if (!isDisposed) notifyListeners();
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
    if (_isSaving) return false;
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
    _accountsService.changeNotifier.removeListener(_onServiceChanged);
    _categoriesService.removeListener(_onServiceChanged);
    _expensesService.removeListener(_onServiceChanged);
    _accountBudgetsService.removeListener(_onServiceChanged);
    _profileService.removeListener(_onServiceChanged);
    editingData.nameController.dispose();
    editingData.amountController.dispose();
    super.dispose();
  }
}
