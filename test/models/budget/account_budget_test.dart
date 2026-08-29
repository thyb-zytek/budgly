import 'package:budgly/src/models/budget/account_budget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccountBudget.fromMap', () {
    test('parses all fields including a Firestore Timestamp', () {
      final updatedAt = DateTime(2026, 3, 15);
      final budget = AccountBudget.fromMap('budget-1', {
        'accountId': 'acc-1',
        'year': 2026,
        'month': 3,
        'revenue': 2500,
        'updatedAt': Timestamp.fromDate(updatedAt),
      });

      expect(budget.id, 'budget-1');
      expect(budget.accountId, 'acc-1');
      expect(budget.year, 2026);
      expect(budget.month, 3);
      expect(budget.revenue, 2500.0);
      expect(budget.updatedAt, updatedAt);
    });

    test('defaults revenue to 0 when absent', () {
      final budget = AccountBudget.fromMap('budget-1', {
        'accountId': 'acc-1',
        'year': 2026,
        'month': 3,
      });
      expect(budget.revenue, 0);
    });

    test('leaves updatedAt null when absent', () {
      final budget = AccountBudget.fromMap('budget-1', {
        'accountId': 'acc-1',
        'year': 2026,
        'month': 3,
        'revenue': 100,
      });
      expect(budget.updatedAt, isNull);
    });

    test('converts an integer revenue to a double', () {
      final budget = AccountBudget.fromMap('budget-1', {
        'accountId': 'acc-1',
        'year': 2026,
        'month': 3,
        'revenue': 100,
      });
      expect(budget.revenue, isA<double>());
      expect(budget.revenue, 100.0);
    });
  });

  group('AccountBudget.toMap', () {
    test('serializes the scalar fields', () {
      const budget = AccountBudget(
        id: 'budget-1',
        accountId: 'acc-1',
        year: 2026,
        month: 3,
        revenue: 2500,
      );
      final map = budget.toMap();
      expect(map['accountId'], 'acc-1');
      expect(map['year'], 2026);
      expect(map['month'], 3);
      expect(map['revenue'], 2500.0);
    });

    test('does not include the id (Firestore document id is separate)', () {
      const budget = AccountBudget(
        id: 'budget-1',
        accountId: 'acc-1',
        year: 2026,
        month: 3,
        revenue: 2500,
      );
      expect(budget.toMap().containsKey('id'), isFalse);
    });
  });

  group('AccountBudget.copyWith', () {
    const base = AccountBudget(
      id: 'budget-1',
      accountId: 'acc-1',
      year: 2026,
      month: 3,
      revenue: 2500,
    );

    test('overrides revenue when passed', () {
      expect(base.copyWith(revenue: 3000).revenue, 3000);
    });

    test('keeps year/month/accountId unchanged (not overridable)', () {
      final result = base.copyWith(revenue: 3000, id: 'budget-2');
      expect(result.year, base.year);
      expect(result.month, base.month);
      expect(result.accountId, base.accountId);
    });

    test('keeps the original id when none is passed', () {
      expect(base.copyWith(revenue: 10).id, base.id);
    });
  });
}
