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
  final DateTime Function() _now;

  static const Duration bannerRedisplayInterval = Duration(hours: 3);
  Timer? _redisplayTimer;

  String? _accountId;
  Period? _currentPeriod;
  List<ExpenseOccurrence> _occurrences = const [];
  DateTime? _dismissedAt;
  bool _initialized = false;
  bool _isDisposed = false;

  UndebitedExpensesService({
    ExpensesService? expensesService,
    LocalCache? localCache,
    ExpenseOccurrenceCalculator? calculator,
    DateTime Function()? now,
  })  : _expensesService = expensesService ?? ExpensesService.instance,
        _localCache = localCache ?? LocalCache(),
        _calculator = calculator ?? const ExpenseOccurrenceCalculator(),
        _now = now ?? DateTime.now {
    _expensesService.addListener(_onExpensesChanged);
  }

  List<ExpenseOccurrence> get occurrences => List.unmodifiable(_occurrences);
  int get count => _occurrences.length;
  Period? get previousPeriod => _currentPeriod?.previous;
  Period? get currentPeriod => _currentPeriod;

  bool get isDismissed => _dismissedAt != null;
  bool get isDisposed => _isDisposed;

  bool get shouldShow {
    if (!_initialized || count == 0) return false;
    final dismissedAt = _dismissedAt;
    return dismissedAt == null || _now().difference(dismissedAt) >= bannerRedisplayInterval;
  }

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
    _scheduleRedisplay();
    await _reloadOccurrences(forceRefresh: forceRefresh);
    // Pull-to-refresh is an explicit user re-sync: if expenses still await
    // reporting, re-arm the banner instead of letting a previous dismissal
    // keep it hidden for the whole redisplay interval.
    if (isDisposed) return;
    if (forceRefresh && _occurrences.isNotEmpty) {
      _dismissedAt = null;
      await _localCache.clearUndebitedBannerDismissedAt(accountId);
    }
    _scheduleRedisplay();
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
    // A forced refresh (app launch / pull-to-refresh) instead queries the
    // server so the banner reflects the authoritative account state.
    List<Expense> expenses = const [];
    try {
      expenses = await _expensesService.listExpensesForAccount(
        accountId,
        forceRefresh: forceRefresh,
      );
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
    _scheduleRedisplay();
    _notify();
  }

  void _scheduleRedisplay() {
    _redisplayTimer?.cancel();
    _redisplayTimer = null;

    final dismissedAt = _dismissedAt;
    if (!_initialized || count == 0 || dismissedAt == null) return;

    final elapsed = _now().difference(dismissedAt);
    final remaining = bannerRedisplayInterval - elapsed;
    if (remaining <= Duration.zero) return;

    _redisplayTimer = Timer(remaining, () {
      _redisplayTimer = null;
      if (!isDisposed && _initialized && _occurrences.isNotEmpty) {
        _notify();
      }
    });
  }

  Future<void> dismiss() async {
    final accountId = _accountId;
    final current = _currentPeriod;
    if (accountId == null) return;
    _dismissedAt = _now();
    await _localCache.saveUndebitedBannerDismissedAt(
      accountId,
      period: current ?? Period.current(),
      value: _dismissedAt!,
    );
    _scheduleRedisplay();
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

  Future<void> debitSelectedOnOriginalPeriod(
    Iterable<ExpenseOccurrence> selected,
  ) async {
    final snapshot = List<ExpenseOccurrence>.from(selected);
    final latest = <String, Expense>{};
    for (final occurrence in snapshot) {
      final expense = latest[occurrence.id] ??
          _expensesService.getExpenseById(occurrence.id) ??
          occurrence.expense;
      latest[occurrence.id] = await _expensesService.markOccurrenceDebited(
        expense, occurrence.sourceDate ?? occurrence.date,
      );
    }
    await _reloadAndNotify();
  }

  Future<void> carrySelectedToCurrentPeriod(
    Iterable<ExpenseOccurrence> selected,
  ) async {
    final current = _currentPeriod;
    if (current == null) return;
    final target = current.startOfMonth;
    final snapshot = List<ExpenseOccurrence>.from(selected);
    final latest = <String, Expense>{};
    for (final occurrence in snapshot) {
      final expense = latest[occurrence.id] ??
          _expensesService.getExpenseById(occurrence.id) ??
          occurrence.expense;
      latest[occurrence.id] = await _expensesService.moveOccurrenceToDate(
        expense, occurrence.sourceDate ?? occurrence.date, target,
        markDebited: false,
      );
    }
    await _reloadAndNotify();
  }

  Future<void> debitSelectedOnCurrentPeriod(
    Iterable<ExpenseOccurrence> selected,
  ) async {
    final current = _currentPeriod;
    if (current == null) return;
    final target = current.startOfMonth;
    final snapshot = List<ExpenseOccurrence>.from(selected);
    final latest = <String, Expense>{};
    for (final occurrence in snapshot) {
      final expense = latest[occurrence.id] ??
          _expensesService.getExpenseById(occurrence.id) ??
          occurrence.expense;
      latest[occurrence.id] = await _expensesService.moveOccurrenceToDate(
        expense, occurrence.sourceDate ?? occurrence.date, target,
        markDebited: true,
      );
    }
    await _reloadAndNotify();
  }

  // Kept for callers using the previous API: process every pending occurrence.
  Future<void> debitOnOriginalPeriod() =>
      debitSelectedOnOriginalPeriod(_occurrences);

  Future<void> carryToCurrentPeriod() =>
      carrySelectedToCurrentPeriod(_occurrences);

  Future<void> debitOnCurrentPeriod() =>
      debitSelectedOnCurrentPeriod(_occurrences);

  void _notify() {
    if (!hasListeners) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _redisplayTimer?.cancel();
    _redisplayTimer = null;
    _expensesService.removeListener(_onExpensesChanged);
    super.dispose();
  }
}
