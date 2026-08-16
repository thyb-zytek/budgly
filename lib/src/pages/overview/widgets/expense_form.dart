import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/extensions/currency.dart';
import 'package:budgly/src/core/theme/button_styles.dart';
import 'package:budgly/src/core/theme/input_styles.dart';
import 'package:budgly/src/pages/overview/view_model.dart';
import 'package:budgly/src/shared/widgets/accounts/selector.dart';
import 'package:budgly/src/shared/widgets/selector/recurrence_selector.dart';
import 'package:budgly/src/shared/widgets/categories/selector.dart';
import 'package:budgly/src/shared/widgets/inputs/input.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ExpenseForm extends StatefulWidget {
  final OverviewViewModel viewModel;

  const ExpenseForm({super.key, required this.viewModel});

  @override
  State<ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<ExpenseForm> {
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

  Future<void> _submit() async {
    final tr = AppLocalizations.of(context)!;
    final viewModel = widget.viewModel;

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final error = viewModel.validate(tr);
    if (error != null) {
      setState(() => _errorMessage = error);
      return;
    }

    setState(() => _errorMessage = null);
    final success = await viewModel.createExpense();
    if (success && mounted) {
      Navigator.pop(context);
    }
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

  Widget _framedField(
    BuildContext context,
    Widget child, {
    EdgeInsets? padding,
  }) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      padding: padding ?? const EdgeInsets.all(4),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final viewModel = widget.viewModel;

    return AnimatedBuilder(
      animation: viewModel,
      builder: (context, child) {
        final accounts = viewModel.accounts;
        final data = viewModel.editingData;
        final categories = viewModel.categoriesForSelectedAccount();

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
                    tr.newExpense,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 8,
                    children: [
                      _sectionLabel(context, tr.account),
                      _framedField(
                        context,
                        AccountSelector(
                          accounts: accounts,
                          selectedAccount: data.account,
                          backgroundColor: theme.colorScheme.surface,
                          onSelect: (account) =>
                              viewModel.selectFormAccount(account),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 8,
                    children: [
                      _sectionLabel(context, tr.category),
                      categories.isEmpty
                          ? Text(
                              tr.noCategoryForAccount,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            )
                          : _framedField(
                              context,
                              CategorySelector(
                                categories: categories,
                                selectedCategory: data.category,
                                onSelect: (category) =>
                                    viewModel.selectFormCategory(category),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 4),
                            ),
                    ],
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
                  if (_errorMessage != null)
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  Row(
                    spacing: 12,
                    children: [
                      Expanded(
                        child: FilledButton(
                          style: ButtonType.error.filledStyle(
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
                          onPressed: _submit,
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
