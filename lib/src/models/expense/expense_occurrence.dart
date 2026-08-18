import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/recurrence.dart';

/// A concrete occurrence of an expense inside a period.
///
/// One-off expenses produce a single occurrence at their debit date, while
/// recurring expenses are expanded on the fly from their anchor date
/// (`Expense.debitDate`) so every period — past, current or future — is
/// populated automatically, without duplicating documents.
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

  /// Stable identity used as list key: expense id + occurrence date.
  String get key => '$id@${Expense.isoDate(date)}';
}

/// Expands [expense] into the occurrences that fall inside [period].
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

/// Expands [expense] into the occurrences whose date falls between [from] and
/// [to] (inclusive). Unlike [expandExpenseOccurrences], this walks the
/// recurrence only once whatever the size of the window.
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

  final anchorDay = expense.debitDate.day;
  var date = expense.recurrence.firstOccurrenceOnOrAfter(
    expense.debitDate,
    from,
  );
  while (!date.isAfter(to)) {
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
