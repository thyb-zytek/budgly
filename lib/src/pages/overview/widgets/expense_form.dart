import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/snackbar.dart';
import 'package:budgly/src/pages/overview/view_model.dart';
import 'package:budgly/src/shared/domain/widgets/accounts/selector.dart';
import 'package:budgly/src/shared/domain/widgets/categories/selector.dart';
import 'package:budgly/src/shared/domain/widgets/expense_form_fields.dart';
import 'package:budgly/src/shared/ui/widgets/form_actions.dart';
import 'package:budgly/src/shared/ui/widgets/layout/framed_container.dart';
import 'package:flutter/material.dart';

class ExpenseForm extends StatefulWidget {
  final OverviewViewModel viewModel;

  const ExpenseForm({super.key, required this.viewModel});

  @override
  State<ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<ExpenseForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? _errorMessage;

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
    final messenger = ScaffoldMessenger.of(context);
    final success = await viewModel.createExpense();
    if (success && mounted) {
      Navigator.pop(context);
      messenger.showSnackBar(
        buildAppSnackBar(tr.expenseCreatedSuccessfully, SnackBarType.success),
      );
    }
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
                      FramedContainer(
                        child: AccountSelector(
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
                          : FramedContainer(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: CategorySelector(
                                categories: categories,
                                selectedCategory: data.category,
                                onSelect: (category) =>
                                    viewModel.selectFormCategory(category),
                              ),
                            ),
                    ],
                  ),
                  ExpenseFormFields(
                    editingData: data,
                    currencyCode: viewModel.currencyCode,
                    localeName: viewModel.localeName,
                    onToggleAdvanced: viewModel.toggleAdvancedOptions,
                    onDateChanged: viewModel.setDebitDate,
                    onRecurrenceChanged: viewModel.setRecurrence,
                  ),
                  if (_errorMessage != null)
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  FormActions(
                    onCancel: () => Navigator.pop(context),
                    onSubmit: _submit,
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
}
