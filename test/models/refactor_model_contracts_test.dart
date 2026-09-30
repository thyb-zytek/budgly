import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/category/category_icon.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/expense_occurrence_exception.dart';
import 'package:budgly/src/models/user/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('transient entities with null ids are not equal', () {
    const accountA = Account(name: 'A');
    const accountB = Account(name: 'B');
    const categoryA = Category(accountId: 'a1', name: 'Food');
    const categoryB = Category(accountId: 'a1', name: 'Groceries');
    final expenseA = Expense(
      accountId: 'a1',
      categoryId: 'c1',
      name: 'A',
      amount: 1,
      debitDate: DateTime(2026, 1, 1),
    );
    final expenseB = Expense(
      accountId: 'a1',
      categoryId: 'c1',
      name: 'B',
      amount: 1,
      debitDate: DateTime(2026, 1, 1),
    );

    expect(accountA, isNot(equals(accountB)));
    expect(categoryA, isNot(equals(categoryB)));
    expect(expenseA, isNot(equals(expenseB)));
  });

  test('model collections are defensively immutable', () {
    final icon = CategoryIcon(
      iconName: 'test',
      iconCode: 1,
      iconPack: 'MaterialIcons',
      labels: {'fr': 'Test'},
    );
    final expense = Expense(
      accountId: 'a1',
      categoryId: 'c1',
      name: 'Expense',
      amount: 1,
      debitDate: DateTime(2026, 1, 1),
      debitedOccurrences: ['2026-01-01'],
    );
    final profile = UserProfile(
      id: 'u1',
      email: 'u@example.com',
      fullName: 'User',
      accounts: [const Account(id: 'a1', name: 'Main')],
    );

    expect(() => icon.labels['en'] = 'Test', throwsUnsupportedError);
    expect(
      () => expense.debitedOccurrences.add('2026-01-02'),
      throwsUnsupportedError,
    );
    expect(
      () => profile.accounts.add(const Account(id: 'a2', name: 'Other')),
      throwsUnsupportedError,
    );
  });

  test('occurrence exception exposes a validated source date', () {
    const valid = ExpenseOccurrenceException(key: 'expense-1@2026-03-15');
    const invalid = ExpenseOccurrenceException(
      key: 'expense-1@2026-03-15T12:00:00',
    );

    expect(valid.sourceDate, DateTime(2026, 3, 15));
    expect(invalid.sourceDate, isNull);
  });
}
