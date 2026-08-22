import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/button_styles.dart';
import 'package:budgly/src/core/theme/snackbar.dart';
import 'package:budgly/src/pages/category_expenses/view_model.dart';
import 'package:budgly/src/pages/settings/widgets/confirm_delete.dart';
import 'package:budgly/src/shared/domain/widgets/categories/category_icon_view.dart';
import 'package:budgly/src/shared/domain/widgets/expense_form_fields.dart';
import 'package:budgly/src/shared/ui/widgets/form_actions.dart';
import 'package:budgly/src/shared/ui/widgets/layout/framed_container.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Bottom sheet to manage an expense occurrence: edit its info, delete it or
/// toggle its debited state. For recurring expenses, edits apply to the whole
/// template while the debited state only concerns the tapped occurrence.
class ExpenseEditSheet extends StatefulWidget {
  final CategoryExpensesViewModel viewModel;

  const ExpenseEditSheet({super.key, required this.viewModel});

  @override
  State<ExpenseEditSheet> createState() => _ExpenseEditSheetState();
}

class _ExpenseEditSheetState extends State<ExpenseEditSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? _errorMessage;

  Future<void> _save() async {
    final tr = AppLocalizations.of(context)!;
    final viewModel = widget.viewModel;

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final error = viewModel.validate(tr);
    if (error != null) {
      setState(() => _errorMessage = error);
      return;
    }

    setState(() => _errorMessage = null);
    final success = await viewModel.saveEditing();
    if (!mounted) return;

    if (success) {
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      navigator.pop();
      messenger.showSnackBar(
        buildAppSnackBar(tr.expenseUpdatedSuccessfully, SnackBarType.success),
      );
    } else {
      setState(() => _errorMessage = tr.expenseUpdateFailed);
    }
  }

  Future<void> _delete() async {
    final tr = AppLocalizations.of(context)!;
    final viewModel = widget.viewModel;
    final occurrence = viewModel.editingOccurrence;
    if (occurrence == null) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final deleted = await showConfirmDelete(
      context,
      title: tr.confirmDeleteExpense(occurrence.name),
      content: tr.confirmDeleteExpenseMessage(occurrence.name),
      onConfirm: () async {
        await viewModel.deleteEditingExpense();
      },
    );
    if (deleted != true || !mounted) return;

    navigator.pop();
    messenger.showSnackBar(
      buildAppSnackBar(tr.expenseDeletedSuccessfully, SnackBarType.success),
    );
  }

  Future<void> _toggleDebited() async {
    final tr = AppLocalizations.of(context)!;
    final viewModel = widget.viewModel;

    final success = await viewModel.toggleEditingOccurrenceDebited();
    if (!mounted || !success) return;

    final isDebitedNow = viewModel.editingOccurrence?.isDebited ?? false;
    showAppSnackBar(
      context,
      message: isDebitedNow ? tr.expenseMarkedAsDebited : tr.expenseMarkedAsPending,
      type: isDebitedNow ? SnackBarType.success : SnackBarType.pending,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: widget.viewModel,
      builder: (context, child) {
        final viewModel = widget.viewModel;
        final occurrence = viewModel.editingOccurrence;
        if (occurrence == null) return const SizedBox.shrink();

        final data = viewModel.editingData;
        final category = viewModel.category;
        final isDebited = occurrence.isDebited;
        final isRecurring = occurrence.recurrence.isRecurring;

        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 4,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 18,
                children: [
                  Text(
                    tr.editExpense,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (category != null)
                    FramedContainer(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        spacing: 12,
                        children: [
                          if (category.icon != null)
                            CategoryIconView(
                              icon: category.icon!,
                              color: category.color ?? Colors.grey,
                              size: 40,
                            )
                          else
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: category.color ?? Colors.grey,
                              ),
                              child: Icon(
                                Icons.category,
                                color: theme.colorScheme.onPrimary,
                                size: 40 * 0.6,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              category.name ?? '',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (isRecurring)
                            Icon(
                              Icons.repeat_rounded,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                        ],
                      ),
                    ),
                  ExpenseFormFields(
                    editingData: data,
                    currencyCode: viewModel.currencyCode,
                    localeName: viewModel.localeName,
                    onToggleAdvanced: viewModel.toggleAdvancedOptions,
                    onDateChanged: viewModel.setDebitDate,
                    onRecurrenceChanged: viewModel.setRecurrence,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 10,
                    children: [
                      Row(
                        spacing: 12,
                        children: [
                          Expanded(
                            child: FilledButton(
                              style:
                                  (isDebited
                                          ? ButtonType.secondary
                                          : ButtonType.success)
                                      .filledStyle(theme, dense: true),
                              onPressed: viewModel.isSaving
                                  ? null
                                  : _toggleDebited,
                              child: Text(
                                isDebited
                                    ? tr.expenseMarkedAsPending
                                    : tr.markAsDebited,
                              ),
                            ),
                          ),
                          Expanded(
                            child: FilledButton(
                              style: ButtonType.error.filledStyle(
                                theme,
                                dense: true,
                              ),
                              onPressed: viewModel.isSaving ? null : _delete,
                              child: Text(tr.delete),
                            ),
                          ),
                        ],
                      ),
                      if (isRecurring)
                        Text(
                          tr.markDebitedOccurrence(
                            DateFormat.yMMMMd(viewModel.localeName)
                                .format(occurrence.date),
                          ),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  if (_errorMessage != null)
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  FormActions(
                    cancelType: ButtonType.outlined,
                    onCancel: () => Navigator.pop(context),
                    onSubmit: viewModel.isSaving ? () {} : _save,
                    isLoading: viewModel.isSaving,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
