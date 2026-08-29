import 'package:budgly/src/models/expense/expense.dart';

class RecurringExpenseVersion {
  final Expense previous;
  final Expense next;

  const RecurringExpenseVersion({
    required this.previous,
    required this.next,
  });
}
