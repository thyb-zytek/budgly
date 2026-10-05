import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/navigation/navigation_helper.dart';
import 'package:budgly/src/core/theme/bottom_sheet.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/state/categories_provider.dart';
import 'package:budgly/src/state/profile_providers.dart';
import 'package:budgly/src/pages/overview/account_selection_provider.dart';
import 'package:budgly/src/pages/overview/overview_provider.dart';
import 'package:budgly/src/pages/overview/widgets/overview_content.dart';
import 'package:budgly/src/shared/domain/widgets/accounts/selector.dart';
import 'package:budgly/src/shared/domain/widgets/categories/selector.dart';
import 'package:budgly/src/shared/domain/widgets/expenses/expense_editor_sheet.dart';
import 'package:budgly/src/shared/domain/widgets/expenses/expense_form_controller.dart';
import 'package:budgly/src/shared/domain/widgets/expenses/undebited_expenses_banner.dart';
import 'package:budgly/src/shared/ui/widgets/feedback/riverpod_feedback.dart';
import 'package:budgly/src/shared/ui/widgets/layout/budgly_fab.dart';
import 'package:budgly/src/shared/ui/widgets/layout/fab_label_auto_hide_mixin.dart';
import 'package:budgly/src/shared/ui/widgets/layout/framed_container.dart';
import 'package:budgly/src/shared/ui/widgets/layout/loading_indicator.dart';
import 'package:budgly/src/shared/ui/widgets/layout/section_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class OverviewPage extends ConsumerStatefulWidget {
  const OverviewPage({super.key});

  @override
  ConsumerState<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends ConsumerState<OverviewPage>
    with FabLabelAutoHideMixin {
  final ValueNotifier<int> _slideDirection = ValueNotifier(1);
  late final ExpenseFormController _expenseForm;

  @override
  void initState() {
    super.initState();
    _expenseForm = ExpenseFormController();
    Future.microtask(
      () => ref.read(overviewProvider.notifier).loadInitialData(),
    );
    startFabLabelAutoHide();
  }

  @override
  void dispose() {
    disposeFabLabelAutoHide();
    _slideDirection.dispose();
    _expenseForm.dispose();
    super.dispose();
  }

  void _openAddExpenseModal() {
    final tr = AppLocalizations.of(context)!;
    final overview = ref.read(overviewProvider.notifier);
    final accounts = ref.read(accountSelectionProvider);
    final profile = ref.read(profileSessionProvider);
    dismissFabLabel();
    final account = accounts.selectedAccount;
    final categories =
        ref.read(categoriesSessionProvider).categoriesByAccount[account?.id] ??
        const [];
    _expenseForm.resetForCreation(
      account: account,
      category: categories.isNotEmpty ? categories.first : null,
    );

    showAppBottomSheet(
      context,
      builder: (context) => ExpenseEditorSheet(
        listenable: _expenseForm,
        editingData: _expenseForm.data,
        title: tr.newExpense,
        currencyCode: profile.currency,
        localeName: profile.locale.languageCode,
        validate: (tr) =>
            _expenseForm.validate(tr, requireAccountAndCategory: true),
        onSubmit: () => overview.createExpense(
          form: ExpenseCreationFormData(
            name: _expenseForm.data.nameController.text,
            amount: _expenseForm.data.amountController.text,
            account: _expenseForm.data.account,
            category: _expenseForm.data.category,
            debitDate: _expenseForm.data.debitDate,
            endDate: _expenseForm.data.effectiveEndDate,
            recurrence: _expenseForm.data.recurrence,
          ),
        ),
        onToggleAdvanced: _expenseForm.toggleAdvancedOptions,
        onDateChanged: _expenseForm.setDebitDate,
        onRecurrenceChanged: (value) =>
            _expenseForm.setRecurrence(value, preventPastStart: true),
        onEndDateChanged: _expenseForm.setEndDate,
        onEndDateCleared: _expenseForm.clearEndDate,
        isSubmitEnabled: () {
          final data = _expenseForm.data;
          return (ref
                          .read(categoriesSessionProvider)
                          .categoriesByAccount[data.account?.id] ??
                      const [])
                  .isNotEmpty &&
              data.account != null &&
              data.category != null;
        },
        preFieldsBuilder: (context) {
          final theme = Theme.of(context);
          final data = _expenseForm.data;
          final categories =
              ref
                  .read(categoriesSessionProvider)
                  .categoriesByAccount[data.account?.id] ??
              const [];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 18,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  SectionLabel(tr.account),
                  FramedContainer(
                    child: AccountSelector(
                      accounts: ref.read(accountSelectionProvider).accounts,
                      selectedAccount: data.account,
                      backgroundColor: theme.colorScheme.surface,
                      onSelect: (account) async {
                        _expenseForm.setAccount(account);
                        final loaded = await ref
                            .read(categoriesSessionProvider.notifier)
                            .load(account.id!);
                        if (loaded.isNotEmpty) {
                          _expenseForm.setCategory(loaded.first);
                        }
                      },
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  SectionLabel(tr.category),
                  categories.isEmpty
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer.withValues(
                              alpha: 0.6,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.error.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                          child: Row(
                            spacing: 8,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 18,
                                color: theme.colorScheme.error,
                              ),
                              Expanded(
                                child: Text(
                                  tr.noCategoryForAccount,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : FramedContainer(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: CategorySelector(
                            categories: categories,
                            selectedCategory: data.category,
                            onSelect: _expenseForm.setCategory,
                          ),
                        ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _onPeriodChanged(Period period) {
    final current = ref.read(overviewProvider).selectedPeriod;
    if (period.isAfter(current)) {
      _slideDirection.value = 1;
    } else if (period.isBefore(current)) {
      _slideDirection.value = -1;
    } else {
      return;
    }
    ref.read(overviewProvider.notifier).selectPeriod(period);
  }

  void _changePeriodBySwipe(bool next) {
    final state = ref.read(overviewProvider);
    final target = next
        ? state.selectedPeriod.next
        : state.selectedPeriod.previous;
    if (target.isBefore(overviewMinPeriod()) ||
        target.isAfter(overviewMaxPeriod())) {
      return;
    }
    _onPeriodChanged(target);
  }

  void _openCategoryDetails(String categoryId) {
    final state = ref.read(overviewProvider);
    final accountId = ref.read(accountSelectionProvider).selectedAccount?.id;
    if (accountId == null) return;
    context.push(
      NavigationHelper.buildCategoryExpensesPath(
        accountId,
        categoryId,
        state.selectedPeriod,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final overview = ref.watch(overviewProvider);
    final body = !overview.hasLoaded
        ? const AppLoadingIndicator()
        : OverviewContent(
            slideDirection: _slideDirection,
            onPeriodChanged: _onPeriodChanged,
            onSwipe: _changePeriodBySwipe,
            onCategoryTap: _openCategoryDetails,
            onRefresh: ref.read(overviewProvider.notifier).refreshAll,
            translations: tr,
          );

    return Scaffold(
      body: Column(
        children: [
          const UndebitedExpensesBanner(),
          Expanded(
            child: RiverpodFeedback(
              messageListenable: overviewProvider.select(
                (s) => s.status.pendingMessage,
              ),
              onConsume: (ref) =>
                  ref.read(overviewProvider.notifier).consumeMessage(),
              child: body,
            ),
          ),
        ],
      ),
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: showFabLabel,
        builder: (context, showLabel, child) => BudglyFab(
          heroTag: 'create_expense',
          label: showLabel ? tr.fabNewExpense : null,
          onPressed: _openAddExpenseModal,
        ),
      ),
    );
  }
}
