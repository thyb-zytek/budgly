import 'package:budgly/src/models/expense/expense_editing_data.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ExpenseEditingData build({
    DateTime? debitDate,
    DateTime? endDate,
    RecurrenceType recurrence = RecurrenceType.none,
  }) {
    return ExpenseEditingData(
      nameController: TextEditingController(),
      amountController: TextEditingController(),
      debitDate: debitDate,
      endDate: endDate,
      recurrence: recurrence,
    );
  }

  group('ExpenseEditingData.effectiveEndDate', () {
    test('is null for a non-recurring expense even if an end date is set', () {
      final data = build(
        recurrence: RecurrenceType.none,
        endDate: DateTime(2026, 12, 31),
      );
      expect(data.effectiveEndDate, isNull);
    });

    test('returns the end date for a recurring expense', () {
      final endDate = DateTime(2026, 12, 31);
      final data = build(recurrence: RecurrenceType.monthly, endDate: endDate);
      expect(data.effectiveEndDate, endDate);
    });

    test('is null for a recurring expense with no end date set', () {
      final data = build(recurrence: RecurrenceType.monthly);
      expect(data.effectiveEndDate, isNull);
    });
  });

  group('ExpenseEditingData.hasEndDateBeforeDebitDate', () {
    test('is false for a non-recurring expense regardless of dates', () {
      final data = build(
        recurrence: RecurrenceType.none,
        debitDate: DateTime(2026, 6, 15),
        endDate: DateTime(2026, 1, 1),
      );
      expect(data.hasEndDateBeforeDebitDate, isFalse);
    });

    test('is false when there is no end date', () {
      final data = build(
        recurrence: RecurrenceType.monthly,
        debitDate: DateTime(2026, 6, 15),
      );
      expect(data.hasEndDateBeforeDebitDate, isFalse);
    });

    test('is true when the end date is strictly before the debit date', () {
      final data = build(
        recurrence: RecurrenceType.monthly,
        debitDate: DateTime(2026, 6, 15),
        endDate: DateTime(2026, 6, 14),
      );
      expect(data.hasEndDateBeforeDebitDate, isTrue);
    });

    test('is false when the end date is the same day as the debit date', () {
      final data = build(
        recurrence: RecurrenceType.monthly,
        debitDate: DateTime(2026, 6, 15),
        endDate: DateTime(2026, 6, 15),
      );
      expect(data.hasEndDateBeforeDebitDate, isFalse);
    });

    test('compares dates by day only, ignoring time-of-day components', () {
      final data = build(
        recurrence: RecurrenceType.monthly,
        debitDate: DateTime(2026, 6, 15, 23, 59),
        endDate: DateTime(2026, 6, 15, 0, 1),
      );
      expect(data.hasEndDateBeforeDebitDate, isFalse);
    });

    test('is true when the end date is a full day before, even with times close together', () {
      final data = build(
        recurrence: RecurrenceType.monthly,
        debitDate: DateTime(2026, 6, 15, 0, 1),
        endDate: DateTime(2026, 6, 14, 23, 59),
      );
      expect(data.hasEndDateBeforeDebitDate, isTrue);
    });
  });

  group('ExpenseEditingData constructor', () {
    test('defaults debitDate to now when not provided', () {
      final before = DateTime.now();
      final data = ExpenseEditingData(
        nameController: TextEditingController(),
        amountController: TextEditingController(),
      );
      final after = DateTime.now();

      expect(
        data.debitDate.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(
        data.debitDate.isBefore(after.add(const Duration(seconds: 1))),
        isTrue,
      );
    });

    test('defaults recurrence to none and showAdvancedOptions to false', () {
      final data = ExpenseEditingData(
        nameController: TextEditingController(),
        amountController: TextEditingController(),
      );
      expect(data.recurrence, RecurrenceType.none);
      expect(data.showAdvancedOptions, isFalse);
    });
  });
}
