import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/budget/calendar_date_range.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/models/expense/expense_occurrence_exception.dart';

class ExpenseOccurrence {
  final Expense expense;
  final DateTime date;
  final bool isDebited;
  final DateTime? sourceDate;

  const ExpenseOccurrence({
    required this.expense,
    required this.date,
    required this.isDebited,
    this.sourceDate,
  });

  String get id => expense.id ?? '';
  String get categoryId => expense.categoryId;
  String get name => expense.name;
  double get amount => expense.amount;
  RecurrenceType get recurrence => expense.recurrence;

  String get key => '$id@${Expense.isoDate(sourceDate ?? date)}';

  bool get isException => sourceDate != null;

  // Pure value object (no server id of its own): identity follows every
  // field, same convention as Period/CategoryIcon. `expense ==` itself
  // compares by Expense.id (see Expense), so this stays cheap.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExpenseOccurrence &&
        other.expense == expense &&
        other.date == date &&
        other.isDebited == isDebited &&
        other.sourceDate == sourceDate;
  }

  @override
  int get hashCode => Object.hash(expense, date, isDebited, sourceDate);
}

extension on Expense {
  bool recurrenceOccursOn(DateTime target) {
    // A recurrence starts at debitDate. Moving the calendar cursor backwards
    // must never manufacture an occurrence before that first occurrence.
    final first = recurrence.firstOccurrenceOnOrAfter(
      debitDate,
      target,
      anchorDay: recurrenceAnchorDay,
    );
    return Expense.isoDate(first) == Expense.isoDate(target) &&
        (endDateExclusive == null || target.isBefore(endDateExclusive!));
  }
}

List<ExpenseOccurrence> expandExpenseOccurrences(
  Expense expense,
  Period period,
) {
  return expandExpenseOccurrencesBetween(expense, period.range);
}

List<ExpenseOccurrence> expandExpenseOccurrencesBetween(
  Expense expense,
  CalendarDateRange range,
) {
  final result = <ExpenseOccurrence>[];

  if (!expense.isRecurring) {
    if (range.contains(expense.debitDate)) {
      result.add(
        ExpenseOccurrence(
          expense: expense,
          date: expense.debitDate,
          isDebited: expense.isDebited,
        ),
      );
    }
    return result;
  }

  final endExclusive = expense.endDateExclusive;
  if (endExclusive != null && !endExclusive.isAfter(range.start)) {
    // A date exception may move an otherwise historical occurrence into the
    // requested range, so continue and apply exceptions below.
  }
  final effectiveEndExclusive =
      endExclusive == null || endExclusive.isAfter(range.endExclusive)
      ? range.endExclusive
      : endExclusive;

  final anchorDay = expense.recurrenceAnchorDay;
  var date = expense.recurrence.firstOccurrenceOnOrAfter(
    expense.debitDate,
    range.start,
    anchorDay: anchorDay,
  );
  final projectedSourceKeys = <String>{};
  while (date.isBefore(effectiveEndExclusive)) {
    final exception = expense.exceptionAt(date);
    final effectiveDate = exception?.debitDate ?? date;
    if (exception?.deleted != true && range.contains(effectiveDate)) {
      final effectiveExpense = _applyException(expense, exception);
      result.add(
        ExpenseOccurrence(
          expense: effectiveExpense,
          date: effectiveDate,
          isDebited: exception?.isDebited ?? expense.isDebitedAt(date),
          sourceDate: exception == null ? null : date,
        ),
      );
      projectedSourceKeys.add(Expense.isoDate(date));
    }
    final next = expense.recurrence.nextOccurrenceAfter(
      date,
      anchorDay: anchorDay,
    );
    if (!next.isAfter(date)) break;
    date = next;
  }

  // Date overrides may move an occurrence outside its original month. Those
  // exceptions must still be projected into the destination range.
  for (final exception in expense.occurrenceExceptions) {
    if (exception.deleted || exception.debitDate == null) continue;
    if (projectedSourceKeys.contains(_exceptionSourceDate(exception))) continue;
    if (!range.contains(exception.debitDate!)) continue;
    final sourceDate = exception.sourceDate;
    if (sourceDate == null || !expense.recurrenceOccursOn(sourceDate)) continue;
    result.add(
      ExpenseOccurrence(
        expense: _applyException(expense, exception),
        date: exception.debitDate!,
        isDebited: exception.isDebited ?? expense.isDebitedAt(sourceDate),
        sourceDate: sourceDate,
      ),
    );
  }

  return result;
}

Expense _applyException(
  Expense expense,
  ExpenseOccurrenceException? exception,
) {
  if (exception == null) return expense;
  return expense.copyWith(
    amount: exception.amount,
    name: exception.name,
    categoryId: exception.categoryId,
  );
}

String _exceptionSourceDate(ExpenseOccurrenceException exception) =>
    exception.key.substring(exception.key.lastIndexOf('@') + 1);
