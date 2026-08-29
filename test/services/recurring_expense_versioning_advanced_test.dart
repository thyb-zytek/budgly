import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/services/calculators/recurring_expense_versioning.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const versioning = RecurringExpenseVersioning();

  Expense buildExpense({
    String id = 'expense-1',
    String accountId = 'account-1',
    String categoryId = 'category-1',
    String name = 'Rent',
    double amount = 900,
    DateTime? debitDate,
    RecurrenceType recurrence = RecurrenceType.monthly,
    int recurrenceAnchorDay = 31,
    List<String> debitedOccurrences = const [],
    bool isDebited = false,
  }) {
    return Expense(
      id: id,
      accountId: accountId,
      categoryId: categoryId,
      name: name,
      amount: amount,
      debitDate: debitDate ?? DateTime(2026, 1, 31),
      recurrence: recurrence,
      recurrenceAnchorDay: recurrenceAnchorDay,
      debitedOccurrences: debitedOccurrences,
      isDebited: isDebited,
    );
  }

  group('RecurringExpenseVersioning.split', () {
    test('throws for non-recurring expense', () {
      final original = buildExpense(
        recurrence: RecurrenceType.none,
        debitDate: DateTime(2026, 1, 15),
      );

      expect(
        () => versioning.split(
          original: original,
          updated: original.copyWith(amount: 1000),
          effectiveDate: DateTime(2026, 3, 15),
        ),
        throwsArgumentError,
      );
    });

    test('throws for null id', () {
      final original = Expense(
        accountId: 'account-1',
        categoryId: 'category-1',
        name: 'Rent',
        amount: 900,
        debitDate: DateTime(2026, 1, 31),
        recurrence: RecurrenceType.monthly,
        recurrenceAnchorDay: 31,
      );

      expect(
        () => versioning.split(
          original: original,
          updated: original.copyWith(amount: 1000),
          effectiveDate: DateTime(2026, 3, 15),
        ),
        throwsArgumentError,
      );
    });

    test('throws when effective date is before debit date', () {
      final original = buildExpense(debitDate: DateTime(2026, 3, 15));

      expect(
        () => versioning.split(
          original: original,
          updated: original.copyWith(amount: 1000),
          effectiveDate: DateTime(2026, 3, 14),
        ),
        throwsArgumentError,
      );
    });

    test('same-day edit returns updated as next with same id', () {
      final original = buildExpense();
      final result = versioning.split(
        original: original,
        updated: original.copyWith(amount: 1000),
        effectiveDate: original.debitDate,
      );

      expect(result.next.id, original.id);
      expect(result.next.amount, 1000);
      expect(result.next.recurrenceAnchorDay, 31);
    });

    test('same-day edit keeps previous unchanged', () {
      final original = buildExpense();
      final result = versioning.split(
        original: original,
        updated: original.copyWith(amount: 1000),
        effectiveDate: original.debitDate,
      );

      expect(result.previous.id, original.id);
      expect(result.previous.amount, 900);
      expect(result.previous.endDate, isNull);
    });

    test('split transfers debited occurrences correctly', () {
      final original = buildExpense(
        debitedOccurrences: ['2026-01-31', '2026-02-28', '2026-03-31'],
      );

      final result = versioning.split(
        original: original,
        updated: original.copyWith(amount: 1000),
        effectiveDate: DateTime(2026, 3, 31),
      );

      expect(result.previous.debitedOccurrences, ['2026-01-31', '2026-02-28']);
      expect(result.next.debitedOccurrences, ['2026-03-31']);
    });

    test('split sets endDate on previous to day before effective', () {
      final original = buildExpense();
      final result = versioning.split(
        original: original,
        updated: original.copyWith(amount: 1000),
        effectiveDate: DateTime(2026, 3, 31),
      );

      expect(result.previous.endDate, DateTime(2026, 3, 30));
    });

    test('split preserves recurrenceAnchorDay on next version', () {
      final original = buildExpense(recurrenceAnchorDay: 28);
      final result = versioning.split(
        original: original,
        updated: original.copyWith(amount: 1000),
        effectiveDate: DateTime(2026, 2, 28),
      );

      expect(result.next.recurrenceAnchorDay, 28);
    });

    test('split sets debitDate on next to effectiveDate', () {
      final original = buildExpense();
      final result = versioning.split(
        original: original,
        updated: original.copyWith(amount: 1000),
        effectiveDate: DateTime(2026, 4, 30),
      );

      expect(result.next.debitDate, DateTime(2026, 4, 30));
    });

    test('all debited occurrences before effective go to previous', () {
      final original = buildExpense(
        debitedOccurrences: ['2026-01-31', '2026-02-28'],
      );

      final result = versioning.split(
        original: original,
        updated: original.copyWith(amount: 1000),
        effectiveDate: DateTime(2026, 3, 31),
      );

      expect(result.previous.debitedOccurrences, ['2026-01-31', '2026-02-28']);
      expect(result.next.debitedOccurrences, isEmpty);
    });

    test('no debited occurrences results in empty lists', () {
      final original = buildExpense();

      final result = versioning.split(
        original: original,
        updated: original.copyWith(amount: 1000),
        effectiveDate: DateTime(2026, 3, 31),
      );

      expect(result.previous.debitedOccurrences, isEmpty);
      expect(result.next.debitedOccurrences, isEmpty);
    });

    test('next version carries over updated fields', () {
      final original = buildExpense();
      final result = versioning.split(
        original: original,
        updated: original.copyWith(
          amount: 1500,
          name: 'New Rent',
          categoryId: 'new-cat',
          accountId: 'new-acc',
        ),
        effectiveDate: DateTime(2026, 3, 31),
      );

      expect(result.next.amount, 1500);
      expect(result.next.name, 'New Rent');
      expect(result.next.categoryId, 'new-cat');
      expect(result.next.accountId, 'new-acc');
    });

    test('next version gets the updated recurrence type', () {
      final original = buildExpense(recurrence: RecurrenceType.monthly);
      final result = versioning.split(
        original: original,
        updated: original.copyWith(recurrence: RecurrenceType.bimonthly),
        effectiveDate: DateTime(2026, 3, 31),
      );

      expect(result.next.recurrence, RecurrenceType.bimonthly);
    });

    test('next version gets the updated endDate', () {
      final original = buildExpense();
      final result = versioning.split(
        original: original,
        updated: original.copyWith(endDate: DateTime(2027, 12, 31)),
        effectiveDate: DateTime(2026, 3, 31),
      );

      expect(result.next.endDate, DateTime(2027, 12, 31));
    });

    test('effective date exactly on next occurrence date', () {
      final original = buildExpense(
        debitDate: DateTime(2026, 1, 15),
        recurrenceAnchorDay: 15,
      );

      final result = versioning.split(
        original: original,
        updated: original.copyWith(amount: 500),
        effectiveDate: DateTime(2026, 2, 15),
      );

      expect(result.previous.endDate, DateTime(2026, 2, 14));
      expect(result.next.debitDate, DateTime(2026, 2, 15));
    });
  });
}
