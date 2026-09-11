import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/services/providers/firestore/expense_page.dart';
import 'package:budgly/src/services/providers/firestore/expenses.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// In-memory [ExpenseFirestore] that simulates expenses already persisted on
/// the server. Mutations ([ExpenseFirestore.create], [ExpenseFirestore.update],
/// [ExpenseFirestore.delete]) are reflected back into
/// [RefreshAwareExpenseFirestore.serverExpenses] so a later period query
/// returns the post-mutation document, matching Firestore.
class RefreshAwareExpenseFirestore extends ExpenseFirestore {
  final List<Expense> serverExpenses = [];

  @override
  Future<Expense?> create(Expense expense) async {
    serverExpenses.removeWhere((item) => item.id == expense.id);
    serverExpenses.add(expense);
    return expense.copyWith(id: expense.id);
  }

  @override
  Future<List<Expense>> listByAccountAndPeriod(
    String accountId,
    Period period, {
    String? categoryId,
    Source source = Source.server,
  }) async {
    return serverExpenses.where((expense) {
      if (expense.accountId != accountId) return false;
      if (categoryId != null && expense.categoryId != categoryId) return false;
      if (expense.isRecurring) {
        final endDate = expense.endOfEndDate;
        return !expense.debitDate.isAfter(period.endOfMonth) &&
            (endDate == null || !endDate.isBefore(period.startOfMonth));
      }
      return period.contains(expense.debitDate);
    }).toList();
  }

  @override
  Future<ExpensePage> listByCategoryAndPeriodPage(
    String accountId,
    String categoryId,
    Period period, {
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    bool includeRecurring = true,
  }) async {
    final expenses = serverExpenses.where((expense) {
      if (expense.accountId != accountId) return false;
      if (expense.categoryId != categoryId) return false;
      if (expense.isRecurring) {
        final endDate = expense.endOfEndDate;
        return !expense.debitDate.isAfter(period.endOfMonth) &&
            (endDate == null || !endDate.isBefore(period.startOfMonth));
      }
      return period.contains(expense.debitDate);
    }).toList();
    return ExpensePage(expenses: expenses, cursor: null, hasMore: false);
  }

  @override
  Future<List<Expense>> listByAccountId(
    String accountId, {
    Source source = Source.server,
  }) async {
    return serverExpenses
        .where((expense) => expense.accountId == accountId)
        .toList();
  }

  @override
  Future<bool> update(Expense expense) async {
    for (var i = 0; i < serverExpenses.length; i++) {
      if (serverExpenses[i].id == expense.id) {
        serverExpenses[i] = expense;
        return true;
      }
    }
    serverExpenses.add(expense);
    return true;
  }

  @override
  Future<bool> delete(String expenseId) async {
    serverExpenses.removeWhere((expense) => expense.id == expenseId);
    return true;
  }
}