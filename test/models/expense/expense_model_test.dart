import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Expense buildExpense({
    String id = 'exp-1',
    String accountId = 'account-1',
    String categoryId = 'cat-1',
    String name = 'Netflix',
    double amount = 15.99,
    DateTime? debitDate,
    DateTime? endDate,
    RecurrenceType recurrence = RecurrenceType.none,
    int? recurrenceAnchorDay,
    bool isDebited = false,
    List<String> debitedOccurrences = const [],
  }) {
    return Expense(
      id: id,
      accountId: accountId,
      categoryId: categoryId,
      name: name,
      amount: amount,
      debitDate: debitDate ?? DateTime(2026, 1, 15),
      endDate: endDate,
      recurrence: recurrence,
      recurrenceAnchorDay: recurrenceAnchorDay,
      isDebited: isDebited,
      debitedOccurrences: debitedOccurrences,
    );
  }

  group('Expense.isoDate', () {
    test('formats date as YYYY-MM-DD with zero padding', () {
      expect(Expense.isoDate(DateTime(2026, 3, 5)), '2026-03-05');
    });

    test('pads single digit month and day', () {
      expect(Expense.isoDate(DateTime(2026, 1, 1)), '2026-01-01');
    });

    test('handles December 31', () {
      expect(Expense.isoDate(DateTime(2026, 12, 31)), '2026-12-31');
    });
  });

  group('Expense.isRecurring', () {
    test('none is not recurring', () {
      expect(buildExpense(recurrence: RecurrenceType.none).isRecurring, isFalse);
    });

    test('monthly is recurring', () {
      expect(buildExpense(recurrence: RecurrenceType.monthly).isRecurring, isTrue);
    });
  });

  group('Expense.endOfEndDate', () {
    test('null when endDate is null', () {
      expect(buildExpense().endOfEndDate, isNull);
    });

    test('returns 23:59:59.999 of endDate', () {
      final expense = buildExpense(endDate: DateTime(2026, 6, 15));
      final result = expense.endOfEndDate!;
      expect(result.year, 2026);
      expect(result.month, 6);
      expect(result.day, 15);
      expect(result.hour, 23);
      expect(result.minute, 59);
      expect(result.second, 59);
      expect(result.millisecond, 999);
    });
  });

  group('Expense.isDebitedAt', () {
    test('non-recurring returns isDebited regardless of date', () {
      final expense = buildExpense(isDebited: true);
      expect(expense.isDebitedAt(DateTime(2026, 1, 1)), isTrue);
    });

    test('recurring checks debitedOccurrences', () {
      final expense = buildExpense(
        recurrence: RecurrenceType.monthly,
        debitedOccurrences: ['2026-01-15', '2026-03-15'],
      );

      expect(expense.isDebitedAt(DateTime(2026, 1, 15)), isTrue);
      expect(expense.isDebitedAt(DateTime(2026, 2, 15)), isFalse);
      expect(expense.isDebitedAt(DateTime(2026, 3, 15)), isTrue);
    });
  });

  group('Expense.copyWith', () {
    test('copies with new values', () {
      final expense = buildExpense();
      final copy = expense.copyWith(
        name: 'New Name',
        amount: 99.99,
      );
      expect(copy.name, 'New Name');
      expect(copy.amount, 99.99);
      expect(copy.id, expense.id);
    });

    test('clearEndDate sets endDate to null', () {
      final expense = buildExpense(endDate: DateTime(2026, 12, 31));
      final copy = expense.copyWith(clearEndDate: true);
      expect(copy.endDate, isNull);
    });

    test('without clearEndDate preserves endDate', () {
      final expense = buildExpense(endDate: DateTime(2026, 12, 31));
      final copy = expense.copyWith();
      expect(copy.endDate, DateTime(2026, 12, 31));
    });

    test('preserves all original values when no changes', () {
      final expense = buildExpense(
        debitDate: DateTime(2026, 6, 15),
        endDate: DateTime(2026, 12, 31),
        recurrence: RecurrenceType.monthly,
        recurrenceAnchorDay: 28,
      );
      final copy = expense.copyWith();
      expect(copy.debitDate, expense.debitDate);
      expect(copy.endDate, expense.endDate);
      expect(copy.recurrence, expense.recurrence);
      expect(copy.recurrenceAnchorDay, expense.recurrenceAnchorDay);
    });
  });

  group('Expense constructor defaults', () {
    test('recurrenceAnchorDay defaults to debitDate.day', () {
      final expense = buildExpense(debitDate: DateTime(2026, 3, 15));
      expect(expense.recurrenceAnchorDay, 15);
    });

    test('isDebited defaults to false', () {
      expect(buildExpense().isDebited, isFalse);
    });

    test('debitedOccurrences defaults to empty', () {
      expect(buildExpense().debitedOccurrences, isEmpty);
    });
  });

  group('Expense.fromMap', () {
    test('parses full map', () {
      final map = {
        'accountId': 'acc-1',
        'categoryId': 'cat-1',
        'name': 'Netflix',
        'amount': 15.99,
        'debitDate': Timestamp.fromDate(DateTime(2026, 1, 15)),
        'endDate': Timestamp.fromDate(DateTime(2026, 12, 31)),
        'isDebited': true,
        'debitedOccurrences': ['2026-01-15'],
        'recurrence': 'monthly',
        'recurrenceAnchorDay': 15,
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
        'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 2)),
      };

      final expense = Expense.fromMap('exp-1', map);
      expect(expense.id, 'exp-1');
      expect(expense.accountId, 'acc-1');
      expect(expense.name, 'Netflix');
      expect(expense.amount, 15.99);
      expect(expense.isDebited, isTrue);
      expect(expense.recurrence, RecurrenceType.monthly);
      expect(expense.recurrenceAnchorDay, 15);
      expect(expense.debitedOccurrences, ['2026-01-15']);
    });

    test('handles null name as empty string', () {
      final map = {
        'accountId': 'acc-1',
        'categoryId': 'cat-1',
        'debitDate': Timestamp.fromDate(DateTime(2026, 1, 15)),
        'isDebited': false,
      };

      final expense = Expense.fromMap('exp-1', map);
      expect(expense.name, '');
    });

    test('handles null amount as 0.0', () {
      final map = {
        'accountId': 'acc-1',
        'categoryId': 'cat-1',
        'debitDate': Timestamp.fromDate(DateTime(2026, 1, 15)),
        'isDebited': false,
      };

      final expense = Expense.fromMap('exp-1', map);
      expect(expense.amount, 0.0);
    });

    test('handles non-list debitedOccurrences as empty', () {
      final map = {
        'accountId': 'acc-1',
        'categoryId': 'cat-1',
        'debitDate': Timestamp.fromDate(DateTime(2026, 1, 15)),
        'isDebited': false,
        'debitedOccurrences': 'invalid',
      };

      final expense = Expense.fromMap('exp-1', map);
      expect(expense.debitedOccurrences, isEmpty);
    });

    test('handles null endDate', () {
      final map = {
        'accountId': 'acc-1',
        'categoryId': 'cat-1',
        'debitDate': Timestamp.fromDate(DateTime(2026, 1, 15)),
        'isDebited': false,
      };

      final expense = Expense.fromMap('exp-1', map);
      expect(expense.endDate, isNull);
    });

    test('handles null recurrence as none', () {
      final map = {
        'accountId': 'acc-1',
        'categoryId': 'cat-1',
        'debitDate': Timestamp.fromDate(DateTime(2026, 1, 15)),
        'isDebited': false,
      };

      final expense = Expense.fromMap('exp-1', map);
      expect(expense.recurrence, RecurrenceType.none);
    });
  });
}
