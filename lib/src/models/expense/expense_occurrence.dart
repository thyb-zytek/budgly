import 'package:budgly/src/models/budget/period.dart';
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

  String get key =>
      '$id@${Expense.isoDate(sourceDate ?? date)}';

  bool get isException => sourceDate != null;
}

extension on Expense {
  bool recurrenceOccursOn(DateTime target) {
    final first = recurrence.firstOccurrenceOnOrAfter(
      debitDate,
      target,
      anchorDay: recurrenceAnchorDay,
    );
    return Expense.isoDate(first) == Expense.isoDate(target) &&
        (endOfEndDate == null || !target.isAfter(endOfEndDate!));
  }
}

List<ExpenseOccurrence> expandExpenseOccurrences(
  Expense expense,
  Period period,
) {
  return expandExpenseOccurrencesBetween(
    expense,
    period.startOfMonth,
    period.endOfMonth,
  );
}

List<ExpenseOccurrence> expandExpenseOccurrencesBetween(
  Expense expense,
  DateTime from,
  DateTime to,
) {
  final result = <ExpenseOccurrence>[];

  if (!expense.isRecurring) {
    if (!expense.debitDate.isBefore(from) && !expense.debitDate.isAfter(to)) {
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

  final endOfEndDate = expense.endOfEndDate;
  if (endOfEndDate != null && endOfEndDate.isBefore(from)) {
    // An exception can move an otherwise historical occurrence into the
    // requested window, so do not return before applying exceptions.
  }
  final effectiveTo = endOfEndDate != null && endOfEndDate.isBefore(to)
      ? endOfEndDate
      : to;

  final anchorDay = expense.recurrenceAnchorDay;
  var date = expense.recurrence.firstOccurrenceOnOrAfter(
    expense.debitDate,
    from,
    anchorDay: expense.recurrenceAnchorDay,
  );
  final projectedSourceKeys = <String>{};
  while (!date.isAfter(effectiveTo)) {
    final exception = expense.exceptionAt(date);
    final effectiveDate = exception?.debitDate ?? date;
    if (exception?.deleted != true &&
        !effectiveDate.isBefore(from) &&
        !effectiveDate.isAfter(to)) {
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
  // exceptions must still be projected into the destination period.
  for (final exception in expense.occurrenceExceptions) {
    if (exception.deleted || exception.debitDate == null) continue;
    if (projectedSourceKeys.contains(_exceptionSourceDate(exception))) continue;
    if (exception.debitDate!.isBefore(from) || exception.debitDate!.isAfter(to)) {
      continue;
    }
    final sourceDate = _parseExceptionSourceDate(exception);
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



Expense _applyException(Expense expense, ExpenseOccurrenceException? exception) {
  if (exception == null) return expense;
  return expense.copyWith(
    amount: exception.amount,
    name: exception.name,
    categoryId: exception.categoryId,
  );
}

String _exceptionSourceDate(ExpenseOccurrenceException exception) =>
    exception.key.substring(exception.key.lastIndexOf('@') + 1);

DateTime? _parseExceptionSourceDate(ExpenseOccurrenceException exception) {
  final raw = _exceptionSourceDate(exception);
  final parts = raw.split('-');
  if (parts.length != 3) return null;
  return DateTime.tryParse(raw);
}
