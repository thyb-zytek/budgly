import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/shared/ui/widgets/selector.dart';
import 'package:flutter/material.dart';

String recurrenceLabel(AppLocalizations tr, RecurrenceType recurrence) {
  return switch (recurrence) {
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
}

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
      items: const [
        RecurrenceType.none,
        RecurrenceType.monthly,
        RecurrenceType.yearly,
        RecurrenceType.bimonthly,
        RecurrenceType.trimonthly,
        RecurrenceType.halfyearly,
        RecurrenceType.biyearly,
        RecurrenceType.daily,
        RecurrenceType.weekly,
      ],
      selectedItem: selectedRecurrence,
      backgroundColor: Theme.of(context).colorScheme.surface,
      maxHeight: 300,
      onSelect: onRecurrenceChanged,
      itemBuilder: (context, recurrence) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: BudglySpacing.sm, vertical: BudglySpacing.lg),
          child: Text(recurrenceLabel(tr, recurrence)),
        );
      },
    );
  }
}
