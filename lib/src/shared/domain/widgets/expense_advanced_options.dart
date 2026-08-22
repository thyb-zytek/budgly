import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/models/expense/expense_editing_data.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/shared/ui/widgets/inputs/date_field.dart';
import 'package:budgly/src/shared/domain/widgets/recurrence_selector.dart';
import 'package:flutter/material.dart';

class ExpenseAdvancedOptions extends StatelessWidget {
  final ExpenseEditingData editingData;
  final String localeName;
  final VoidCallback onToggleAdvanced;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<RecurrenceType> onRecurrenceChanged;

  const ExpenseAdvancedOptions({
    super.key,
    required this.editingData,
    required this.localeName,
    required this.onToggleAdvanced,
    required this.onDateChanged,
    required this.onRecurrenceChanged,
  });

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

    return Column(
      children: [
        Align(
          alignment: Alignment.center,
          child: TextButton.icon(
            onPressed: onToggleAdvanced,
            icon: Icon(
              editingData.showAdvancedOptions
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
          child: !editingData.showAdvancedOptions
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
                          selectedRecurrence: editingData.recurrence,
                          onRecurrenceChanged: onRecurrenceChanged,
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 8,
                      children: [
                        _sectionLabel(context, tr.debitDate),
                        DateField(
                          initialDate: editingData.debitDate,
                          localeName: localeName,
                          onDateChanged: onDateChanged,
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
