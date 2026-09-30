import 'dart:async';

import 'package:flutter/foundation.dart' hide Category;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/core/errors/app_user_message.dart';
import 'package:budgly/src/core/extensions/amount.dart';
import 'package:budgly/src/state/action_status.dart';
import 'package:budgly/src/state/expenses_provider.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/pages/overview/account_selection_provider.dart';
import 'package:budgly/src/pages/overview/period_expenses_provider.dart';
import 'package:budgly/src/pages/overview/revenue_provider.dart';
import 'package:budgly/src/pages/undebited_expenses/undebited_expenses_provider.dart';
import 'package:budgly/src/services/analytics/analytics_service_provider.dart';

part 'overview_provider.g.dart';

Period overviewMinPeriod() => Period.current().addMonths(-12);

Period overviewMaxPeriod() => Period.fromDate(
  DateTime.now().add(const Duration(days: AppConstants.maxFutureExpenseDays)),
);

@immutable
class OverviewState {
  const OverviewState({
    required this.selectedPeriod,
    required this.status,
    this.hasLoaded = false,
  });

  final Period selectedPeriod;
  final ActionStatus status;
  final bool hasLoaded;

  bool get isLoading => status.isLoading;

  OverviewState copyWith({
    Period? selectedPeriod,
    ActionStatus? status,
    bool? hasLoaded,
  }) => OverviewState(
    selectedPeriod: selectedPeriod ?? this.selectedPeriod,
    status: status ?? this.status,
    hasLoaded: hasLoaded ?? this.hasLoaded,
  );
}

@riverpod
class Overview extends _$Overview {
  @override
  OverviewState build() => OverviewState(
    selectedPeriod: Period.current(),
    status: const ActionStatus.idle(),
    hasLoaded: false,
  );

  Future<void> loadInitialData() async {
    if (state.status.isLoading) return;
    state = state.copyWith(status: state.status.loading());
    try {
      // ProfileSession preloads accounts and categories before the user can
      // reach Overview. Overview owns only screen/period data, so expenses
      // are loaded here when the page is actually entered.
      final account = ref.read(accountSelectionProvider).selectedAccount;
      if (account?.id != null) {
        final accountId = account!.id!;
        final period = state.selectedPeriod;
        await Future.wait([
          ref.read(periodExpensesProvider(accountId, period).notifier).load(),
          ref.read(revenueProvider(accountId, period).notifier).load(),
          ref.read(undebitedExpensesProvider.notifier).ensureDataLoaded(),
        ]);
      }
      if (!ref.mounted) return;
      ref.read(analyticsServiceProvider).track('screen_viewed', {
        'screen': 'overview',
      });
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(status: state.status.failure(e));
    } finally {
      state = state.copyWith(
        status: state.status.doneLoading(),
        hasLoaded: true,
      );
    }
  }

  Future<void> refreshAll() async {
    ref.read(analyticsServiceProvider).track('overview_refresh');
    final accountId = ref.read(accountSelectionProvider).selectedAccount?.id;
    if (accountId == null) return;
    state = state.copyWith(status: state.status.loading());
    try {
      await ref
          .read(accountSelectionProvider.notifier)
          .load(forceRefresh: true);
      if (!ref.mounted) return;
      final selectedId = ref.read(accountSelectionProvider).selectedAccount?.id;
      if (selectedId == null) return;
      await Future.wait([
        ref
            .read(
              periodExpensesProvider(selectedId, state.selectedPeriod).notifier,
            )
            .refresh(),
        ref
            .read(revenueProvider(selectedId, state.selectedPeriod).notifier)
            .load(forceRefresh: true),
        ref
            .read(undebitedExpensesProvider.notifier)
            .refresh(forceRefresh: true),
      ]);
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(status: state.status.failure(e));
    } finally {
      state = state.copyWith(
        status: state.status.doneLoading(),
        hasLoaded: true,
      );
    }
  }

  void selectPeriod(Period period) {
    if (period == state.selectedPeriod) return;
    state = state.copyWith(selectedPeriod: period);
    ref.read(analyticsServiceProvider).track('overview_period_changed');
    final accountId = ref.read(accountSelectionProvider).selectedAccount?.id;
    if (accountId == null) return;
    unawaited(
      ref.read(periodExpensesProvider(accountId, period).notifier).load(),
    );
    unawaited(ref.read(revenueProvider(accountId, period).notifier).load());
  }

  /// Changes the UI-selected account and reloads all account-scoped Overview
  /// data for that account. Undebited expenses deliberately stay global: their
  /// provider loads and computes occurrences across every account.
  void selectAccount(Account? account) {
    final previousId = ref.read(accountSelectionProvider).selectedAccount?.id;
    ref.read(accountSelectionProvider.notifier).select(account);
    final accountId = account?.id;
    if (accountId == null || accountId == previousId) return;

    unawaited(
      Future.wait([
        ref
            .read(
              periodExpensesProvider(accountId, state.selectedPeriod).notifier,
            )
            .load(),
        ref
            .read(revenueProvider(accountId, state.selectedPeriod).notifier)
            .load(),
      ]),
    );
  }

  Future<bool> createExpense({required ExpenseFormData form}) async {
    if (state.status.isLoading) return false;
    final account = form.account;
    final category = form.category;
    if (account?.id == null || category?.id == null) return false;
    final amount = parseAmount(form.amount);
    if (amount == null) return false;
    state = state.copyWith(status: state.status.loading());
    try {
      final expense = Expense(
        accountId: account!.id!,
        categoryId: category!.id!,
        name: form.name.trim(),
        amount: amount,
        debitDate: form.debitDate,
        endDate: form.endDate,
        recurrence: form.recurrence,
      );
      await ref.read(expensesSessionProvider.notifier).create(expense);
      state = state.copyWith(
        status: state.status.success(
          const AppUserMessage.success(AppMessageKey.expenseSaved),
        ),
      );
      return true;
    } catch (e) {
      state = state.copyWith(status: state.status.failure(e));
      return false;
    } finally {
      state = state.copyWith(status: state.status.doneLoading());
    }
  }

  void consumeMessage() =>
      state = state.copyWith(status: state.status.consumeMessage());
}

@immutable
class ExpenseFormData {
  const ExpenseFormData({
    required this.name,
    required this.amount,
    required this.account,
    required this.category,
    required this.debitDate,
    required this.endDate,
    required this.recurrence,
  });

  final String name;
  final String amount;
  final Account? account;
  final Category? category;
  final DateTime debitDate;
  final DateTime? endDate;
  final RecurrenceType recurrence;
}
