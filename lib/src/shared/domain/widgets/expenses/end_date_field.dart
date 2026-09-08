import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/shared/ui/widgets/inputs/date_field.dart';
import 'package:flutter/material.dart';

/// Builds the end-date variant of [DateField], pre-filled with the
/// recurrence's next occurrence after [minimumDate].
///
/// This is expense-recurrence business logic (it knows how to derive a
/// suggested end date from a [RecurrenceType]), so it lives alongside the
/// other expense widgets rather than in the generic inputs folder.
Widget buildEndDateField(
  BuildContext context, {
  Key? key,
  required DateTime? endDate,
  required RecurrenceType recurrence,
  required DateTime minimumDate,
  required String localeName,
  required ValueChanged<DateTime> onDateChanged,
  required VoidCallback onCleared,
}) {
  final tr = AppLocalizations.of(context)!;
  final firstDate = DateTime(
    minimumDate.year,
    minimumDate.month,
    minimumDate.day,
  );

  return DateField(
    key: key,
    date: endDate,
    localeName: localeName,
    onDateChanged: onDateChanged,
    onCleared: endDate != null ? onCleared : null,
    firstDate: firstDate,
    suggestedDate: recurrence.nextOccurrenceAfter(minimumDate),
    placeholder: tr.addEndDate,
    icon: Icons.event_busy_rounded,
  );
}
