import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/recurrence.dart';

class ExpenseOccurrence {
  final Expense expense;
  final DateTime date;
  final bool isDebited;

  const ExpenseOccurrence({
    required this.expense,
    required this.date,
    required this.isDebited,
  });

  String get id => expense.id ?? '';
  String get categoryId => expense.categoryId;
  String get name => expense.name;
  double get amount => expense.amount;
  RecurrenceType get recurrence => expense.recurrence;

  String get key => '$id@${Expense.isoDate(date)}';
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
    return result;
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
  while (!date.isAfter(effectiveTo)) {
    if (!date.isBefore(from)) {
      result.add(
        ExpenseOccurrence(
          expense: expense,
          date: date,
          isDebited: expense.isDebitedAt(date),
        ),
      );
    }
    final next = expense.recurrence.nextOccurrenceAfter(
      date,
      anchorDay: anchorDay,
    );
    if (!next.isAfter(date)) break;
    date = next;
  }

  return result;
}

