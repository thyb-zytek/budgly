import 'package:budgly/src/models/expense/expense.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ExpensePage {
  final List<Expense> expenses;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool hasMore;

  const ExpensePage({
    required this.expenses,
    required this.cursor,
    required this.hasMore,
  });
}
