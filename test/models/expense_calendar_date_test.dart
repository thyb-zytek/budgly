import 'package:budgly/src/models/expense/expense.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('business dates ignore time of day', () {
    final expense = Expense(
      accountId: 'account',
      categoryId: 'category',
      name: 'Test',
      amount: 10,
      debitDate: DateTime(2026, 9, 30, 18, 30),
      endDate: DateTime(2026, 10, 15, 23, 45),
    );

    expect(expense.debitDate, DateTime(2026, 9, 30));
    expect(expense.endDate, DateTime(2026, 10, 15));
  });
}
