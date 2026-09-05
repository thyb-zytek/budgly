import 'package:budgly/src/models/budget/account_budget.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/services/providers/firestore/accounts_budget.dart';
import 'package:flutter_test/flutter_test.dart';

AccountBudget b(int y, int m, double rev, {String accountId = 'acc-1'}) =>
    AccountBudget(accountId: accountId, year: y, month: m, revenue: rev);

void main() {
  group('firstRevenueBefore – spécification métier', () {
    test('Jan 2000, Mars 2500 => Février 2000, Mars 2500, Avril 2500', () {
      final budgets = [b(2026, 1, 2000), b(2026, 3, 2500)];
      expect(firstRevenueBefore(budgets, const Period(year: 2026, month: 2))?.revenue, 2000);
      expect(firstRevenueBefore(budgets, const Period(year: 2026, month: 3))?.revenue, 2000,
          reason: 'March inherits only strictly before, not itself');
      // But if March has explicit revenue, April should inherit March
      expect(firstRevenueBefore(budgets, const Period(year: 2026, month: 4))?.revenue, 2500);
    });

    test('Mars 2500 Avril/Mai héritent, Mars -> 2800 => Avril/Mai 2800', () {
      // Simulate update: budget March changed
      var budgets = [b(2026, 3, 2500)];
      expect(firstRevenueBefore(budgets, const Period(year: 2026, month: 4))?.revenue, 2500);
      expect(firstRevenueBefore(budgets, const Period(year: 2026, month: 5))?.revenue, 2500);
      budgets = [b(2026, 3, 2800)];
      expect(firstRevenueBefore(budgets, const Period(year: 2026, month: 4))?.revenue, 2800);
      expect(firstRevenueBefore(budgets, const Period(year: 2026, month: 5))?.revenue, 2800);
    });

    test('propagation stoppée par revenu explicite ultérieur: Mars 2500 Juin 3000', () {
      // Mars->2800 should give Avril/Mai 2800 but Juin 3000 unchanged
      final marchUpdated = [b(2026, 3, 2800), b(2026, 6, 3000)];
      expect(firstRevenueBefore(marchUpdated, const Period(year: 2026, month: 4))?.revenue, 2800);
      expect(firstRevenueBefore(marchUpdated, const Period(year: 2026, month: 5))?.revenue, 2800);
      expect(firstRevenueBefore(marchUpdated, const Period(year: 2026, month: 7))?.revenue, 3000,
          reason: 'July should inherit June explicit 3000, not March 2800');
      expect(firstRevenueBefore(marchUpdated, const Period(year: 2026, month: 6))?.revenue, 2800,
          reason: 'June is explicit, but its own inheritance query is for before June');
    });

    test('transitions entre années: Déc 2025 2000 -> Jan 2026 hérite, Juin 2026 3000', () {
      final budgets = [b(2025, 12, 2000)];
      expect(firstRevenueBefore(budgets, const Period(year: 2026, month: 1))?.revenue, 2000);
      expect(firstRevenueBefore(budgets, const Period(year: 2026, month: 6))?.revenue, 2000);
      final withJune = [b(2025, 12, 2000), b(2026, 6, 3000)];
      expect(firstRevenueBefore(withJune, const Period(year: 2026, month: 7))?.revenue, 3000);
      expect(firstRevenueBefore(withJune, const Period(year: 2026, month: 5))?.revenue, 2000);
    });

    test('mois sans revenu explicite hérite du plus récent', () {
      final budgets = [b(2026, 1, 1000), b(2026, 3, 2000), b(2026, 8, 4000)];
      expect(firstRevenueBefore(budgets, const Period(year: 2026, month: 2))?.revenue, 1000);
      expect(firstRevenueBefore(budgets, const Period(year: 2026, month: 4))?.revenue, 2000);
      expect(firstRevenueBefore(budgets, const Period(year: 2026, month: 7))?.revenue, 2000);
      expect(firstRevenueBefore(budgets, const Period(year: 2026, month: 9))?.revenue, 4000);
    });

    test('jamais de revenu futur, jamais de la période courante', () {
      final budgets = [b(2026, 5, 5000), b(2026, 7, 7000)];
      expect(firstRevenueBefore(budgets, const Period(year: 2026, month: 5))?.revenue, isNull);
      expect(firstRevenueBefore(budgets, const Period(year: 2026, month: 6))?.revenue, 5000);
      expect(firstRevenueBefore(budgets, const Period(year: 2026, month: 8))?.revenue, 7000);
    });

    test('revenu 0 est ignoré', () {
      final budgets = [b(2026, 1, 1000), b(2026, 2, 0), b(2026, 3, 0)];
      expect(firstRevenueBefore(budgets, const Period(year: 2026, month: 4))?.revenue, 1000);
    });

    test('plusieurs années avec trous', () {
      final budgets = [b(2024, 11, 1500), b(2025, 6, 1800), b(2026, 1, 2000)];
      expect(firstRevenueBefore(budgets, const Period(year: 2026, month: 2))?.revenue, 2000);
      expect(firstRevenueBefore(budgets, const Period(year: 2025, month: 7))?.revenue, 1800);
      expect(firstRevenueBefore(budgets, const Period(year: 2025, month: 1))?.revenue, 1500);
      expect(firstRevenueBefore(budgets, const Period(year: 2024, month: 11))?.revenue, isNull);
    });

    test('ordre d’entrée indépendant', () {
      final budgets = [b(2026, 3, 300), b(2026, 7, 500), b(2026, 6, 900), b(2026, 2, 200)];
      expect(firstRevenueBefore(budgets, const Period(year: 2026, month: 8))?.revenue, 500);
      expect(firstRevenueBefore(budgets, const Period(year: 2026, month: 7))?.revenue, 900);
    });
  });

  group('effectiveRevenue helper semantics', () {
    double effective(double revenue, double? inherited) {
      if (revenue > 0) return revenue;
      return inherited ?? 0;
    }

    test('hasRevenue prioritizes explicit', () {
      expect(effective(2500, 2000), 2500);
      expect(effective(0, 2000), 2000);
      expect(effective(0, null), 0);
    });

    test('revenue estimé quand inherited > 0 et revenue == 0', () {
      bool isEstimated(double revenue, double? inherited) => revenue <= 0 && (inherited ?? 0) > 0;
      expect(isEstimated(0, 2000), isTrue);
      expect(isEstimated(2500, 2000), isFalse);
      expect(isEstimated(0, 0), isFalse);
    });
  });
}
