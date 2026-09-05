import 'package:budgly/src/models/budget/account_budget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccountBudget advanced', () {
    group('fromMap edge cases', () {
      test('handles zero revenue', () {
        final budget = AccountBudget.fromMap('b1', {
          'accountId': 'a1',
          'year': 2026,
          'month': 6,
          'revenue': 0,
        });
        expect(budget.revenue, 0.0);
      });

      test('handles negative revenue', () {
        final budget = AccountBudget.fromMap('b1', {
          'accountId': 'a1',
          'year': 2026,
          'month': 6,
          'revenue': -100,
        });
        expect(budget.revenue, -100.0);
      });

      test('handles large revenue', () {
        final budget = AccountBudget.fromMap('b1', {
          'accountId': 'a1',
          'year': 2026,
          'month': 6,
          'revenue': 999999.99,
        });
        expect(budget.revenue, 999999.99);
      });

      test('null revenue defaults to 0', () {
        final budget = AccountBudget.fromMap('b1', {
          'accountId': 'a1',
          'year': 2026,
          'month': 6,
        });
        expect(budget.revenue, 0);
      });
    });

    group('toMap', () {
      test('does not include id', () {
        const budget = AccountBudget(
          id: 'b1',
          accountId: 'a1',
          year: 2026,
          month: 6,
          revenue: 1000,
        );
        expect(budget.toMap().containsKey('id'), isFalse);
      });

      test('includes server timestamp for updatedAt', () {
        const budget = AccountBudget(
          accountId: 'a1',
          year: 2026,
          month: 6,
          revenue: 1000,
        );
        final map = budget.toMap();
        expect(map['updatedAt'], isA<FieldValue>());
      });
    });

    group('copyWith', () {
      test('overrides id', () {
        const budget = AccountBudget(
          accountId: 'a1',
          year: 2026,
          month: 6,
          revenue: 1000,
        );
        final copy = budget.copyWith(id: 'new-id');
        expect(copy.id, 'new-id');
      });

      test('overrides revenue', () {
        const budget = AccountBudget(
          accountId: 'a1',
          year: 2026,
          month: 6,
          revenue: 1000,
        );
        final copy = budget.copyWith(revenue: 2000);
        expect(copy.revenue, 2000);
      });

      test('preserves all fields when no overrides', () {
        const budget = AccountBudget(
          id: 'b1',
          accountId: 'a1',
          year: 2026,
          month: 6,
          revenue: 1000,
        );
        final copy = budget.copyWith();
        expect(copy.id, 'b1');
        expect(copy.accountId, 'a1');
        expect(copy.year, 2026);
        expect(copy.month, 6);
        expect(copy.revenue, 1000);
      });
    });

    group('equality', () {
      test('two identical budgets are equal', () {
        const a = AccountBudget(
          accountId: 'a1',
          year: 2026,
          month: 6,
          revenue: 1000,
        );
        const b = AccountBudget(
          accountId: 'a1',
          year: 2026,
          month: 6,
          revenue: 1000,
        );
        expect(a, equals(b));
      });
    });
  });
}

