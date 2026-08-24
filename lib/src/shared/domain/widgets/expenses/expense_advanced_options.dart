import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/models/expense/expense_editing_data.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/shared/domain/widgets/expenses/recurrence_badge.dart';
import 'package:budgly/src/shared/domain/widgets/expenses/recurrence_selector.dart';
import 'package:budgly/src/shared/ui/widgets/inputs/date_field.dart';
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
    final theme = Theme.of(context);
    final data = editingData;
    final isExpanded = data.showAdvancedOptions;
    final isRecurring = data.recurrence.isRecurring;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButton(
          onPressed: onToggleAdvanced,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              const Icon(Icons.event_repeat_rounded, size: 18),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr.expenseAdvancedOptions,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  if (isRecurring) ...[
                    const SizedBox(height: 4),
                    RecurrenceBadge(
                      label: tr.recurrenceActiveSummary(
                        recurrenceLabel(tr, data.recurrence),
                      ),
                    ),
                  ]
                ],
              ),
            ],
          ),
        ),        
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: isExpanded
              ? Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Column(
                    spacing: 18,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 6,
                        children: [
                          _sectionLabel(context, tr.recurrence),
                          RecurrenceSelector(
                            selectedRecurrence: data.recurrence,
                            onRecurrenceChanged: onRecurrenceChanged,
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 6,
                        children: [
                          _sectionLabel(context, tr.debitDate),
                          DateField(
                            initialDate: data.debitDate,
                            localeName: localeName,
                            onDateChanged: onDateChanged,
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}