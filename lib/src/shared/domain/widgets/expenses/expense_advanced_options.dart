import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/models/expense/expense_editing_data.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/shared/domain/widgets/expenses/recurrence_badge.dart';
import 'package:budgly/src/shared/domain/widgets/expenses/recurrence_selector.dart';
import 'package:budgly/src/shared/ui/widgets/inputs/date_field.dart';
import 'package:flutter/material.dart';

class ExpenseAdvancedOptions extends StatefulWidget {
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

  @override
  State<ExpenseAdvancedOptions> createState() =>
      _ExpenseAdvancedOptionsState();
}

class _ExpenseAdvancedOptionsState extends State<ExpenseAdvancedOptions> {
  late bool _showRecurrence = widget.editingData.recurrence.isRecurring;

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
    final data = widget.editingData;
    final isRecurring = data.recurrence.isRecurring;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _showRecurrence = !_showRecurrence),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isRecurring
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              spacing: 10,
              children: [
                Icon(
                  Icons.repeat_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                Expanded(
                  child: Text(
                    tr.recurrence,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: isRecurring
                      ? RecurrenceBadge(
                          key: const ValueKey('recurrence-summary'),
                          label: tr.recurrenceActiveSummary(
                            recurrenceLabel(tr, data.recurrence),
                          ),
                        )
                      : const SizedBox.shrink(
                          key: ValueKey('recurrence-empty'),
                        ),
                ),
                AnimatedRotation(
                  turns: _showRecurrence ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.expand_more_rounded,
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
          child: !_showRecurrence
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: RecurrenceSelector(
                    selectedRecurrence: data.recurrence,
                    onRecurrenceChanged: widget.onRecurrenceChanged,
                  ),
                ),
        ),
        Align(
          alignment: Alignment.center,
          child: TextButton.icon(
            onPressed: widget.onToggleAdvanced,
            icon: Icon(
              data.showAdvancedOptions
                  ? Icons.expand_less
                  : Icons.expand_more,
            ),
            label: Text(tr.debitDateOptions),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: !data.showAdvancedOptions
              ? const SizedBox(width: double.infinity)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [
                    _sectionLabel(context, tr.debitDate),
                    DateField(
                      initialDate: data.debitDate,
                      localeName: widget.localeName,
                      onDateChanged: widget.onDateChanged,
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
