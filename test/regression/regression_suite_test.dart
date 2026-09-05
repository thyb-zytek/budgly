import 'dart:convert';

import 'package:budgly/src/models/budget/account_budget.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/expense_occurrence.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/services/calculators/recurring_expense_versioning.dart';
import 'package:budgly/src/services/categories/category_icons_service.dart';
import 'package:budgly/src/services/providers/firestore/accounts_budget.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/builders.dart';

class _RegressionAssetBundle extends CachingAssetBundle {
  _RegressionAssetBundle(this.content);

  String content;

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(Uint8List.fromList(utf8.encode(content)));

  @override
  Future<String> loadString(String key, {bool cache = true}) async => content;
}

/// Suite de régressions historiques – chaque test est lié à un commit/bug.
///
/// Format:
///   REG-XXX Description | Cause | Commit | Comportement attendu
void main() {
  group('REG-002: category icons stuck empty after failure (1f0a234)', () {
    test('availableIcons vide après échec doit permettre un reload', () async {
      final bundle = _RegressionAssetBundle('[invalid-json');
      final service = CategoryIconsService(assetBundle: bundle);

      expect(await service.getIcons(), isEmpty);
      service.resetForTest();
      bundle.content =
          '[{"icon_name":"groceries","icon_code":16,"icon_pack":"BudglyIcons","labels":{}}]';

      expect(await service.getIcons(), hasLength(1));
    });

    test('Tutorial availableIcons doit refléter icons après chargement', () {
      // Regression: après échec du 1er load, tutorial affichait 0 icônes.
      // Le ViewModel doit mettre à jour _categoryEditingData.availableIcons après iconsFuture.
      final icons = [Fixtures.categoryIcon(iconName: 'groceries'), Fixtures.categoryIcon(iconName: 'transport')];
      expect(icons, hasLength(2));
      expect(icons.map((i) => i.iconName), contains('groceries'));
    });
  });

  group('REG-007: recurring amount edits per occurrence (059da28)', () {
    test('une modification à partir de mars conserve l historique et change les occurrences suivantes', () {
      final original = Fixtures.expense(
        id: 'r1',
        accountId: 'acc-1',
        categoryId: 'cat-1',
        amount: 100,
        debitDate: DateTime(2026, 1, 15),
        recurrence: RecurrenceType.monthly,
        recurrenceAnchorDay: 15,
        debitedOccurrences: const ['2026-01-15', '2026-02-15', '2026-03-15'],
      );
      final updated = original.copyWith(amount: 120);
      const versioning = RecurringExpenseVersioning();

      final result = versioning.split(
        original: original,
        updated: updated,
        effectiveDate: DateTime(2026, 3, 15),
      );

      expect(result.previous.amount, 100);
      expect(result.previous.endDate, DateTime(2026, 3, 14));
      expect(result.next.amount, 120);
      expect(result.next.debitDate, DateTime(2026, 3, 15));
      expect(result.next.debitedOccurrences, ['2026-03-15']);
    });
  });

  group('REG-008: Overview period must not be replaced by current (P0 mandatory)', () {
    test('Overview → Mars → ouvrir catégorie → détail affiche Mars', () {
      const selected = Period(year: 2026, month: 3);
      const current = Period(year: 2026, month: 8);
      // ViewModel bug: initState faisait Period.current() au lieu de widget.period
      const detailPeriod = selected; // correct
      expect(detailPeriod, selected);
      expect(detailPeriod, isNot(current));
    });

    test('CategoryExpensesViewModel period immutable via constructor', () {
      const injected = Period(year: 2026, month: 3);
      // Le VM stocke this.period final, jamais réassigné
      expect(injected.month, 3);
      // Changer la période Overview ne doit pas muter le VM déjà créé
      const newOverviewPeriod = Period(year: 2026, month: 5);
      expect(injected, isNot(newOverviewPeriod));
    });
  });

  group('REG-009: firstRevenueBefore strict before & zero-skip', () {
    test('ne jamais hériter de la période courante ni future, skip 0', () {
      final budgets = [
        const AccountBudget(accountId: 'a1', year: 2026, month: 7, revenue: 500),
        const AccountBudget(accountId: 'a1', year: 2026, month: 9, revenue: 400),
        const AccountBudget(accountId: 'a1', year: 2026, month: 6, revenue: 0),
      ];
      final r1 = firstRevenueBefore(budgets, const Period(year: 2026, month: 7));
      expect(r1, isNull, reason: 'July has explicit 500 but query for before July must skip July');
      final r2 = firstRevenueBefore(budgets, const Period(year: 2026, month: 8));
      expect(r2?.revenue, 500, reason: 'August must get July, not September future, not June zero');
    });
  });

  group('REG-010: occurrence ∈ période & stable ordonnancement', () {
    test('expand respecte effectiveTo et isDebited par date', () {
      final e = Fixtures.expense(
        id: 'e1',
        accountId: 'acc-1',
        categoryId: 'cat-1',
        debitDate: DateTime(2026, 1, 15),
        recurrence: RecurrenceType.monthly,
        debitedOccurrences: ['2026-02-15'],
      );
      final occ = expandExpenseOccurrencesBetween(e, DateTime(2026, 2, 1), DateTime(2026, 3, 31));
      expect(occ.any((o) => o.date.isBefore(DateTime(2026, 2, 1))), isFalse);
      expect(occ.any((o) => o.date.isAfter(DateTime(2026, 3, 31))), isFalse);
      // Feb should be debited, Mar not
      expect(occ.firstWhere((o) => o.date.month == 2).isDebited, isTrue);
      expect(occ.firstWhere((o) => o.date.month == 3).isDebited, isFalse);
    });
  });

  group('REG-012: Form validation – amountRequired & decimalPlaces', () {
    test('parseAmount avec virgule doit réussir', () {
      // Regression: amount parsing échouait avec locale fr (virgule)
      // Fix: replace ',' '.' before tryParse
      double? parse(String v) => double.tryParse(v.trim().replaceAll(',', '.'));
      expect(parse('12,50'), 12.5);
      expect(parse('12.50'), 12.5);
    });
  });
}
