import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/extensions/currency.dart';
import 'package:budgly/src/core/theme/button_styles.dart';
import 'package:budgly/src/core/theme/input_styles.dart';
import 'package:budgly/src/core/theme/snackbar.dart';
import 'package:budgly/src/pages/category_expenses/view_model.dart';
import 'package:budgly/src/pages/settings/widgets/confirm_delete.dart';
import 'package:budgly/src/shared/widgets/categories/category_icon_view.dart';
import 'package:budgly/src/shared/widgets/inputs/input.dart';
import 'package:budgly/src/shared/widgets/selector/recurrence_selector.dart';
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

  Future<void> _pickDebitDate() async {
    final viewModel = widget.viewModel;
    final picked = await showDatePicker(
      context: context,
      initialDate: viewModel.editingData.debitDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) viewModel.setDebitDate(picked);
  }

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
      type: SnackBarType.success,
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Text(
      text.toUpperCase(),
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
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
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 12,
                    children: [
                      Expanded(
                        flex: 4,
                        child: TextInput(
                          controller: data.nameController,
                          labelText: tr.activity,
                          hotValidating: (v) => v == null || v.trim().isEmpty
                              ? tr.nameRequired
                              : null,
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: TextInput(
                          controller: data.amountController,
                          labelText: tr.amount,
                          type: InputType.currency,
                          suffix: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(
                              viewModel.currencyCode.currencyIcon,
                              size: 20,
                              opticalSize: 14,
                              color: theme.colorScheme.onSurface.withAlpha(155),
                            ),
                          ),
                          textInputAction: TextInputAction.done,
                          hotValidating: (v) {
                            final amount = double.tryParse(
                              (v ?? '').replaceAll(',', '.'),
                            );
                            if (amount == null || amount <= 0) {
                              return tr.amountInvalid;
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: TextButton.icon(
                      onPressed: viewModel.toggleAdvancedOptions,
                      icon: Icon(
                        data.showAdvancedOptions
                            ? Icons.expand_less
                            : Icons.expand_more,
                      ),
                      label: Text(tr.advancedOptions),
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: !data.showAdvancedOptions
                        ? const SizedBox(width: double.infinity)
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            spacing: 18,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                spacing: 8,
                                children: [
                                  _sectionLabel(context, tr.recurrence),
                                  RecurrenceSelector(
                                    selectedRecurrence: data.recurrence,
                                    onRecurrenceChanged: (recurrence) {
                                      viewModel.setRecurrence(recurrence);
                                    },
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                spacing: 8,
                                children: [
                                  _sectionLabel(context, tr.debitDate),
                                  InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: _pickDebitDate,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surface,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Row(
                                        spacing: 8,
                                        children: [
                                          Icon(
                                            Icons.event_outlined,
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                            size: 28,
                                          ),
                                          Text(
                                            DateFormat.yMMMMd(
                                              viewModel.localeName,
                                            ).format(data.debitDate),
                                            style: theme.textTheme.bodyMedium,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 8,
                    children: [
                      FilledButton.icon(
                        style: ButtonType.success.filledStyle(
                          theme,
                          dense: true,
                        ),
                        onPressed: viewModel.isSaving ? null : _toggleDebited,
                        icon: Icon(
                          isDebited
                              ? Icons.undo_rounded
                              : Icons.check_circle_rounded,
                          size: 20,
                        ),
                        label: Text(
                          isDebited
                              ? tr.expenseMarkedAsPending
                              : tr.markAsDebited,
                        ),
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
                  FilledButton(
                    style: ButtonType.error.filledStyle(theme, dense: true),
                    onPressed: viewModel.isSaving ? null : _delete,
                    child: Text(tr.deleteExpense),
                  ),
                  Row(
                    spacing: 12,
                    children: [
                      Expanded(
                        child: FilledButton(
                          style: ButtonType.outlined.filledStyle(
                            theme,
                            dense: true,
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: Text(tr.cancel),
                        ),
                      ),
                      Expanded(
                        child: FilledButton(
                          style: ButtonType.primary.filledStyle(
                            theme,
                            dense: true,
                          ),
                          onPressed: viewModel.isSaving ? null : _save,
                          child: Text(tr.validate),
                        ),
                      ),
                    ],
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
