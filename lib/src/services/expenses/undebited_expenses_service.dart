import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/expense_occurrence.dart';
import 'package:budgly/src/services/calculators/expense_occurrence_calculator.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/services/offline/local_cache.dart';

/// Coordinates detection and user decisions for expenses left undebited before
/// the real current month. It is deliberately presentation-agnostic so the
/// Overview only renders its state and delegates mutations here.
///
/// Important: [current] is the real current month used as the reporting target,
/// not the month currently selected by the Overview UI.
class UndebitedExpensesService extends ChangeNotifier {
  final ExpensesService _expensesService;
  final LocalCache _localCache;
  final ExpenseOccurrenceCalculator _calculator;

  String? _accountId;
  Period? _currentPeriod;
  List<ExpenseOccurrence> _occurrences = const [];
  DateTime? _dismissedAt;
  bool _initialized = false;

  UndebitedExpensesService({
    ExpensesService? expensesService,
    LocalCache? localCache,
    ExpenseOccurrenceCalculator? calculator,
  })  : _expensesService = expensesService ?? ExpensesService.instance,
        _localCache = localCache ?? LocalCache(),
        _calculator = calculator ?? const ExpenseOccurrenceCalculator() {
    _expensesService.addListener(_onExpensesChanged);
  }

  List<ExpenseOccurrence> get occurrences => List.unmodifiable(_occurrences);
  int get count => _occurrences.length;
  Period? get previousPeriod => _currentPeriod?.previous;
  Period? get currentPeriod => _currentPeriod;

  bool get isDismissed => _dismissedAt != null;

  bool get shouldShow =>
      _initialized && count > 0 && !isDismissed;

  Future<void> refresh({
    required String accountId,
    required Period current,
    bool showImmediately = false,
    bool forceRefresh = false,
  }) async {
    _accountId = accountId;
    _currentPeriod = current;
    _dismissedAt =
        showImmediately ? null : await _loadDismissal(accountId, current);
    _initialized = true;
    await _reloadOccurrences(forceRefresh: forceRefresh);
    _notify();
  }

  /// A dismissal only covers the real reporting month it was recorded in.
  /// Navigating through the Overview must not re-arm or hide the banner; it is
  /// re-armed only when the real calendar month changes.
  Future<DateTime?> _loadDismissal(String accountId, Period current) async {
    final dismissed = await _localCache.loadUndebitedBannerDismissedAt(accountId);
    if (dismissed == null) return null;
    if (dismissed.period != current) return null;
    return dismissed.at;
  }

  Future<void> _reloadOccurrences({bool forceRefresh = false}) async {
    final accountId = _accountId;
    final current = _currentPeriod;
    if (accountId == null || current == null) {
      _occurrences = const [];
      return;
    }

    final previous = current.previous;
    final to = previous.endOfMonth;

    // A cold start may only have loaded the Overview's selected period, which
    // can be in the past or future. Ensure the month immediately preceding the
    // real current period is available; older periods already present in the
    // store are also considered below.
    if (forceRefresh ||
        _expensesService.cachedExpensesForPeriod(accountId, previous) == null) {
      try {
        await _expensesService.listExpensesForPeriod(
          accountId,
          previous,
          forceRefresh: forceRefresh,
        );
      } catch (_) {
        // Firestore's local cache is the source of truth for offline mode. If it
        // cannot be loaded yet, the next service/store notification retries it.
      }
    }

    // Local-first: project every occurrence from the account's stored
    // expenses that falls before the current period, not only those of the
    // immediately previous month, so multi-month delays stay visible.
    List<Expense> expenses = const [];
    try {
      expenses = await _expensesService.listExpensesForAccount(accountId);
    } catch (_) {
      expenses = const [];
    }

    final from = expenses.isEmpty
        ? to
        : expenses
            .map((expense) => expense.debitDate)
            .reduce((a, b) => a.isBefore(b) ? a : b);
    _occurrences = _calculator
        .between(expenses, from, to)
        .where((occurrence) => !occurrence.isDebited)
        .toList();
  }

  void _onExpensesChanged() {
    if (!_initialized) return;
    unawaited(_reloadAndNotify());
  }

  Future<void> _reloadAndNotify() async {
    await _reloadOccurrences();
    _notify();
  }

  Future<void> dismiss() async {
    final accountId = _accountId;
    final current = _currentPeriod;
    if (accountId == null) return;
    _dismissedAt = DateTime.now();
    await _localCache.saveUndebitedBannerDismissedAt(
      accountId,
      period: current ?? Period.current(),
      value: _dismissedAt!,
    );
    _notify();
  }

  Future<void> carryOccurrenceToCurrentPeriod(ExpenseOccurrence occurrence) async {
    final current = _currentPeriod;
    if (current == null) return;
    await _expensesService.moveOccurrenceToDate(
      occurrence.expense,
      occurrence.sourceDate ?? occurrence.date,
      current.startOfMonth,
      markDebited: false,
    );
    await _reloadAndNotify();
  }

  Future<void> debitOccurrenceOnOriginalPeriod(ExpenseOccurrence occurrence) async {
    await _expensesService.markOccurrenceDebited(
      occurrence.expense,
      occurrence.sourceDate ?? occurrence.date,
    );
    await _reloadAndNotify();
  }

  Future<void> debitOccurrenceOnCurrentPeriod(ExpenseOccurrence occurrence) async {
    final current = _currentPeriod;
    if (current == null) return;
    await _expensesService.moveOccurrenceToDate(
      occurrence.expense,
      occurrence.sourceDate ?? occurrence.date,
      current.startOfMonth,
      markDebited: true,
    );
    await _reloadAndNotify();
  }

  Future<void> debitOnOriginalPeriod() async {
    final snapshot = List<ExpenseOccurrence>.from(_occurrences);
    for (final occurrence in snapshot) {
      await _expensesService.markOccurrenceDebited(
        occurrence.expense,
        occurrence.sourceDate ?? occurrence.date,
      );
    }
    await _reloadAndNotify();
  }

  Future<void> carryToCurrentPeriod() async {
    final current = _currentPeriod;
    if (current == null) return;
    final target = current.startOfMonth;
    final snapshot = List<ExpenseOccurrence>.from(_occurrences);
    for (final occurrence in snapshot) {
      await _expensesService.moveOccurrenceToDate(
        occurrence.expense,
        occurrence.sourceDate ?? occurrence.date,
        target,
        markDebited: false,
      );
    }
    await _reloadAndNotify();
  }

  Future<void> debitOnCurrentPeriod() async {
    final current = _currentPeriod;
    if (current == null) return;
    final target = current.startOfMonth;
    final snapshot = List<ExpenseOccurrence>.from(_occurrences);
    for (final occurrence in snapshot) {
      await _expensesService.moveOccurrenceToDate(
        occurrence.expense,
        occurrence.sourceDate ?? occurrence.date,
        target,
        markDebited: true,
      );
    }
    await _reloadAndNotify();
  }

  void _notify() {
    if (!hasListeners) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _expensesService.removeListener(_onExpensesChanged);
    super.dispose();
  }
}
