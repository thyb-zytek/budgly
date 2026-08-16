import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/shared/widgets/selector/selector.dart';
import 'package:flutter/material.dart';

class RecurrenceSelector extends StatelessWidget {
  final RecurrenceType selectedRecurrence;
  final ValueChanged<RecurrenceType> onRecurrenceChanged;

  const RecurrenceSelector({
    super.key,
    required this.selectedRecurrence,
    required this.onRecurrenceChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;

    return Selector<RecurrenceType>(
      items: RecurrenceType.values,
      selectedItem: selectedRecurrence,
      backgroundColor: Theme.of(context).colorScheme.surface,
      maxHeight: 300,
      onSelect: onRecurrenceChanged,
      itemBuilder: (context, recurrence) {
        final label = switch (recurrence) {
          RecurrenceType.none => tr.recurrenceNone,
          RecurrenceType.daily => tr.recurrenceDaily,
          RecurrenceType.weekly => tr.recurrenceWeekly,
          RecurrenceType.monthly => tr.recurrenceMonthly,
          RecurrenceType.yearly => tr.recurrenceYearly,
          RecurrenceType.bimonthly => tr.recurrenceBiMonthly,
          RecurrenceType.trimonthly => tr.recurrenceTriMonthly,
          RecurrenceType.halfyearly => tr.recurrenceHalfYearly,
          RecurrenceType.biyearly => tr.recurrenceBiYearly,
        };
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          child: Text(label),
        );
      },
    );
  }
}
