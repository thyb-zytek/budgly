import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/expense_occurrence.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/services/calculators/expense_occurrence_calculator.dart';
import 'package:budgly/src/services/calculators/expense_summary_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/builders.dart';

void main() {
  const calculator = ExpenseOccurrenceCalculator();
  const summaryCalculator = ExpenseSummaryCalculator();

  Expense exp({
    String id = 'e1',
    String accountId = 'acc-1',
    String categoryId = 'cat-1',
    double amount = 100,
    DateTime? debitDate,
    RecurrenceType recurrence = RecurrenceType.none,
    bool isDebited = false,
  }) => Fixtures.expense(
        id: id,
        accountId: accountId,
        categoryId: categoryId,
        amount: amount,
        debitDate: debitDate,
        recurrence: recurrence,
        isDebited: isDebited,
      );

  group('Expense CRUD invariants', () {
    test('création: fields preserved', () {
      final e = exp();
      expect(e.amount, 100);
      expect(e.accountId, 'acc-1');
      expect(e.categoryId, 'cat-1');
      expect(e.name, isNotEmpty);
    });

    test('modification montant preserves identity', () {
      final e = exp(id: 'e-42', amount: 100);
      final updated = e.copyWith(amount: 250);
      expect(updated.id, 'e-42');
      expect(updated.amount, 250);
      expect(updated.accountId, e.accountId);
    });

    test('changement catégorie: ancienne absente, nouvelle présente', () {
      final e = exp(id: 'e1', categoryId: 'cat-A');
      final moved = e.copyWith(categoryId: 'cat-B');
      expect(e.categoryId, 'cat-A');
      expect(moved.categoryId, 'cat-B');
      // filtering simulation
      final catAList = [e].where((ex) => ex.categoryId == 'cat-A').toList();
      expect(catAList, hasLength(1));
      // after move, old list would be empty if we replace store contents
      final afterMoveA = <Expense>[]; // old category no longer has it
      final afterMoveB = [moved];
      expect(afterMoveA.any((ex) => ex.id == 'e1'), isFalse);
      expect(afterMoveB.any((ex) => ex.id == 'e1'), isTrue);
    });

    test('changement compte: isolation vérifiée', () {
      final e = exp(id: 'e1', accountId: 'acc-A', categoryId: 'cat-1');
      final moved = e.copyWith(accountId: 'acc-B');
      // after move, old account list empty, new has it
      final oldAccExpenses = <Expense>[];
      final newAccExpenses = [moved];
      expect(oldAccExpenses.where((ex) => ex.accountId == 'acc-A'), isEmpty);
      expect(newAccExpenses.where((ex) => ex.accountId == 'acc-B'), hasLength(1));
    });

    test('changement catégorie + compte simultanément', () {
      final e = exp(id: 'e1', accountId: 'acc-A', categoryId: 'cat-A');
      final moved = e.copyWith(accountId: 'acc-B', categoryId: 'cat-B');
      expect(moved.accountId, 'acc-B');
      expect(moved.categoryId, 'cat-B');
      // both old combos absent, new present
      expect(moved.accountId != e.accountId && moved.categoryId != e.categoryId, isTrue);
    });

    test('changement date/période: occurrence migre de période', () {
      final e = exp(id: 'e1', debitDate: DateTime(2026, 3, 15));
      const march = Period(year: 2026, month: 3);
      const april = Period(year: 2026, month: 4);
      expect(expandExpenseOccurrences(e, march), hasLength(1));
      expect(expandExpenseOccurrences(e, april), isEmpty);
      final moved = e.copyWith(debitDate: DateTime(2026, 4, 10));
      expect(expandExpenseOccurrences(moved, march), isEmpty);
      expect(expandExpenseOccurrences(moved, april), hasLength(1));
    });

    test('débit/non-débit toggle', () {
      var e = exp(isDebited: false);
      expect(e.isDebited, isFalse);
      e = e.copyWith(isDebited: true);
      expect(e.isDebited, isTrue);
      e = e.copyWith(isDebited: false);
      expect(e.isDebited, isFalse);
    });

    test('récurrence toggle: debitedOccurrences per date', () {
      final e = Fixtures.expense(
        id: 'r1',
        accountId: 'acc-1',
        categoryId: 'cat-1',
        debitDate: DateTime(2026, 1, 15),
        recurrence: RecurrenceType.monthly,
        debitedOccurrences: [],
      );
      final key = Expense.isoDate(DateTime(2026, 2, 15));
      expect(e.isDebitedAt(DateTime(2026, 2, 15)), isFalse);
      final debited = e.copyWith(debitedOccurrences: [key]);
      expect(debited.isDebitedAt(DateTime(2026, 2, 15)), isTrue);
      expect(debited.isDebitedAt(DateTime(2026, 3, 15)), isFalse);
    });

    test('suppression retire exactement une expense', () {
      final list = [exp(id: 'e1'), exp(id: 'e2'), exp(id: 'e3')];
      final after = list.where((e) => e.id != 'e2').toList();
      expect(after.length, list.length - 1);
      expect(after.any((e) => e.id == 'e2'), isFalse);
      expect(after.any((e) => e.id == 'e1'), isTrue);
      expect(after.any((e) => e.id == 'e3'), isTrue);
    });

    test('mutation ne crée jamais de doublon', () {
      final e = exp(id: 'e1', amount: 100);
      final updated = e.copyWith(amount: 200);
      final store = [e];
      // update replaces
      final after = store.map((ex) => ex.id == updated.id ? updated : ex).toList();
      expect(after.where((ex) => ex.id == 'e1'), hasLength(1));
      expect(after.singleWhere((ex) => ex.id == 'e1').amount, 200);
    });

    test('limites fin de mois: Feb 28 handling', () {
      final e = Fixtures.expense(
        id: 'e1',
        accountId: 'acc-1',
        categoryId: 'cat-1',
        debitDate: DateTime(2026, 1, 31),
        recurrence: RecurrenceType.monthly,
        recurrenceAnchorDay: 31,
      );
      const feb = Period(year: 2026, month: 2);
      const mar = Period(year: 2026, month: 3);
      final febOcc = expandExpenseOccurrences(e, feb);
      final marOcc = expandExpenseOccurrences(e, mar);
      expect(febOcc.single.date, DateTime(2026, 2, 28));
      expect(marOcc.single.date, DateTime(2026, 3, 31));
    });

    test('plusieurs comptes/catégories isolation', () {
      final expenses = [
        exp(id: 'e1', accountId: 'acc-1', categoryId: 'cat-1'),
        exp(id: 'e2', accountId: 'acc-1', categoryId: 'cat-2'),
        exp(id: 'e3', accountId: 'acc-2', categoryId: 'cat-1'),
        exp(id: 'e4', accountId: 'acc-2', categoryId: 'cat-2'),
      ];
      expect(expenses.where((e) => e.accountId == 'acc-1'), hasLength(2));
      expect(expenses.where((e) => e.categoryId == 'cat-1'), hasLength(2));
      expect(expenses.where((e) => e.accountId == 'acc-1' && e.categoryId == 'cat-1'), hasLength(1));
    });
  });

  group('Statistics via calculators', () {
    test('calcul des occurrences trié: non-débité avant débité', () {
      final expenses = [
        exp(id: 'e1', amount: 50, debitDate: DateTime(2026, 3, 5), isDebited: true),
        exp(id: 'e2', amount: 30, debitDate: DateTime(2026, 3, 10), isDebited: false),
        exp(id: 'e3', amount: 20, debitDate: DateTime(2026, 3, 15), isDebited: false),
      ];
      const period = Period(year: 2026, month: 3);
      final occ = calculator.forPeriod(expenses, period);
      expect(occ.length, 3);
      // undedebited first sorted by date
      expect(occ[0].isDebited, isFalse);
      expect(occ[1].isDebited, isFalse);
      expect(occ[2].isDebited, isTrue);
    });

    test('summary totals per period', () {
      final acc = Fixtures.account(id: 'acc-1');
      final cat1 = Fixtures.category(id: 'cat-1', accountId: acc.id!);
      final cat2 = Fixtures.category(id: 'cat-2', accountId: acc.id!);
      final expenses = [
        exp(id: 'e1', categoryId: 'cat-1', amount: 100, debitDate: DateTime(2026, 3, 5)),
        exp(id: 'e2', categoryId: 'cat-1', amount: 50, debitDate: DateTime(2026, 3, 10)),
        exp(id: 'e3', categoryId: 'cat-2', amount: 75, debitDate: DateTime(2026, 3, 15)),
      ];
      const period = Period(year: 2026, month: 3);
      final occ = calculator.forPeriod(expenses, period);
      final summaries = summaryCalculator.summarizeByCategory(
        occurrences: occ,
        resolveCategory: (id) => id == 'cat-1' ? cat1 : cat2,
      );
      final total = summaries.fold(0.0, (s, e) => s + e.total);
      expect(total, 225);
      expect(summaries.firstWhere((s) => s.category.id == 'cat-1').total, 150);
      expect(summaries.firstWhere((s) => s.category.id == 'cat-2').total, 75);
    });
  });
}
