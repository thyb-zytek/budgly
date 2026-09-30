import 'dart:async';

import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/budget/calendar_date_range.dart';
import 'package:budgly/src/models/expense/expense_occurrence.dart';
import 'package:budgly/src/services/calculators/expense_occurrence_calculator.dart';
import 'package:budgly/src/services/expenses/undebited_expenses_service.dart';
import 'package:budgly/src/services/expenses/expenses_service_provider.dart';
import 'package:budgly/src/services/offline/local_cache.dart';
import 'package:budgly/src/services/offline/local_cache_provider.dart';
import 'package:budgly/src/state/profile_providers.dart';
import 'package:budgly/src/state/accounts_provider.dart';
import 'package:budgly/src/state/expenses_provider.dart';
import 'package:budgly/src/state/action_status.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'undebited_expenses_provider.g.dart';

@immutable
class UndebitedExpensesState {
  const UndebitedExpensesState({
    this.accounts = const [],
    this.currencyCode = 'EUR',
    this.localeName = 'fr',
    this.amountDecimalPlaces = 2,
    required this.currentPeriod,
    this.selectedAccountId,
    this.selectionMode = false,
    this.processing = false,
    this.busyKey,
    this.dataLoaded = false,
    this.selected = const <String>{},
    this.removing = const <String>{},
    this.allOccurrences = const <ExpenseOccurrence>[],
    this.displayed = const <ExpenseOccurrence>[],
    this.status = const ActionStatus.idle(),
    this.bannerVisible = false,
  });

  final List<Account> accounts;
  final String currencyCode;
  final String localeName;
  final int amountDecimalPlaces;
  final Period? currentPeriod;
  final String? selectedAccountId;
  final bool selectionMode;
  final bool processing;
  final String? busyKey;
  final bool dataLoaded;
  final Set<String> selected;
  final Set<String> removing;
  final List<ExpenseOccurrence> allOccurrences;
  final List<ExpenseOccurrence> displayed;
  final ActionStatus status;
  final bool bannerVisible;

  bool get isEmpty => allOccurrences.isEmpty;
  int get selectedCount => selected.length;
  int get totalCount => displayed.length;
  double get totalAmount =>
      displayed.fold(0.0, (sum, occurrence) => sum + occurrence.amount);
  Period get effectiveCurrentPeriod =>
      currentPeriod ?? Period.fromDate(DateTime.now());
  bool isSelected(ExpenseOccurrence occurrence) =>
      selected.contains(occurrence.key);
  bool isRemoving(ExpenseOccurrence occurrence) =>
      removing.contains(occurrence.key);
  bool isBusy(ExpenseOccurrence occurrence) => busyKey == occurrence.key;
  List<({Period period, List<ExpenseOccurrence> occurrences})> get grouped {
    final groups = <Period, List<ExpenseOccurrence>>{};
    for (final occurrence in displayed) {
      groups
          .putIfAbsent(Period.fromDate(occurrence.date), () => [])
          .add(occurrence);
    }
    final periods = groups.keys.toList()
      ..sort((a, b) => a.startOfMonth.compareTo(b.startOfMonth));
    return [
      for (final period in periods)
        (period: period, occurrences: groups[period]!),
    ];
  }

  bool get isInteractive => !processing && busyKey == null;

  UndebitedExpensesState copyWith({
    List<Account>? accounts,
    String? currencyCode,
    String? localeName,
    int? amountDecimalPlaces,
    Period? currentPeriod,
    String? selectedAccountId,
    bool clearSelectedAccount = false,
    bool? selectionMode,
    bool? processing,
    Object? busyKey = _unset,
    bool? dataLoaded,
    Set<String>? selected,
    Set<String>? removing,
    List<ExpenseOccurrence>? allOccurrences,
    List<ExpenseOccurrence>? displayed,
    ActionStatus? status,
    bool? bannerVisible,
  }) => UndebitedExpensesState(
    accounts: accounts ?? this.accounts,
    currencyCode: currencyCode ?? this.currencyCode,
    localeName: localeName ?? this.localeName,
    amountDecimalPlaces: amountDecimalPlaces ?? this.amountDecimalPlaces,
    currentPeriod: currentPeriod ?? this.currentPeriod,
    selectedAccountId: clearSelectedAccount
        ? null
        : selectedAccountId ?? this.selectedAccountId,
    selectionMode: selectionMode ?? this.selectionMode,
    processing: processing ?? this.processing,
    busyKey: identical(busyKey, _unset) ? this.busyKey : busyKey as String?,
    dataLoaded: dataLoaded ?? this.dataLoaded,
    selected: selected ?? this.selected,
    removing: removing ?? this.removing,
    allOccurrences: allOccurrences ?? this.allOccurrences,
    displayed: displayed ?? this.displayed,
    status: status ?? this.status,
    bannerVisible: bannerVisible ?? this.bannerVisible,
  );
}

const _unset = Object();

@riverpod
class UndebitedExpenses extends _$UndebitedExpenses {
  static const removalDuration = Duration(milliseconds: 180);

  late final UndebitedExpensesService _service;
  late final ExpenseOccurrenceCalculator _calculator;
  late final LocalCache _localCache;
  var _disposed = false;
  Timer? _bannerTimer;

  @override
  UndebitedExpensesState build() {
    _localCache = ref.read(localCacheProvider);
    _service = UndebitedExpensesService(
      expensesService: ref.read(expensesServiceProvider),
      localCache: _localCache,
    );
    _calculator = const ExpenseOccurrenceCalculator();
    ref.onDispose(() {
      _disposed = true;
      _bannerTimer?.cancel();
    });

    ref.listen(expensesSessionProvider, (_, _) => _recompute());
    ref.listen(accountsSessionProvider, (_, _) => _recompute());
    ref.listen(profileSessionProvider, (_, _) => _recompute());

    final profile = ref.read(profileSessionProvider);
    return UndebitedExpensesState(
      accounts: ref
          .read(accountsSessionProvider)
          .accounts
          .where((a) => a.id != null)
          .toList(),
      currencyCode: profile.currency,
      localeName: profile.locale.languageCode,
      amountDecimalPlaces: profile.amountDecimalPlaces,
      currentPeriod: _service.currentPeriod ?? Period.fromDate(DateTime.now()),
    );
  }

  /// Checks if the banner should be visible for any account that has undebited expenses.
  /// Loads dismissal status from local cache for each relevant account.
  Future<bool> _shouldShowBanner(Period currentPeriod) async {
    final all = _computeAllUndebited();
    if (all.isEmpty) return false;

    // Group undebited occurrences by account
    final byAccount = <String, List<ExpenseOccurrence>>{};
    for (final occ in all) {
      byAccount.putIfAbsent(occ.expense.accountId, () => []).add(occ);
    }

    // Check each account: if it has undebited expenses and banner isn't dismissed (or redisplay interval passed)
    for (final entry in byAccount.entries) {
      final accountId = entry.key;
      final dismissed = await _localCache.loadUndebitedBannerDismissedAt(
        accountId,
      );
      if (dismissed == null) return true; // Never dismissed for this account
      if (dismissed.period != currentPeriod) {
        return true; // Dismissed for a different period
      }
      final elapsed = DateTime.now().difference(dismissed.at);
      if (elapsed >= UndebitedExpensesService.bannerRedisplayInterval) {
        return true; // Redisplay interval passed
      }
    }
    return false;
  }

  /// Loads undebited-expense data for every account, independently of the
  /// account currently selected in Overview. The selected-account filter is
  /// applied only to the dedicated Undebited Expenses UI.
  Future<void> ensureDataLoaded() async {
    if (state.dataLoaded) return;
    state = state.copyWith(dataLoaded: true, status: state.status.loading());
    try {
      final accounts = state.accounts
          .map((account) => account.id)
          .whereType<String>()
          .toList(growable: false);
      await Future.wait(
        accounts.map((accountId) async {
          await ref
              .read(expensesSessionProvider.notifier)
              .loadAccount(accountId);
          if (_disposed) return;
          await _service.refresh(
            accountId: accountId,
            current: Period.fromDate(DateTime.now()),
            showImmediately: true,
          );
        }),
      );
      if (_disposed) return;
      _recompute();
      // _recompute() now sets bannerVisible internally
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(status: state.status.failure(e));
    }
  }

  List<ExpenseOccurrence> _computeAllUndebited() {
    final rangeEnd = state.effectiveCurrentPeriod.previous.startOfNextMonth;
    final result = <ExpenseOccurrence>[];
    for (final account in state.accounts) {
      final accountId = account.id;
      if (accountId == null) continue;
      final expenses =
          ref.read(expensesSessionProvider).expensesByAccount[accountId] ??
          const [];
      if (expenses.isEmpty) continue;
      final from = expenses
          .map((expense) => expense.debitDate)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      if (!from.isBefore(rangeEnd)) continue;
      result.addAll(
        _calculator
            .between(
              expenses,
              CalendarDateRange(start: from, endExclusive: rangeEnd),
            )
            .where((occurrence) => !occurrence.isDebited),
      );
    }
    return result;
  }

  List<ExpenseOccurrence> _filter(List<ExpenseOccurrence> occurrences) {
    final accountId = state.selectedAccountId;
    if (accountId == null) return occurrences;
    return occurrences
        .where((occurrence) => occurrence.expense.accountId == accountId)
        .toList();
  }

  Future<void> _recompute() async {
    final profile = ref.read(profileSessionProvider);
    final all = _computeAllUndebited();
    final next = _filter(all);
    final nextKeys = next.map((occurrence) => occurrence.key).toSet();
    final removed = state.displayed
        .map((occurrence) => occurrence.key)
        .where((key) => !nextKeys.contains(key))
        .toSet();

    final accounts = ref
        .read(accountsSessionProvider)
        .accounts
        .where((a) => a.id != null)
        .toList();
    final currentPeriod =
        _service.currentPeriod ?? Period.fromDate(DateTime.now());
    final bannerVisible = await _shouldShowBanner(currentPeriod);
    if (removed.isEmpty) {
      state = state.copyWith(
        accounts: accounts,
        currencyCode: profile.currency,
        localeName: profile.locale.languageCode,
        amountDecimalPlaces: profile.amountDecimalPlaces,
        currentPeriod: currentPeriod,
        allOccurrences: all,
        displayed: next,
        bannerVisible: bannerVisible,
      );
    } else {
      final removedOccurrences = state.displayed.where(
        (occurrence) => removed.contains(occurrence.key),
      );
      state = state.copyWith(
        accounts: accounts,
        currencyCode: profile.currency,
        localeName: profile.locale.languageCode,
        amountDecimalPlaces: profile.amountDecimalPlaces,
        currentPeriod: currentPeriod,
        allOccurrences: all,
        displayed: [...next, ...removedOccurrences],
        removing: {...state.removing, ...removed},
        selected: state.selected.difference(removed),
        bannerVisible: bannerVisible,
      );
      Future<void>.delayed(removalDuration, () {
        if (_disposed) return;
        final remaining = _computeAllUndebited();
        state = state.copyWith(
          allOccurrences: remaining,
          displayed: _filter(remaining),
          removing: const <String>{},
        );
      });
    }
  }

  Future<void> refresh({bool forceRefresh = false}) async {
    final accounts = ref.read(accountsSessionProvider).accounts;
    for (final account in accounts) {
      final id = account.id;
      if (id == null) continue;
      await ref
          .read(expensesSessionProvider.notifier)
          .loadAccount(id, forceRefresh: forceRefresh);
      if (_disposed) return;
    }
    for (final account in accounts) {
      final id = account.id;
      if (id == null) continue;
      await _service.refresh(
        accountId: id,
        current: Period.fromDate(DateTime.now()),
        forceRefresh: forceRefresh,
      );
      if (_disposed) return;
    }
    _recompute();
    // _recompute() now sets bannerVisible internally
  }

  Future<void> dismiss() async {
    // Dismiss for all accounts that currently have undebited expenses
    final currentPeriod =
        _service.currentPeriod ?? Period.fromDate(DateTime.now());
    final all = _computeAllUndebited();
    final accountIds = all.map((occ) => occ.expense.accountId).toSet();
    for (final accountId in accountIds) {
      await _localCache.saveUndebitedBannerDismissedAt(
        accountId,
        period: currentPeriod,
        value: DateTime.now(),
      );
    }
    if (_disposed) return;
    _bannerTimer?.cancel();
    state = state.copyWith(bannerVisible: false);
    _bannerTimer = Timer(UndebitedExpensesService.bannerRedisplayInterval, () {
      if (_disposed) return;
      _recompute();
    });
  }

  void consumeMessage() =>
      state = state.copyWith(status: state.status.consumeMessage());

  void selectAccount(String? accountId) {
    if (state.selectedAccountId == accountId) return;
    final displayed = accountId == null
        ? state.allOccurrences
        : state.allOccurrences
              .where((occurrence) => occurrence.expense.accountId == accountId)
              .toList();
    state = state.copyWith(
      selectedAccountId: accountId,
      selected: const {},
      removing: const {},
      selectionMode: false,
      displayed: displayed,
    );
  }

  void enterSelection(ExpenseOccurrence occurrence) {
    if (!state.isInteractive) return;
    state = state.copyWith(
      selectionMode: true,
      selected: {...state.selected, occurrence.key},
    );
  }

  void toggleSelection(ExpenseOccurrence occurrence) {
    if (!state.selectionMode) return;
    final selected = {...state.selected};
    if (!selected.remove(occurrence.key)) selected.add(occurrence.key);
    state = state.copyWith(
      selected: selected,
      selectionMode: selected.isNotEmpty,
    );
  }

  void selectAll() {
    state = state.copyWith(
      selectionMode: true,
      selected: state.displayed.map((occurrence) => occurrence.key).toSet(),
    );
  }

  void clearSelection() =>
      state = state.copyWith(selected: const {}, selectionMode: false);

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
    if (!state.isInteractive) return;
    state = state.copyWith(busyKey: occurrence.key);
    try {
      await action();
      await _reloadAccounts({occurrence.expense.accountId});
      if (!_disposed) _recompute();
    } catch (e) {
      if (!_disposed) state = state.copyWith(status: state.status.failure(e));
    } finally {
      if (!_disposed) state = state.copyWith(busyKey: null);
    }
  }

  Future<void> _process(
    Future<void> Function(Iterable<ExpenseOccurrence>) action,
  ) async {
    if (state.processing || state.selected.isEmpty) return;
    final selected = state.displayed
        .where((occurrence) => state.selected.contains(occurrence.key))
        .toList();
    if (selected.isEmpty) return;
    state = state.copyWith(processing: true);
    try {
      await action(selected);
      await _reloadAccounts(
        selected.map((occurrence) => occurrence.expense.accountId),
      );
    } catch (e) {
      if (!_disposed) state = state.copyWith(status: state.status.failure(e));
    } finally {
      if (!_disposed) {
        state = state.copyWith(
          selected: const {},
          selectionMode: false,
          processing: false,
        );
        _recompute();
      }
    }
  }

  Future<void> _reloadAccounts(Iterable<String> accountIds) async {
    for (final accountId in accountIds.toSet()) {
      if (_disposed) return;
      await ref.read(expensesSessionProvider.notifier).loadAccount(accountId);
    }
  }
}
