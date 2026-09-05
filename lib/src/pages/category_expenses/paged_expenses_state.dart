import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:budgly/src/models/expense/expense.dart';

/// Mutable pagination state kept outside the ViewModel orchestration code.
class PagedExpensesState {
  final List<Expense> expenses = [];
  DocumentSnapshot<Map<String, dynamic>>? cursor;
  bool hasMore = true;
  bool isLoading = false;
  bool hasLoadedFirstPage = false;

  bool contains(String? id) => expenses.any((expense) => expense.id == id);

  void append(Iterable<Expense> values) {
    final existingIds = expenses.map((expense) => expense.id).toSet();
    for (final expense in values) {
      final id = expense.id;
      if (id == null || existingIds.add(id)) {
        expenses.add(expense);
      }
    }
    sort();
  }

  void sort() {
    expenses.sort((a, b) => b.debitDate.compareTo(a.debitDate));
  }

  void replace(String? id, Expense expense) {
    if (id == null) return;
    final index = expenses.indexWhere((item) => item.id == id);
    if (index == -1) return;
    expenses[index] = expense;
    sort();
  }

  void removeById(String? id) {
    if (id == null) return;
    expenses.removeWhere((expense) => expense.id == id);
  }
}
