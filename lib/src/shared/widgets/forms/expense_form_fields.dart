import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/models/expense/expense_editing_data.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/shared/widgets/forms/expense_advanced_options.dart';
import 'package:budgly/src/shared/widgets/inputs/currency_input.dart';
import 'package:budgly/src/shared/widgets/inputs/input.dart';
import 'package:flutter/material.dart';

class ExpenseFormFields extends StatelessWidget {
  final ExpenseEditingData editingData;
  final String currencyCode;
  final String localeName;
  final VoidCallback onToggleAdvanced;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<RecurrenceType> onRecurrenceChanged;

  const ExpenseFormFields({
    super.key,
    required this.editingData,
    required this.currencyCode,
    required this.localeName,
    required this.onToggleAdvanced,
    required this.onDateChanged,
    required this.onRecurrenceChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 18,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Expanded(
              flex: 4,
              child: TextInput(
                controller: editingData.nameController,
                labelText: tr.activity,
                hotValidating: (v) => v == null || v.trim().isEmpty
                    ? tr.nameRequired
                    : null,
              ),
            ),
            Expanded(
              flex: 3,
              child: CurrencyInput(
                controller: editingData.amountController,
                currencyCode: currencyCode,
                labelText: tr.amount,
              ),
            ),
          ],
        ),
        ExpenseAdvancedOptions(
          editingData: editingData,
          localeName: localeName,
          onToggleAdvanced: onToggleAdvanced,
          onDateChanged: onDateChanged,
          onRecurrenceChanged: onRecurrenceChanged,
        ),
      ],
    );
  }
}
