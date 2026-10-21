import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/button_styles.dart';
import 'package:budgly/src/core/theme/snackbar.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/expense/expense_occurrence.dart';
import 'package:budgly/src/pages/category_expenses/category_expenses_provider.dart';
import 'package:budgly/src/shared/domain/widgets/accounts/selector.dart';
import 'package:budgly/src/shared/domain/widgets/categories/selector.dart';
import 'package:budgly/src/shared/domain/widgets/expenses/expense_editor_sheet.dart';
import 'package:budgly/src/shared/domain/widgets/expenses/expense_form_controller.dart';
import 'package:budgly/src/shared/ui/widgets/layout/framed_container.dart';
import 'package:budgly/src/shared/ui/widgets/layout/section_label.dart';
import 'package:budgly/src/pages/settings/widgets/confirm_delete.dart';
import 'package:budgly/src/state/accounts_provider.dart';
import 'package:budgly/src/state/categories_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class CategoryExpenseEditorSheet extends ConsumerWidget {
  const CategoryExpenseEditorSheet({
    super.key,
    required this.form,
    required this.occurrence,
    required this.accountId,
    required this.categoryId,
    required this.period,
  });

  final ExpenseFormController form;
  final ExpenseOccurrence occurrence;
  final String accountId;
  final String categoryId;
  final Period period;

  CategoryExpensesProvider get provider =>
      categoryExpensesProvider(accountId, categoryId, period);

  Future<void> _selectAccount(
    WidgetRef ref,
    BuildContext context,
    Account account,
  ) async {
    if (form.data.account?.id == account.id) return;

    form.setAccount(account);
    final id = account.id;
    if (id == null) return;

    final session = ref.read(categoriesSessionProvider);
    if (!session.loadedAccounts.contains(id)) {
      await ref.read(categoriesSessionProvider.notifier).load(id);
    }

    if (!context.mounted) return;

    final categories =
        ref.read(categoriesSessionProvider).categoriesByAccount[id] ?? const [];

    if (categories.isEmpty) {
      form.clearCategory();
      return;
    }

    final selected = form.data.category;
    if (selected == null ||
        !categories.any((category) => category.id == selected.id)) {
      form.setCategory(categories.first);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyCode = ref.watch(
      provider.select((state) => state.currencyCode),
    );
    final localeName = ref.watch(provider.select((state) => state.localeName));
    final isSaving = ref.watch(provider.select((state) => state.isSaving));
    final editingOccurrence = ref.watch(
      provider.select((state) => state.editingOccurrence),
    );
    final currentOccurrence = editingOccurrence ?? occurrence;
    final tr = AppLocalizations.of(context)!;

    return ExpenseEditorSheet(
      listenable: form,
      editingData: form.data,
      nameController: form.nameController,
      amountController: form.amountController,
      title: tr.editExpense,
      currencyCode: currencyCode,
      localeName: localeName,
      validate: (tr) => form.validate(tr, requireAccountAndCategory: true),
      onSubmit: () {
        final amount = form.parseEnteredAmount();
        if (amount == null) return Future.value(false);

        return ref
            .read(provider.notifier)
            .saveEditing(
              ExpenseEditFormData(
                name: form.nameController.text.trim(),
                amount: amount,
                accountId: form.data.account?.id,
                categoryId: form.data.category?.id,
                debitDate: form.data.debitDate,
                endDate: form.data.effectiveEndDate,
                recurrence: form.data.recurrence,
              ),
            );
      },
      onBeforeSubmit: occurrence.recurrence.isRecurring
          ? () async {
              final choice = await showRecurringEditOptions(
                context,
                expenseName: occurrence.name,
                dateLabel: DateFormat.yMMMMd(localeName)
                    .format(occurrence.date),
              );
              if (!context.mounted || choice == null) return false;

              ref
                  .read(provider.notifier)
                  .setRecurringEditScope(
                    choice == RecurringEditChoice.single
                        ? RecurringEditScope.single
                        : RecurringEditScope.future,
                  );
              return true;
            }
          : null,
      submitFailureMessage: tr.expenseUpdateFailed,
      onToggleAdvanced: form.toggleAdvancedOptions,
      onDateChanged: form.setDebitDate,
      onRecurrenceChanged: form.setRecurrence,
      onEndDateChanged: form.setEndDate,
      onEndDateCleared: form.clearEndDate,
      isSubmitEnabled: () {
        final selectedAccountId = form.data.account?.id ?? accountId;
        final categories =
            ref
                .read(categoriesSessionProvider)
                .categoriesByAccount[selectedAccountId] ??
            const [];
        return categories.isNotEmpty &&
            form.data.account != null &&
            form.data.category != null;
      },
      titleLeadingBuilder: (context) {
        // A debited expense cannot be deleted: hide the affordance entirely.
        if (currentOccurrence.isDebited) {
          return const SizedBox(width: 40);
        }

        final theme = Theme.of(context);
        return IconButton.filled(
          style: ButtonType.error.iconFilledStyle(theme),
          onPressed: isSaving
              ? null
              : () => _deleteEditingExpense(ref, context, currentOccurrence),
          icon: const Icon(Icons.delete_outline, size: 20),
          tooltip: tr.delete,
        );
      },
      titleTrailingBuilder: (context) {
        final theme = Theme.of(context);
        final isDebited = currentOccurrence.isDebited;
        return IconButton.filled(
          style: (isDebited ? ButtonType.secondary : ButtonType.success)
              .iconFilledStyle(theme),
          onPressed: isSaving
              ? null
              : () => _toggleDebited(ref, context, currentOccurrence),
          icon: Icon(
            isDebited
                ? Icons.remove_circle_outline
                : Icons.check_circle_outline,
            size: 20,
          ),
          tooltip: isDebited ? tr.expenseMarkedAsPending : tr.markAsDebited,
        );
      },
      preFieldsBuilder: (context) => Consumer(
        builder: (context, ref, _) {
          final accounts = ref.watch(
            accountsSessionProvider.select((state) => state.accounts),
          );
          final selectedAccountId = form.data.account?.id ?? accountId;
          final categories = ref.watch(
            categoriesSessionProvider.select(
              (state) =>
                  state.categoriesByAccount[selectedAccountId] ?? const [],
            ),
          );
          final theme = Theme.of(context);
          final editing = ref.watch(
            provider.select((state) => state.editingOccurrence),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  SectionLabel(tr.account),
                  FramedContainer(
                    child: AccountSelector(
                      accounts: accounts,
                      selectedAccount: form.data.account,
                      backgroundColor: theme.colorScheme.surface,
                      onSelect: (account) =>
                          _selectAccount(ref, context, account),
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
                            selectedCategory: form.data.category,
                            onSelect: form.setCategory,
                          ),
                        ),
                ],
              ),
              if (editing != null && editing.recurrence.isRecurring)
                Text(
                  tr.recurringEditFromDate(
                    DateFormat.yMMMMd(localeName).format(editing.date),
                  ),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              if (editing != null && editing.recurrence.isRecurring)
                Text(
                  tr.markDebitedOccurrence(
                    DateFormat.yMMMMd(localeName).format(editing.date),
                  ),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          );
        },
      ),
      onSubmitSuccess: () {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(
          buildAppSnackBar(tr.expenseUpdatedSuccessfully, SnackBarType.success),
        );
      },
    );
  }

  Future<void> _toggleDebited(
    WidgetRef ref,
    BuildContext context,
    ExpenseOccurrence occurrence,
  ) async {
    final tr = AppLocalizations.of(context)!;
    final current = ref.read(provider).editingOccurrence ?? occurrence;
    final wasDebited = current.isDebited;
    final success = await ref.read(provider.notifier).toggleDebited(current);
    if (!context.mounted || !success) return;

    showAppSnackBar(
      context,
      message: wasDebited
          ? tr.expenseMarkedAsPending
          : tr.expenseMarkedAsDebited,
      type: wasDebited ? SnackBarType.pending : SnackBarType.success,
    );
  }

  Future<void> _deleteEditingExpense(
    WidgetRef ref,
    BuildContext context,
    ExpenseOccurrence occurrence,
  ) async {
    final tr = AppLocalizations.of(context)!;
    final current = ref.read(provider).editingOccurrence ?? occurrence;
    if (current.isDebited) return;

    var success = false;
    bool? confirmed;

    if (current.recurrence.isRecurring) {
      final choice = await showRecurringDeleteOptions(
        context,
        expenseName: current.name,
        dateLabel: DateFormat.yMMMMd(ref.read(provider).localeName)
            .format(current.date),
      );
      if (!context.mounted || choice == null) return;

      if (choice == RecurringDeleteChoice.single) {
        success = await ref
            .read(provider.notifier)
            .deleteSingleOccurrence(current);
        confirmed = success;
      } else {
        success = await ref
            .read(provider.notifier)
            .deleteFutureOccurrences(current);
        confirmed = success;
      }
    } else {
      confirmed = await showConfirmDelete(
        context,
        title: tr.confirmDeleteExpense(current.name),
        content: tr.confirmDeleteExpenseMessage(current.name),
        onConfirm: () async {
          success = await ref.read(provider.notifier).deleteOccurrence(current);
        },
      );
      if (!context.mounted || confirmed != true) return;
    }

    if (!context.mounted || !success) return;

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      buildAppSnackBar(tr.expenseDeletedSuccessfully, SnackBarType.success),
    );
  }
}
