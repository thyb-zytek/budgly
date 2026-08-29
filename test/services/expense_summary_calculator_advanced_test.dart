import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/expense_occurrence.dart';
import 'package:budgly/src/services/calculators/expense_summary_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calculator = ExpenseSummaryCalculator();

  final food = Category(id: 'food', accountId: 'account', name: 'Food');
  final transport = Category(id: 'transport', accountId: 'account', name: 'Transport');

  ExpenseOccurrence occurrence({
    required double amount,
    required bool debited,
    String categoryId = 'food',
    String expenseId = 'exp-1',
  }) {
    final expense = Expense(
      id: expenseId,
      accountId: 'account',
      categoryId: categoryId,
      name: 'Expense',
      amount: amount,
      debitDate: DateTime(2026, 8, 1),
      isDebited: debited,
    );
    return ExpenseOccurrence(
      expense: expense,
      date: expense.debitDate,
      isDebited: debited,
    );
  }

  group('ExpenseSummaryCalculator.summarize', () {
    test('all debited', () {
      final result = calculator.summarize(
        category: food,
        occurrences: [
          occurrence(amount: 10, debited: true),
          occurrence(amount: 20, debited: true),
        ],
      );
      expect(result.total, 30);
      expect(result.debited, 30);
      expect(result.undebited, 0);
      expect(result.undebitedCount, 0);
    });

    test('all undebited', () {
      final result = calculator.summarize(
        category: food,
        occurrences: [
          occurrence(amount: 10, debited: false),
          occurrence(amount: 20, debited: false),
        ],
      );
      expect(result.total, 30);
      expect(result.debited, 0);
      expect(result.undebited, 30);
      expect(result.undebitedCount, 2);
    });

    test('empty occurrences', () {
      final result = calculator.summarize(
        category: food,
        occurrences: [],
      );
      expect(result.total, 0);
      expect(result.debited, 0);
      expect(result.undebited, 0);
      expect(result.undebitedCount, 0);
    });

    test('single occurrence debited', () {
      final result = calculator.summarize(
        category: food,
        occurrences: [occurrence(amount: 42.5, debited: true)],
      );
      expect(result.total, 42.5);
      expect(result.debited, 42.5);
      expect(result.undebited, 0);
      expect(result.undebitedCount, 0);
    });
  });

  group('ExpenseSummaryCalculator.summarizeByCategory', () {
    test('groups by category and sorts by total descending', () {
      final occurrences = [
        occurrence(amount: 10, debited: true, categoryId: 'food', expenseId: 'e1'),
        occurrence(amount: 30, debited: false, categoryId: 'transport', expenseId: 'e2'),
        occurrence(amount: 20, debited: true, categoryId: 'food', expenseId: 'e3'),
      ];

      final results = calculator.summarizeByCategory(
        occurrences: occurrences,
        resolveCategory: (id) {
          if (id == 'food') return food;
          if (id == 'transport') return transport;
          return null;
        },
      );

      expect(results, hasLength(2));
      expect(results[0].category.id, 'food');
      expect(results[0].total, 30);
      expect(results[1].category.id, 'transport');
      expect(results[1].total, 30);
    });

    test('skips categories that cannot be resolved', () {
      final occurrences = [
        occurrence(amount: 10, debited: true, categoryId: 'food', expenseId: 'e1'),
        occurrence(amount: 20, debited: false, categoryId: 'unknown', expenseId: 'e2'),
      ];

      final results = calculator.summarizeByCategory(
        occurrences: occurrences,
        resolveCategory: (id) => id == 'food' ? food : null,
      );

      expect(results, hasLength(1));
      expect(results.first.category.id, 'food');
    });

    test('empty occurrences returns empty list', () {
      final results = calculator.summarizeByCategory(
        occurrences: [],
        resolveCategory: (_) => food,
      );
      expect(results, isEmpty);
    });
  });
}
