import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/models/expense/expense_editing_data.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/shared/domain/widgets/expenses/recurrence_badge.dart';
import 'package:budgly/src/shared/domain/widgets/expenses/advanced_date_field.dart';
import 'package:budgly/src/shared/domain/widgets/expenses/recurrence_selector.dart';
import 'package:budgly/src/shared/domain/widgets/expenses/end_date_field.dart';
import 'package:budgly/src/shared/ui/widgets/inputs/date_field.dart';
import 'package:budgly/src/shared/ui/widgets/layout/section_label.dart';
import 'package:flutter/material.dart';

class ExpenseAdvancedOptions extends StatelessWidget {
  final ExpenseEditingData editingData;
  final String localeName;
  final VoidCallback onToggleAdvanced;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<RecurrenceType> onRecurrenceChanged;
  final ValueChanged<DateTime> onEndDateChanged;
  final VoidCallback onEndDateCleared;

  const ExpenseAdvancedOptions({
    super.key,
    required this.editingData,
    required this.localeName,
    required this.onToggleAdvanced,
    required this.onDateChanged,
    required this.onRecurrenceChanged,
    required this.onEndDateChanged,
    required this.onEndDateCleared,
  });

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
        InkWell(
          onTap: onToggleAdvanced,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
              ),
            ),
            child: Row(
              spacing: BudglySpacing.sm,
              children: [
                Icon(
                  Icons.event_repeat_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Row(
                        spacing: BudglySpacing.sm,
                        children: [
                          Text(
                            tr.expenseAdvancedOptions,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (isRecurring)
                            RecurrenceBadge(
                              label: tr.recurrenceActiveSummary(
                                recurrenceLabel(tr, data.recurrence),
                              ),
                            ),
                        ],
                      ),
                      if (!isExpanded)
                        Text(
                          tr.expenseAdvancedOptionsHint,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 22,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: isExpanded
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    spacing: BudglySpacing.lg,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: BudglySpacing.sm,
                        children: [
                          SectionLabel(tr.recurrence),
                          RecurrenceSelector(
                            selectedRecurrence: data.recurrence,
                            onRecurrenceChanged: onRecurrenceChanged,
                          ),
                        ],
                      ),
                      Column(
                        spacing: BudglySpacing.lg,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: AdvancedDateField(
                                      label: tr.debitDate,
                                      child: DateField(
                                        date: data.debitDate,
                                        localeName: localeName,
                                        onDateChanged: onDateChanged,
                                      ),
                                    ),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.topCenter,
                            child: isRecurring
                                ? SizedBox(
                                    width: double.infinity,
                                    child: AdvancedDateField(
                                      label: tr.endDate,
                                      child: buildEndDateField(
                                        context,
                                        endDate: data.endDate,
                                        recurrence: data.recurrence,
                                        minimumDate: data.debitDate,
                                        localeName: localeName,
                                        onDateChanged: onEndDateChanged,
                                        onCleared: onEndDateCleared,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
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

