import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/models/expense/expense_editing_data.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/shared/domain/widgets/expenses/expense_form_fields.dart';
import 'package:budgly/src/shared/ui/widgets/forms/form_actions.dart';
import 'package:flutter/material.dart';

/// Shared presentation for creating and editing an expense.
///
/// Business operations remain owned by the caller's ViewModel. This widget
/// owns only the common form presentation, validation and submit lifecycle.
class ExpenseEditorSheet extends StatefulWidget {
  final Listenable listenable;
  final ExpenseEditingData editingData;
  final String title;
  final String currencyCode;
  final String localeName;
  final String? Function(AppLocalizations translations) validate;
  final Future<bool> Function() onSubmit;
  final VoidCallback? onSubmitSuccess;
  final String? submitFailureMessage;
  final bool Function() isSaving;
  final bool destructiveCancel;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<RecurrenceType> onRecurrenceChanged;
  final ValueChanged<DateTime> onEndDateChanged;
  final VoidCallback onEndDateCleared;
  final VoidCallback onToggleAdvanced;
  final WidgetBuilder? headerBuilder;
  final WidgetBuilder? preFieldsBuilder;
  final WidgetBuilder? actionsBuilder;
  final WidgetBuilder? titleLeadingBuilder;
  final WidgetBuilder? titleTrailingBuilder;
  final bool Function()? isSubmitEnabled;

  const ExpenseEditorSheet({
    super.key,
    required this.listenable,
    required this.editingData,
    required this.title,
    required this.currencyCode,
    required this.localeName,
    required this.validate,
    required this.onSubmit,
    required this.onDateChanged,
    required this.onRecurrenceChanged,
    required this.onEndDateChanged,
    required this.onEndDateCleared,
    required this.onToggleAdvanced,
    this.onSubmitSuccess,
    this.submitFailureMessage,
    required this.isSaving,
    this.destructiveCancel = true,
    this.headerBuilder,
    this.preFieldsBuilder,
    this.actionsBuilder,
    this.titleLeadingBuilder,
    this.titleTrailingBuilder,
    this.isSubmitEnabled,
  });

  @override
  State<ExpenseEditorSheet> createState() => _ExpenseEditorSheetState();
}

class _ExpenseEditorSheetState extends State<ExpenseEditorSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? _errorMessage;

  Future<void> _submit() async {
    final tr = AppLocalizations.of(context)!;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final error = widget.validate(tr);
    if (error != null) {
      setState(() => _errorMessage = error);
      return;
    }

    setState(() => _errorMessage = null);
    final success = await widget.onSubmit();
    if (!mounted) return;

    if (success) {
      widget.onSubmitSuccess?.call();
      if (widget.onSubmitSuccess == null) Navigator.pop(context);
    } else if (widget.submitFailureMessage != null) {
      setState(() => _errorMessage = widget.submitFailureMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: widget.listenable,
      builder: (context, child) {
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
                  Row(
                    spacing: 8,
                    children: [
                      if (widget.titleLeadingBuilder != null)
                        widget.titleLeadingBuilder!(context)
                      else
                        const SizedBox(width: 48),
                      Expanded(
                        child: Text(
                          widget.title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (widget.titleTrailingBuilder != null)
                        widget.titleTrailingBuilder!(context)
                      else
                        const SizedBox(width: 48),
                    ],
                  ),
                  if (widget.headerBuilder != null)
                    widget.headerBuilder!(context),
                  if (widget.preFieldsBuilder != null)
                    widget.preFieldsBuilder!(context),
                  ExpenseFormFields(
                    editingData: widget.editingData,
                    currencyCode: widget.currencyCode,
                    localeName: widget.localeName,
                    onToggleAdvanced: widget.onToggleAdvanced,
                    onDateChanged: widget.onDateChanged,
                    onRecurrenceChanged: widget.onRecurrenceChanged,
                    onEndDateChanged: widget.onEndDateChanged,
                    onEndDateCleared: widget.onEndDateCleared,
                  ),
                  if (widget.actionsBuilder != null)
                    widget.actionsBuilder!(context),
                  if (_errorMessage != null)
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  FormActions(
                    onCancel: () => Navigator.pop(context),
                    onSubmit: _submit,
                    destructiveCancel: widget.destructiveCancel,
                    isLoading: widget.isSaving(),
                    isSubmitEnabled: widget.isSubmitEnabled?.call() ?? true,
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
