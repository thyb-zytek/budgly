import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/recurring_expense_version.dart';
import 'package:budgly/src/models/expense/expense_occurrence_exception.dart';

class RecurringExpenseVersioning {
  const RecurringExpenseVersioning();

  RecurringExpenseVersion split({
    required Expense original,
    required Expense updated,
    required DateTime effectiveDate,
  }) {
    if (!original.isRecurring || original.id == null) {
      throw ArgumentError('The original expense must be a persisted recurring expense');
    }

    final effectiveDay = _calendarDay(effectiveDate);
    final originalDay = _calendarDay(original.debitDate);

    if (effectiveDay.isBefore(originalDay)) {
      throw ArgumentError('The effective date cannot precede the original date');
    }

    if (effectiveDay.isAtSameMomentAs(originalDay)) {
      return RecurringExpenseVersion(
        previous: original,
        next: updated.copyWith(
          id: original.id,
          recurrenceAnchorDay: original.recurrenceAnchorDay,
          occurrenceExceptions: original.occurrenceExceptions,
        ),
      );
    }

    final effectiveKey = Expense.isoDate(effectiveDay);
    final previous = original.copyWith(
      endDate: effectiveDay.subtract(const Duration(days: 1)),
      debitedOccurrences: [
        for (final key in original.debitedOccurrences)
          if (key.compareTo(effectiveKey) < 0) key,
      ],
      occurrenceExceptions: [
        for (final exception in original.occurrenceExceptions)
          if (_exceptionDate(exception).isBefore(effectiveDay)) exception,
      ],
    );

    final next = Expense(
      accountId: updated.accountId,
      categoryId: updated.categoryId,
      name: updated.name,
      amount: updated.amount,
      debitDate: effectiveDay,
      endDate: updated.endDate,
      recurrence: updated.recurrence,
      recurrenceAnchorDay: original.recurrenceAnchorDay,
      isDebited: updated.isDebited,
      debitedOccurrences: updated.isRecurring
          ? [
              for (final key in original.debitedOccurrences)
                if (key.compareTo(effectiveKey) >= 0) key,
            ]
          : const [],
      occurrenceExceptions: [
        for (final exception in original.occurrenceExceptions)
          if (!_exceptionDate(exception).isBefore(effectiveDay)) exception,
      ],
    );

    return RecurringExpenseVersion(previous: previous, next: next);
  }

  DateTime _calendarDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}


DateTime _exceptionDate(ExpenseOccurrenceException exception) =>
    DateTime.parse(exception.key.substring(exception.key.lastIndexOf('@') + 1));
