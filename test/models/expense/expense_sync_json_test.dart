import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/builders.dart';

void main() {
  test('expense JSON round trip preserves fields required by the offline queue', () {
    final expense = Fixtures.expense(
      id: 'e1',
      accountId: 'a1',
      categoryId: 'c1',
      amount: 123.45,
      debitDate: DateTime(2026, 3, 15, 10, 30),
      endDate: DateTime(2026, 12, 31),
      recurrence: RecurrenceType.monthly,
      recurrenceAnchorDay: 15,
      isDebited: true,
      debitedOccurrences: const ['2026-03-15', '2026-04-15'],
    );

    final restored = Expense.fromJson(expense.toJson());

    expect(restored.id, expense.id);
    expect(restored.accountId, expense.accountId);
    expect(restored.categoryId, expense.categoryId);
    expect(restored.amount, expense.amount);
    expect(restored.debitDate, expense.debitDate);
    expect(restored.endDate, expense.endDate);
    expect(restored.recurrence, expense.recurrence);
    expect(restored.recurrenceAnchorDay, expense.recurrenceAnchorDay);
    expect(restored.isDebited, expense.isDebited);
    expect(restored.debitedOccurrences, expense.debitedOccurrences);
  });
}
