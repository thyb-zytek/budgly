import 'package:budgly/src/core/view_models/base_view_model.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/expense_occurrence.dart';
import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/calculators/expense_occurrence_calculator.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/services/expenses/undebited_expenses_service.dart';
import 'package:budgly/src/services/profile/profile_service.dart';

/// Invoked when every undebited occurrence has been resolved between all
/// accounts. The view uses it to leave a dedicated report screen.
typedef OnUndebitedResolved = void Function();

class UndebitedExpensesViewModel extends BaseViewModel {
  static const removalDuration = Duration(milliseconds: 180);

  /// Fired when the aggregated undebited list becomes empty.
  final OnUndebitedResolved? onResolved;

  final UndebitedExpensesService _service;
  final ExpensesService _expensesService;
  final AccountsService _accountsService;
  final ProfileService _profileService;
  final ExpenseOccurrenceCalculator _calculator;
  final DateTime Function() _now;

  String? _selectedAccountId;
  bool _selectionMode = false;
  bool _processing = false;
  String? _busyKey;
  bool _dataLoaded = false;

  final Set<String> _selected = <String>{};
  final Set<String> _removing = <String>{};

  List<ExpenseOccurrence> _allOccurrences = const [];
  List<ExpenseOccurrence> _displayed = const [];

  UndebitedExpensesViewModel({
    UndebitedExpensesService? service,
    ExpensesService? expensesService,
    AccountsService? accountsService,
    ProfileService? profileService,
    ExpenseOccurrenceCalculator? calculator,
    DateTime Function()? now,
    this.onResolved,
  })  : _service = service ?? UndebitedExpensesService(),
        _expensesService = expensesService ?? ExpensesService.instance,
        _accountsService = accountsService ?? AccountsService.instance,
        _profileService = profileService ?? ProfileService.instance,
        _calculator = calculator ?? const ExpenseOccurrenceCalculator(),
        _now = now ?? DateTime.now {
    _expensesService.addListener(_onDataChanged);
    _accountsService.changeNotifier.addListener(_onDataChanged);
    _profileService.addListener(_onDataChanged);
  }

  // ---------------------------------------------------------------------
  // Data
  // ---------------------------------------------------------------------

  List<Account> get accounts =>
      _accountsService.accounts.where((account) => account.id != null).toList();

  String get currencyCode => _profileService.currency;
  String get localeName => _profileService.locale.languageCode;
  int get amountDecimalPlaces => _profileService.amountDecimalPlaces;

  Period get currentPeriod =>
      _service.currentPeriod ?? Period.fromDate(_now());

  /// Local-first: aggregate every stored expense across all accounts, project
  /// its occurrences and keep only the ones that were never debited before the
  /// current month. The store is backend-agnostic, so this never blocks on the
  /// network; the refreshed remote state lands through [ExpensesStore] cache.
  List<ExpenseOccurrence> _computeAllUndebited() {
    final to = currentPeriod.previous.endOfMonth;
    final result = <ExpenseOccurrence>[];
    for (final account in _accountsService.accounts) {
      final accountId = account.id;
      if (accountId == null) continue;
      final expenses = _expensesService.getExpensesForAccount(accountId);
      if (expenses.isEmpty) continue;
      final from = expenses
          .map((expense) => expense.debitDate)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      result.addAll(
        _calculator
            .between(expenses, from, to)
            .where((occurrence) => !occurrence.isDebited),
      );
    }
    return result;
  }

  List<ExpenseOccurrence> _filter(List<ExpenseOccurrence> occurrences) {
    final accountId = _selectedAccountId;
    if (accountId == null) return occurrences;
    return occurrences
        .where((occurrence) => occurrence.expense.accountId == accountId)
        .toList();
  }

  /// Loads every account's stored expenses so the aggregate reflects the whole
  /// account set, and pins the reporting period used by the mutation actions.
  /// Local-first: cache is rendered immediately, remote data arrives through
  /// the expenses store notifications.
  Future<void> ensureDataLoaded() async {
    if (_dataLoaded) return;
    _dataLoaded = true;
    for (final account in accounts) {
      await _service.refresh(
        accountId: account.id!,
        current: Period.fromDate(_now()),
        showImmediately: true,
      );
    }
    _recompute();
  }

  void _onDataChanged() {
    if (isDisposed) return;
    _recompute();
  }

  void _recompute() {
    _allOccurrences = _computeAllUndebited();
    _reconcileDisplayed();
    _maybeResolved();
    if (!isDisposed) notifyListeners();
  }

  void _reconcileDisplayed() {
    final next = _filter(_allOccurrences);
    final nextKeys = next.map((occurrence) => occurrence.key).toSet();
    final removed = _displayed
        .map((occurrence) => occurrence.key)
        .where((key) => !nextKeys.contains(key))
        .toSet();
    if (removed.isEmpty) {
      _displayed = next;
      return;
    }
    _removing.addAll(removed);
    _selected.removeAll(removed);
    // Keep the shrinking card on screen until its AnimatedSize collapses.
    Future<void>.delayed(removalDuration, () {
      if (isDisposed) return;
      _displayed = _filter(_allOccurrences);
      _removing.removeAll(removed);
      if (!isDisposed) notifyListeners();
    });
  }

  void _maybeResolved() {
    if (isDisposed || _processing) return;
    if (_allOccurrences.isNotEmpty) return;
    if (_accountsService.accounts.isEmpty) return;
    onResolved?.call();
  }

  // ---------------------------------------------------------------------
  // Display state
  // ---------------------------------------------------------------------

  String? get selectedAccountId => _selectedAccountId;
  List<ExpenseOccurrence> get occurrences => List.unmodifiable(_displayed);
  bool get isEmpty => _allOccurrences.isEmpty;
  bool get isSelectionMode => _selectionMode;
  bool get isProcessing => _processing;
  String? get busyKey => _busyKey;
  int get selectedCount => _selected.length;
  int get totalCount => _displayed.length;

  double get totalAmount =>
      _displayed.fold<double>(0, (sum, occurrence) => sum + occurrence.amount);

  double get selectedAmount => _displayed
      .where((occurrence) => _selected.contains(occurrence.key))
      .fold<double>(0, (sum, occurrence) => sum + occurrence.amount);

  bool isSelected(ExpenseOccurrence occurrence) =>
      _selected.contains(occurrence.key);
  bool isRemoving(ExpenseOccurrence occurrence) =>
      _removing.contains(occurrence.key);
  bool isBusy(ExpenseOccurrence occurrence) => _busyKey == occurrence.key;

  /// Cards stay interactive while no single-item or bulk mutation is running.
  bool get isInteractive => !_processing && _busyKey == null;

  void selectAccount(String? accountId) {
    if (_selectedAccountId == accountId) return;
    _selectedAccountId = accountId;
    _selected.clear();
    _removing.clear();
    _selectionMode = false;
    _displayed = _filter(_allOccurrences);
    if (!isDisposed) notifyListeners();
  }

  List<({Period period, List<ExpenseOccurrence> occurrences})> get grouped {
    final groups = <Period, List<ExpenseOccurrence>>{};
    for (final occurrence in _displayed) {
      groups.putIfAbsent(
        Period.fromDate(occurrence.date),
        () => [],
      ).add(occurrence);
    }
    final periods = groups.keys.toList()
      ..sort((a, b) => a.startOfMonth.compareTo(b.startOfMonth));
    return [
      for (final period in periods)
        (period: period, occurrences: groups[period]!),
    ];
  }

  // ---------------------------------------------------------------------
  // Selection
  // ---------------------------------------------------------------------

  void enterSelection(ExpenseOccurrence occurrence) {
    if (!isInteractive) return;
    _selectionMode = true;
    _selected.add(occurrence.key);
    if (!isDisposed) notifyListeners();
  }

  void toggleSelection(ExpenseOccurrence occurrence) {
    if (!_selectionMode) return;
    if (!_selected.remove(occurrence.key)) {
      _selected.add(occurrence.key);
    }
    if (_selected.isEmpty) _selectionMode = false;
    if (!isDisposed) notifyListeners();
  }

  void selectAll() {
    _selectionMode = true;
    _selected
      ..clear()
      ..addAll(_displayed.map((occurrence) => occurrence.key));
    if (!isDisposed) notifyListeners();
  }

  void clearSelection() {
    _selected.clear();
    _selectionMode = false;
    if (!isDisposed) notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------

  Future<void> carryToCurrentPeriod(ExpenseOccurrence occurrence) =>
      _processSingle(
        occurrence,
        () => _service.carrySelectedToCurrentPeriod([occurrence]),
      );

  Future<void> debitOnOriginalPeriod(ExpenseOccurrence occurrence) =>
      _processSingle(
        occurrence,
        () => _service.debitSelectedOnOriginalPeriod([occurrence]),
      );

  Future<void> debitOnCurrentPeriod(ExpenseOccurrence occurrence) =>
      _processSingle(
        occurrence,
        () => _service.debitSelectedOnCurrentPeriod([occurrence]),
      );

  Future<void> carrySelectedToCurrentPeriod() =>
      _process(_service.carrySelectedToCurrentPeriod);

  Future<void> debitSelectedOnOriginalPeriod() =>
      _process(_service.debitSelectedOnOriginalPeriod);

  Future<void> debitSelectedOnCurrentPeriod() =>
      _process(_service.debitSelectedOnCurrentPeriod);

  Future<void> _processSingle(
    ExpenseOccurrence occurrence,
    Future<void> Function() action,
  ) async {
    if (!isInteractive) return;
    _busyKey = occurrence.key;
    if (!isDisposed) notifyListeners();
    try {
      await action();
    } finally {
      if (!isDisposed) {
        _busyKey = null;
        notifyListeners();
      }
    }
  }

  Future<void> _process(
    Future<void> Function(Iterable<ExpenseOccurrence>) action,
  ) async {
    if (_processing || _selected.isEmpty) return;
    final selected =
        _displayed.where((occurrence) => _selected.contains(occurrence.key));
    if (selected.isEmpty) return;
    _processing = true;
    if (!isDisposed) notifyListeners();
    try {
      await action(selected);
    } finally {
      if (!isDisposed) {
        // Resolve only after the processing guard is lifted so a concurrent
        // recompute does not close the page while the mutation still runs.
        _selected.clear();
        _selectionMode = false;
        _processing = false;
        notifyListeners();
        _maybeResolved();
      }
    }
  }

  @override
  void dispose() {
    _expensesService.removeListener(_onDataChanged);
    _accountsService.changeNotifier.removeListener(_onDataChanged);
    _profileService.removeListener(_onDataChanged);
    _service.dispose();
    super.dispose();
  }
}