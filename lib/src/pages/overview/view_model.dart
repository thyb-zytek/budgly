import 'dart:async';

import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/core/errors/app_user_message.dart';
import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/expense/category_expense_summary.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/expense_occurrence.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/shared/domain/widgets/expenses/expense_form_controller.dart';
import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/budget/account_budgets_service.dart';
import 'package:budgly/src/services/categories/categories_service.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:budgly/src/core/extensions/amount.dart';
import 'package:budgly/src/core/view_models/base_view_model.dart';
import 'package:budgly/src/pages/overview/ui_state.dart';
import 'package:budgly/src/services/calculators/expense_summary_calculator.dart';
import 'package:budgly/src/services/calculators/expense_occurrence_calculator.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/pages/overview/overview_repository.dart';

class OverviewViewModel extends BaseViewModel {
  final AccountsService _accountsService;
  final CategoriesService _categoriesService;
  final ExpensesService _expensesService;
  final AccountBudgetsService _accountBudgetsService;
  final OverviewRepository _repository;
  final ProfileService _profileService;
  final ExpenseSummaryCalculator _summaryCalculator;
  final ExpenseOccurrenceCalculator _occurrenceCalculator;

  OverviewUiState _uiState = OverviewUiState(selectedPeriod: Period.current());

  String? _lastRevenueEvaluationKey;

  String? _derivedDataKey;
  List<ExpenseOccurrence>? _cachedOccurrences;
  List<CategoryExpenseSummary>? _cachedCategorySummaries;
  List<Expense> _expenses = const [];
  String? _expensesKey;
  String? _loadingExpensesKey;
  Future<void>? _expensesLoad;

  final ExpenseFormController expenseForm = ExpenseFormController();

  OverviewViewModel({
    AccountsService? accountsService,
    CategoriesService? categoriesService,
    ExpensesService? expensesService,
    AccountBudgetsService? accountBudgetsService,
    ProfileService? profileService,
    ExpenseSummaryCalculator? summaryCalculator,
    ExpenseOccurrenceCalculator? occurrenceCalculator,
    OverviewRepository? repository,
  }) : _accountsService = accountsService ?? AccountsService.instance,
       _categoriesService = categoriesService ?? CategoriesService.instance,
       _expensesService = expensesService ?? ExpensesService.instance,
       _accountBudgetsService =
           accountBudgetsService ?? AccountBudgetsService.instance,
       _repository = repository ??
           OverviewRepository(
             categoriesService: categoriesService,
             expensesService: expensesService,
             accountBudgetsService: accountBudgetsService,
           ),
       _profileService = profileService ?? ProfileService.instance,
       _summaryCalculator =
           summaryCalculator ?? const ExpenseSummaryCalculator(),
       _occurrenceCalculator =
           occurrenceCalculator ?? const ExpenseOccurrenceCalculator() {
    AnalyticsService.instance.track('screen_viewed', {'screen': 'overview'});
    expenseForm.addListener(_onFormChanged);
    _accountsService.changeNotifier.addListener(_onAccountsChanged);
    _categoriesService.addListener(_onCategoriesChanged);
    _expensesService.addListener(_onExpensesChanged);
    _accountBudgetsService.addListener(_onRevenueChanged);
    _profileService.addListener(_onProfileChanged);
  }

  void _onFormChanged() {
    _notifyAfterFrame();
  }

  void _onAccountsChanged() {
    _dataRevision++;
    _syncSelectedAccount();
    _notifyAfterFrame();
  }

  void _onCategoriesChanged() {
    _dataRevision++;
    _invalidateDerivedData();
    _notifyAfterFrame();
  }

  void _onExpensesChanged() {
    _dataRevision++;
    final accountId = _uiState.account?.id;
    final cachedExpenses = accountId == null
        ? null
        : _expensesService.cachedExpensesForPeriod(
            accountId,
            _uiState.selectedPeriod,
          );
    if (cachedExpenses != null) {
      _expenses = cachedExpenses;
      _expensesKey = _currentPeriodCacheKey;
      _invalidateDerivedData();
      _maybeShowRevenueEditor();
      _notifyAfterFrame();
    } else if (accountId != null) {
      // Optimistic fallback: derive period expenses from the local store
      // so a debitDate/period move is reflected instantly even before the
      // Firestore period cache is repopulated.
      final all = _expensesService.getExpensesForAccount(accountId);
      final period = _uiState.selectedPeriod;
      final start = period.startOfMonth;
      final end = period.endOfMonth;
      _expenses = all.where((expense) {
        if (!expense.isRecurring) {
          return !expense.debitDate.isBefore(start) &&
              !expense.debitDate.isAfter(end);
        }
        final endDate = expense.endOfEndDate;
        return !expense.debitDate.isAfter(end) &&
            (endDate == null || !endDate.isBefore(start));
      }).toList();
      _expensesKey = _currentPeriodCacheKey;
      _invalidateDerivedData();
      _maybeShowRevenueEditor();
      _notifyAfterFrame();
      unawaited(_loadSelectedPeriodExpenses(forceRefresh: true));
    } else {
      _expenses = const [];
      _expensesKey = null;
      _invalidateDerivedData();
      _maybeShowRevenueEditor();
      _notifyAfterFrame();
    }
  }

  void _onRevenueChanged() {
    _dataRevision++;
    _maybeShowRevenueEditor();
    _notifyAfterFrame();
  }

  void _onProfileChanged() {
    _dataRevision++;
    _notifyAfterFrame();
  }

  bool _notificationScheduled = false;

  void _notifyAfterFrame() {
    if (isDisposed || _notificationScheduled) return;
    _notificationScheduled = true;
    scheduleMicrotask(() {
      _notificationScheduled = false;
      if (!isDisposed) notifyListeners();
    });
  }

  int _dataRevision = 0;

  int get dataRevision => _dataRevision;
  OverviewUiState get uiState => _uiState;
  bool get isSaving => _uiState.isSaving;

  void _syncSelectedAccount() {
    final accounts = _accountsService.accounts;
    if (accounts.isEmpty) return;

    final currentId = _uiState.account?.id;
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
    } else if (!identical(match, _uiState.account)) {
      _uiState = _uiState.copyWith(account: match);
      _invalidateDerivedData();
    }

    final formAccountId = expenseForm.data.account?.id;
    if (formAccountId != null && !accounts.any((a) => a.id == formAccountId)) {
      expenseForm.data.account = null;
      expenseForm.data.category = null;
    }
  }

  List<Account> get accounts => _accountsService.accounts;
  bool get hasAccountsLoaded => _accountsService.hasLoaded;
  String get currencyCode => _profileService.currency;
  String get localeName => _profileService.locale.languageCode;

  Future<void> loadInitialData() async {
    setLoading(true);
    try {
      await _accountsService.loadAccounts();
      final accounts = _accountsService.accounts;
      if (accounts.isEmpty) return;

      final selectedAccount = accounts.first;
      _setSelectedAccount(selectedAccount, trackEvent: false);
      _ensureRevenueLoaded();
      unawaited(_ensureInheritedRevenueLoaded());

      // Once the account is known, period data can load independently. The
      // repository keeps this data-source orchestration out of the ViewModel.
      final loadedExpenses = await _repository.loadInitialData(
        selectedAccount,
        _uiState.selectedPeriod,
      );
      final accountId = selectedAccount.id!;
      _expenses = loadedExpenses;
      _expensesKey = _currentPeriodCacheKey;
      _invalidateDerivedData();
      unawaited(
        _repository.preloadOtherAccounts(
          accounts,
          accountId,
          _uiState.selectedPeriod,
        ),
      );
    } catch (e, stackTrace) {
      setError(e, stackTrace: stackTrace);
    } finally {
      setLoading(false);
    }
  }

  Future<void> refreshAll() async {
    AnalyticsService.instance.track('overview_refresh');
    try {
      await _accountsService.loadAccounts(forceRefresh: true);
      final accountId = _uiState.account?.id;

      if (accountId != null) {
        await _repository.refresh(_uiState.account!, _uiState.selectedPeriod);
        _inheritedRevenueByAccount
            .removeWhere((key, _) => key.startsWith('${accountId}_'));
        await _ensureInheritedRevenueLoaded();
      }

      _invalidateDerivedData();
      _lastRevenueEvaluationKey = null;
    } catch (e, stackTrace) {
      setError(e, stackTrace: stackTrace);
    }
  }

  Account? get account => _uiState.account;

  void _setSelectedAccount(Account account, {required bool trackEvent}) {
    if (_uiState.account?.id == account.id) return;

    _uiState = _uiState.copyWith(account: account, clearAccount: false);
    _expenses = const [];
    _expensesKey = null;
    _dataRevision++;
    _invalidateDerivedData();
    if (!isDisposed) notifyListeners();

    if (trackEvent) {
      AnalyticsService.instance.track('account_switched');
    }
  }

  set account(Account? value) {
    if (_uiState.account?.id == value?.id) return;

    if (value == null) {
      _uiState = _uiState.copyWith(clearAccount: true);
      _dataRevision++;
      _invalidateDerivedData();
      if (!isDisposed) notifyListeners();
      return;
    }

    _setSelectedAccount(value, trackEvent: true);
    unawaited(_loadSelectedPeriodExpenses());
    _ensureRevenueLoaded();
    unawaited(_ensureInheritedRevenueLoaded());
    _maybeShowRevenueEditor();
  }

  Period get selectedPeriod => _uiState.selectedPeriod;
  Period get minPeriod => Period.current().addMonths(-12);
  Period get maxPeriod => Period.fromDate(
    DateTime.now().add(const Duration(days: AppConstants.maxFutureExpenseDays)),
  );

  set selectedPeriod(Period value) {
    if (_uiState.selectedPeriod == value) return;
    _uiState = _uiState.copyWith(selectedPeriod: value);
    _dataRevision++;
    _invalidateDerivedData();
    if (!isDisposed) notifyListeners();
    AnalyticsService.instance.track('overview_period_changed');
    _ensureRevenueLoaded();
    _ensureInheritedRevenueLoaded();
    _loadSelectedPeriodExpenses();
    _maybeShowRevenueEditor();
  }

  void _ensureRevenueLoaded() {
    final accountId = _uiState.account?.id;
    if (accountId == null) return;
    final year = _uiState.selectedPeriod.year;
    final month = _uiState.selectedPeriod.month;
    if (_accountBudgetsService.hasLoaded(accountId, year, month)) return;

    unawaited(_loadRevenueInBackground(accountId, year, month));
  }

  Future<void> _loadRevenueInBackground(
    String accountId,
    int year,
    int month,
  ) async {
    await _repository.loadRevenueInBackground(accountId, year, month);
  }

  final Map<String, double?> _inheritedRevenueByAccount = {};

  String get _inheritedRevenueKey {
    final accountId = _uiState.account?.id;
    final period = _uiState.selectedPeriod;
    return '${accountId}_${period.year}_${period.month}';
  }

  Future<void> _ensureInheritedRevenueLoaded() async {
    final accountId = _uiState.account?.id;
    if (accountId == null) return;
    final key = _inheritedRevenueKey;
    if (_inheritedRevenueByAccount.containsKey(key)) return;

    try {
      final value = await _repository.getMostRecentRevenue(
        accountId,
        before: _uiState.selectedPeriod,
      );
      if (isDisposed ||
          accountId != _uiState.account?.id ||
          key != _inheritedRevenueKey) {
        return;
      }
      _inheritedRevenueByAccount[key] = value;
      _lastRevenueEvaluationKey = null;
      _maybeShowRevenueEditor();
      notifyListeners();
    } catch (e) {
      AppLogger.debug('Inherited revenue unavailable: $e');
    }
  }

  bool get showRevenueEditor => _uiState.showRevenueEditor;

  void openRevenueEditor() {
    _uiState = _uiState.copyWith(showRevenueEditor: true);
    AnalyticsService.instance.track('revenue_editor_opened');
    if (!isDisposed) notifyListeners();
  }

  void closeRevenueEditor() {
    _uiState = _uiState.copyWith(showRevenueEditor: false);
    AnalyticsService.instance.track('revenue_editor_closed');
    if (!isDisposed) notifyListeners();
  }

  void _maybeShowRevenueEditor() {
    final accountId = _uiState.account?.id;
    if (accountId == null) return;
    if (!isRevenueLoaded) return;
    // Do not prompt while the estimate is still loading: otherwise the editor
    // can briefly open and its evaluation is cached before the estimate wins.
    if (!_inheritedRevenueByAccount.containsKey(_inheritedRevenueKey)) return;

    final key =
        '${accountId}_${_uiState.selectedPeriod.year}_${_uiState.selectedPeriod.month}';
    if (_lastRevenueEvaluationKey == key) return;
    _lastRevenueEvaluationKey = key;

    final shouldShow = revenue <= 0 && (inheritedRevenue ?? 0) <= 0;
    if (_uiState.showRevenueEditor != shouldShow) {
      _uiState = _uiState.copyWith(showRevenueEditor: shouldShow);
      if (!isDisposed) notifyListeners();
    }
  }

  double get revenue {
    if (_uiState.account?.id == null) return 0;
    final value = _accountBudgetsService.getRevenue(
      _uiState.account!.id!,
      _uiState.selectedPeriod.year,
      _uiState.selectedPeriod.month,
    );
    return normalizeAmount(value, decimalPlaces: amountDecimalPlaces);
  }

  bool get isRevenueLoaded {
    if (_uiState.account?.id == null) return false;
    return _accountBudgetsService.hasLoaded(
      _uiState.account!.id!,
      _uiState.selectedPeriod.year,
      _uiState.selectedPeriod.month,
    );
  }

  int get amountDecimalPlaces => _profileService.amountDecimalPlaces;

  bool get hasRevenue => revenue > 0;

  double? get inheritedRevenue {
    final value = _inheritedRevenueByAccount[_inheritedRevenueKey];
    if (value == null) return null;
    return normalizeAmount(value, decimalPlaces: amountDecimalPlaces);
  }

  bool get isRevenueEstimated => !hasRevenue && (inheritedRevenue ?? 0) > 0;

  double get effectiveRevenue => hasRevenue ? revenue : (inheritedRevenue ?? 0);

  Future<void> setRevenue(double value) async {
    if (_uiState.account?.id == null) return;
    try {
      await _accountBudgetsService.setRevenue(
        _uiState.account!.id!,
        _uiState.selectedPeriod.year,
        _uiState.selectedPeriod.month,
        value,
      );
      _inheritedRevenueByAccount
          .removeWhere((key, _) => key.startsWith('${_uiState.account!.id}_'));
      _ensureInheritedRevenueLoaded();
      setSuccessMessage(
        const AppUserMessage.success(AppMessageKey.budgetSaved),
      );
    } catch (e, stackTrace) {
      setError(e, stackTrace: stackTrace);
    }
  }

  String get _currentPeriodCacheKey =>
      '${_uiState.account?.id}_${_uiState.selectedPeriod.year}_${_uiState.selectedPeriod.month}';

  List<Expense> get expenses {
    if (_uiState.account?.id == null ||
        _expensesKey != _currentPeriodCacheKey) {
      return const [];
    }
    return _expenses;
  }

  void _invalidateDerivedData() {
    _derivedDataKey = null;
    _cachedOccurrences = null;
    _cachedCategorySummaries = null;
  }

  List<ExpenseOccurrence> get periodOccurrences {
    if (_uiState.account?.id == null) return const [];
    final key = _currentPeriodCacheKey;
    if (_derivedDataKey == key && _cachedOccurrences != null) {
      return _cachedOccurrences!;
    }

    final result = _occurrenceCalculator.forPeriod(
      expenses,
      _uiState.selectedPeriod,
    );

    _derivedDataKey = key;
    _cachedOccurrences = result;
    _cachedCategorySummaries = null;
    return result;
  }

  bool get hasExpensesLoaded =>
      _uiState.account?.id != null && _expensesKey == _currentPeriodCacheKey;

  Future<void> _loadSelectedPeriodExpenses({bool forceRefresh = false}) async {
    final accountId = _uiState.account?.id;
    if (accountId == null) return;
    final key = _currentPeriodCacheKey;

    if (!forceRefresh && _expensesKey == key) return;
    if (_loadingExpensesKey == key && _expensesLoad != null) {
      await _expensesLoad;
      return;
    }

    _loadingExpensesKey = key;
    final future = _loadPeriodExpenses(
      accountId,
      key,
      forceRefresh: forceRefresh,
    );
    _expensesLoad = future;
    try {
      await future;
    } finally {
      if (identical(_expensesLoad, future)) {
        _expensesLoad = null;
        _loadingExpensesKey = null;
      }
    }
  }

  Future<void> _loadPeriodExpenses(
    String accountId,
    String key, {
    required bool forceRefresh,
  }) async {
    try {
      final expenses = await _repository.loadPeriodExpenses(
        accountId,
        _uiState.selectedPeriod,
        forceRefresh: forceRefresh,
      );
      if (isDisposed ||
          _uiState.account?.id != accountId ||
          _currentPeriodCacheKey != key) {
        return;
      }
      _expenses = expenses;
      _expensesKey = key;
      _dataRevision++;
      _invalidateDerivedData();
      AnalyticsService.instance.track('overview_expense_loaded');
      if (!isDisposed) notifyListeners();
    } catch (e) {
      AppLogger.debug('Background expense load unavailable: $e');
    }
  }

  double get totalExpenses =>
      periodOccurrences.fold(0.0, (sum, occurrence) => sum + occurrence.amount);

  double get pendingExpenses => periodOccurrences
      .where((occurrence) => !occurrence.isDebited)
      .fold(0.0, (sum, occurrence) => sum + occurrence.amount);

  double get remaining => effectiveRevenue - totalExpenses;

  int? get remainingWeekendsInPeriod {
    if (_uiState.selectedPeriod.isBefore(Period.current())) return null;
    if (_uiState.selectedPeriod == Period.current()) {
      return _uiState.selectedPeriod.remainingWeekends();
    }
    return _uiState.selectedPeriod.totalWeekends();
  }

  double? get weeklyBudget {
    final weekends = remainingWeekendsInPeriod;
    if (weekends == null) return null;

    return remaining / (weekends > 0 ? weekends : 1);
  }

  List<CategoryExpenseSummary> get categorySummaries {
    final key = _currentPeriodCacheKey;
    if (_derivedDataKey == key && _cachedCategorySummaries != null) {
      return _cachedCategorySummaries!;
    }

    final summaries = _summaryCalculator.summarizeByCategory(
      occurrences: periodOccurrences,
      resolveCategory: _categoriesService.getCategoryById,
    );
    _cachedCategorySummaries = summaries;
    return summaries;
  }

  List<Category> categoriesForSelectedAccount() {
    final accountId = expenseForm.data.account?.id;
    if (accountId == null) return [];
    return _categoriesService.getCategoriesForAccount(accountId);
  }

  void startNewExpense() {
    final account = _uiState.account;
    final accountId = account?.id;
    final categories = accountId == null
        ? const <Category>[]
        : _categoriesService.getCategoriesForAccount(accountId);
    expenseForm.resetForCreation(
      account: account,
      category: categories.isNotEmpty ? categories.first : null,
    );
    AnalyticsService.instance.track('expense_form_opened');
  }

  Future<void> selectFormAccount(Account formAccount) async {
    if (expenseForm.data.account?.id == formAccount.id) return;

    expenseForm.setAccount(formAccount);

    if (formAccount.id != null &&
        !_categoriesService.hasLoadedAccount(formAccount.id!)) {
      await _categoriesService.listCategoriesByAccount(formAccount.id!);
    }

    final categories = categoriesForSelectedAccount();
    if (categories.isNotEmpty) {
      expenseForm.setCategory(categories.first);
    }
  }

  void selectFormCategory(Category category) {
    expenseForm.setCategory(category);
  }

  void setDebitDate(DateTime date) => expenseForm.setDebitDate(date);

  void setEndDate(DateTime date) => expenseForm.setEndDate(date);

  void clearEndDate() => expenseForm.clearEndDate();

  void setRecurrence(RecurrenceType recurrence) =>
      expenseForm.setRecurrence(recurrence, preventPastStart: true);

  void toggleAdvancedOptions() => expenseForm.toggleAdvancedOptions();

  String? validate(AppLocalizations tr) =>
      expenseForm.validate(tr, requireAccountAndCategory: true);

  Future<bool> createExpense() async {
    if (_uiState.isSaving) return false;
    final formAccount = expenseForm.data.account;
    final category = expenseForm.data.category;
    if (formAccount?.id == null || category?.id == null) return false;

    final amount = expenseForm.parseEnteredAmount();
    if (amount == null) return false;

    _uiState = _uiState.copyWith(isSaving: true);
    notifyListeners();

    try {
      final expense = Expense(
        accountId: formAccount!.id!,
        categoryId: category!.id!,
        name: expenseForm.data.nameController.text.trim(),
        amount: amount,
        debitDate: expenseForm.data.debitDate,
        endDate: expenseForm.data.effectiveEndDate,
        recurrence: expenseForm.data.recurrence,
      );

      await _expensesService.createExpense(expense);
      setSuccessMessage(
        const AppUserMessage.success(AppMessageKey.expenseSaved),
      );
      return true;
    } catch (e, stackTrace) {
      setError(e, stackTrace: stackTrace);
      return false;
    } finally {
      _uiState = _uiState.copyWith(isSaving: false);
      if (!isDisposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _accountsService.changeNotifier.removeListener(_onAccountsChanged);
    _categoriesService.removeListener(_onCategoriesChanged);
    _expensesService.removeListener(_onExpensesChanged);
    _accountBudgetsService.removeListener(_onRevenueChanged);
    _profileService.removeListener(_onProfileChanged);
    expenseForm.removeListener(_onFormChanged);
    expenseForm.dispose();
    super.dispose();
  }
}
