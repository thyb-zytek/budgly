import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/services/calculators/expense_occurrence_calculator.dart';
import 'package:budgly/src/services/calculators/expense_summary_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/builders.dart';

void main() {
  const occCalc = ExpenseOccurrenceCalculator();
  const sumCalc = ExpenseSummaryCalculator();

  Category cat(String id, String accountId) => Fixtures.category(id: id, accountId: accountId, name: 'Cat $id');

  group('Invariants financiers', () {
    test('sum(categories) == total expenses', () {
      const accId = 'acc-1';
      final categories = [cat('cat-1', accId), cat('cat-2', accId), cat('cat-3', accId)];
      final expenses = [
        Fixtures.expense(id: 'e1', accountId: accId, categoryId: 'cat-1', amount: 100, debitDate: DateTime(2026, 3, 5)),
        Fixtures.expense(id: 'e2', accountId: accId, categoryId: 'cat-2', amount: 50, debitDate: DateTime(2026, 3, 10)),
        Fixtures.expense(id: 'e3', accountId: accId, categoryId: 'cat-1', amount: 25, debitDate: DateTime(2026, 3, 15)),
        Fixtures.expense(id: 'e4', accountId: accId, categoryId: 'cat-3', amount: 75, debitDate: DateTime(2026, 3, 20)),
      ];
      const period = Period(year: 2026, month: 3);
      final occurrences = occCalc.forPeriod(expenses, period);
      final total = occurrences.fold(0.0, (s, o) => s + o.amount);
      final summaries = sumCalc.summarizeByCategory(
        occurrences: occurrences,
        resolveCategory: (id) => categories.firstWhere((c) => c.id == id),
      );
      final sumCat = summaries.fold(0.0, (s, e) => s + e.total);
      expect(sumCat, total);
      expect(total, 250);
    });

    test('sum(accounts) == total (multi-account)', () {
      final expenses = [
        Fixtures.expense(id: 'e1', accountId: 'acc-1', categoryId: 'cat-1', amount: 100, debitDate: DateTime(2026, 3, 5)),
        Fixtures.expense(id: 'e2', accountId: 'acc-2', categoryId: 'cat-1', amount: 200, debitDate: DateTime(2026, 3, 10)),
        Fixtures.expense(id: 'e3', accountId: 'acc-1', categoryId: 'cat-2', amount: 50, debitDate: DateTime(2026, 3, 15)),
      ];
      const period = Period(year: 2026, month: 3);
      final allOcc = occCalc.forPeriod(expenses, period);
      final total = allOcc.fold(0.0, (s, o) => s + o.amount);
      // simulate per-account totals
      final acc1Total = occCalc.forPeriod(expenses.where((e) => e.accountId == 'acc-1'), period).fold(0.0, (s, o) => s + o.amount);
      final acc2Total = occCalc.forPeriod(expenses.where((e) => e.accountId == 'acc-2'), period).fold(0.0, (s, o) => s + o.amount);
      expect(acc1Total + acc2Total, total);
      expect(total, 350);
    });

    test('income - expenses == résultat attendu', () {
      const revenue = 2000.0;
      final expenses = [
        Fixtures.expense(id: 'e1', accountId: 'acc-1', categoryId: 'cat-1', amount: 300, debitDate: DateTime(2026, 3, 5)),
        Fixtures.expense(id: 'e2', accountId: 'acc-1', categoryId: 'cat-2', amount: 150, debitDate: DateTime(2026, 3, 10)),
      ];
      const period = Period(year: 2026, month: 3);
      final total = occCalc.forPeriod(expenses, period).fold(0.0, (s, o) => s + o.amount);
      final remaining = revenue - total;
      expect(remaining, 1550);
      expect(total, 450);
    });

    test('graph total == total (occurrence sum)', () {
      final expenses = [
        Fixtures.expense(id: 'e1', accountId: 'acc-1', categoryId: 'cat-1', amount: 100, debitDate: DateTime(2026, 3, 5)),
        Fixtures.expense(id: 'e2', accountId: 'acc-1', categoryId: 'cat-1', amount: 200, debitDate: DateTime(2026, 3, 15)),
      ];
      const period = Period(year: 2026, month: 3);
      final occ = occCalc.forPeriod(expenses, period);
      final graphTotal = occ.fold(0.0, (s, o) => s + o.amount);
      final summaryTotal = sumCalc.summarize(
        category: cat('cat-1', 'acc-1'),
        occurrences: occ,
      ).total;
      expect(graphTotal, summaryTotal);
    });

    test('déplacer expense conserve son montant', () {
      final e = Fixtures.expense(id: 'e1', accountId: 'acc-1', categoryId: 'cat-1', amount: 123.45, debitDate: DateTime(2026, 3, 15));
      final moved = e.copyWith(categoryId: 'cat-2', accountId: 'acc-2');
      expect(moved.amount, e.amount);
    });

    test('budgets: restant, dépassement, pourcentage', () {
      const revenue = 1000.0;
      final expenses = [
        Fixtures.expense(id: 'e1', accountId: 'acc-1', categoryId: 'cat-1', amount: 600, debitDate: DateTime(2026, 3, 5)),
        Fixtures.expense(id: 'e2', accountId: 'acc-1', categoryId: 'cat-2', amount: 500, debitDate: DateTime(2026, 3, 10)),
      ];
      const period = Period(year: 2026, month: 3);
      final total = occCalc.forPeriod(expenses, period).fold(0.0, (s, o) => s + o.amount);
      final remaining = revenue - total;
      final percent = total / revenue * 100;
      expect(remaining, -100); // dépassement
      expect(percent, closeTo(110, 0.001));
      expect(total > revenue, isTrue);
    });

    test('données vides => totaux 0', () {
      const period = Period(year: 2026, month: 3);
      final occ = occCalc.forPeriod(const [], period);
      expect(occ, isEmpty);
      expect(occ.fold(0.0, (s, o) => s + o.amount), 0);
    });

    test('valeurs extrêmes (grand montant)', () {
      final e = Fixtures.expense(id: 'e1', accountId: 'acc-1', categoryId: 'cat-1', amount: 999999.99, debitDate: DateTime(2026, 3, 15));
      const period = Period(year: 2026, month: 3);
      final occ = occCalc.forPeriod([e], period);
      expect(occ.single.amount, 999999.99);
    });

    test('changement de période isole les totaux', () {
      final eMar = Fixtures.expense(id: 'e1', accountId: 'acc-1', categoryId: 'cat-1', amount: 100, debitDate: DateTime(2026, 3, 15));
      final eApr = Fixtures.expense(id: 'e2', accountId: 'acc-1', categoryId: 'cat-1', amount: 200, debitDate: DateTime(2026, 4, 15));
      const march = Period(year: 2026, month: 3);
      const april = Period(year: 2026, month: 4);
      final marTotal = occCalc.forPeriod([eMar, eApr], march).fold(0.0, (s, o) => s + o.amount);
      final aprTotal = occCalc.forPeriod([eMar, eApr], april).fold(0.0, (s, o) => s + o.amount);
      expect(marTotal, 100);
      expect(aprTotal, 200);
      expect(marTotal != aprTotal, isTrue);
    });

    test('changement de compte isole les totaux par compte', () {
      final e1 = Fixtures.expense(id: 'e1', accountId: 'acc-1', categoryId: 'cat-1', amount: 100, debitDate: DateTime(2026, 3, 10));
      final e2 = Fixtures.expense(id: 'e2', accountId: 'acc-2', categoryId: 'cat-1', amount: 300, debitDate: DateTime(2026, 3, 10));
      const period = Period(year: 2026, month: 3);
      final acc1 = occCalc.forPeriod([e1, e2].where((e) => e.accountId == 'acc-1'), period).fold(0.0, (s, o) => s + o.amount);
      final acc2 = occCalc.forPeriod([e1, e2].where((e) => e.accountId == 'acc-2'), period).fold(0.0, (s, o) => s + o.amount);
      expect(acc1, 100);
      expect(acc2, 300);
    });

    test('mutation création -> stats mises à jour', () {
      final expenses = <Expense>[];
      const period = Period(year: 2026, month: 3);
      var total = occCalc.forPeriod(expenses, period).fold(0.0, (s, o) => s + o.amount);
      expect(total, 0);
      expenses.add(Fixtures.expense(id: 'e1', accountId: 'acc-1', categoryId: 'cat-1', amount: 100, debitDate: DateTime(2026, 3, 5)));
      total = occCalc.forPeriod(expenses, period).fold(0.0, (s, o) => s + o.amount);
      expect(total, 100);
    });

    test('mutation suppression -> stats mises à jour', () {
      final expenses = [
        Fixtures.expense(id: 'e1', accountId: 'acc-1', categoryId: 'cat-1', amount: 100, debitDate: DateTime(2026, 3, 5)),
        Fixtures.expense(id: 'e2', accountId: 'acc-1', categoryId: 'cat-1', amount: 50, debitDate: DateTime(2026, 3, 10)),
      ];
      const period = Period(year: 2026, month: 3);
      var total = occCalc.forPeriod(expenses, period).fold(0.0, (s, o) => s + o.amount);
      expect(total, 150);
      expenses.removeWhere((e) => e.id == 'e1');
      total = occCalc.forPeriod(expenses, period).fold(0.0, (s, o) => s + o.amount);
      expect(total, 50);
    });

    test('récurrence -> stats correctement agrégées', () {
      final e = Fixtures.expense(
        id: 'e1',
        accountId: 'acc-1',
        categoryId: 'cat-1',
        amount: 100,
        debitDate: DateTime(2026, 1, 15),
        recurrence: RecurrenceType.monthly,
      );
      const march = Period(year: 2026, month: 3);
      final occ = occCalc.forPeriod([e], march);
      expect(occ.length, 1);
      expect(occ.single.amount, 100);
    });
  });
}
