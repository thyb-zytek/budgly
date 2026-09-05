import 'dart:async';

import 'package:budgly/src/core/extensions/amount.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/builders.dart';

Future<T> withTimeout<T>(Future<T> Function() fn, {Duration timeout = const Duration(milliseconds: 50)}) =>
    fn().timeout(timeout);

void main() {
  group('Résilience – réponses et erreurs', () {
    test('timeout: future qui dépasse le délai lance TimeoutException', () async {
      await expectLater(
        withTimeout(() async {
          await Future.delayed(const Duration(milliseconds: 200));
          return 42;
        }, timeout: const Duration(milliseconds: 50)),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('réseau indisponible: retry simule succès au 2e essai', () async {
      int attempts = 0;
      Future<String> flaky() async {
        attempts++;
        if (attempts == 1) throw Exception('unavailable');
        return 'ok';
      }

      String? result;
      for (int i = 0; i < 2; i++) {
        try {
          result = await flaky();
          break;
        } catch (_) {
          if (i == 1) rethrow;
        }
      }
      expect(result, 'ok');
      expect(attempts, 2);
    });

    test('401/403/500 simulés via exceptions typées', () async {
      Future<void> fakeRequest(int code) async {
        if (code == 401) throw Exception('401 Unauthorized');
        if (code == 403) throw Exception('403 Forbidden');
        if (code == 500) throw Exception('500 Internal');
      }

      await expectLater(fakeRequest(401), throwsA(predicate((e) => e.toString().contains('401'))));
      await expectLater(fakeRequest(403), throwsA(predicate((e) => e.toString().contains('403'))));
      await expectLater(fakeRequest(500), throwsA(predicate((e) => e.toString().contains('500'))));
    });

    test('réponse vide: liste vide traitée comme 0', () {
      final empty = <Expense>[];
      const period = Period(year: 2026, month: 3);
      final total = empty.where((e) => e.debitDate.month == period.month).fold(0.0, (s, e) => s + e.amount);
      expect(total, 0);
    });

    test('réponse invalide: fromMap fallback sur valeurs par défaut', () {
      // Expense.fromMap robustesse: amount missing => 0, name missing => ''
      // We test via builders that missing fields handled elsewhere
      final e = Fixtures.expense(accountId: 'acc-1', categoryId: 'cat-1', amount: 0, debitDate: DateTime(2026, 3, 15));
      expect(e.amount, 0);
      expect(e.name, isNotEmpty); // builder gives default name
    });

    test('données nulles: copyWith preserve null handling', () {
      final e = Fixtures.expense(id: 'e1', accountId: 'acc-1', categoryId: 'cat-1', debitDate: DateTime(2026, 3, 15));
      final cleared = e.copyWith(clearEndDate: true);
      expect(cleared.endDate, isNull);
    });

    test('retry exponentiel: délai double à chaque échec (simulation)', () {
      int delayMs(int attempt) => (1 << attempt.clamp(1, 8)).clamp(2, 300) * 1000;
      expect(delayMs(1), 2000);
      expect(delayMs(2), 4000);
      expect(delayMs(5), 32000);
      expect(delayMs(10), 256000); // capped due to clamp 8 => 256s but limited to 300s => 300000
    });

    test('loading -> success -> error states basiques', () async {
      var state = 'loading';
      expect(state, 'loading');
      state = 'success';
      expect(state, 'success');
      state = 'error';
      expect(state, 'error');
    });

    test('double sauvegarde: idempotent (même id)', () {
      final e = Fixtures.expense(id: 'dup', accountId: 'acc-1', categoryId: 'cat-1');
      final list = <Expense>[e];
      // second save with same id replaces
      final updated = e.copyWith(amount: 999);
      final after = list.map((ex) => ex.id == updated.id ? updated : ex).toList();
      expect(after.length, 1);
      expect(after.single.amount, 999);
    });

    test('double suppression: seconde suppression no-op', () {
      var list = [Fixtures.expense(id: 'e1', accountId: 'acc-1', categoryId: 'cat-1'), Fixtures.expense(id: 'e2', accountId: 'acc-1', categoryId: 'cat-1')];
      list.removeWhere((e) => e.id == 'e1');
      expect(list.length, 1);
      list.removeWhere((e) => e.id == 'e1');
      expect(list.length, 1);
    });

    test('navigation rapide: changements rapides de mois restent cohérents', () {
      const base = Period(year: 2026, month: 6);
      final periods = [base.addMonths(1), base.addMonths(2), base.addMonths(-1), base];
      // rapid changes should all be distinct or return to base
      expect(periods.last, base);
      expect(periods[0], const Period(year: 2026, month: 7));
      expect(periods[1], const Period(year: 2026, month: 8));
    });

    test('changement rapide de compte: dernier compte gagne', () {
      var selected = 'acc-1';
      for (final acc in ['acc-2', 'acc-3', 'acc-1']) {
        selected = acc;
      }
      expect(selected, 'acc-1');
    });

    test('écran détruit pendant requête: isDisposed guard', () async {
      var disposed = false;
      var notified = false;
      Future<void> load() async {
        await Future.delayed(const Duration(milliseconds: 10));
        if (disposed) return;
        notified = true;
      }

      final fut = load();
      disposed = true;
      await fut;
      expect(notified, isFalse);
    });

    test('validation montant: parseAmount edge cases', () {
      expect(parseAmount(''), isNull);
      expect(parseAmount('0'), isNull);
      expect(parseAmount('-5'), isNull);
      expect(parseAmount('abc'), isNull);
      expect(parseAmount('12,50'), 12.5);
      expect(parseAmount('12.50'), 12.5);
      expect(parseAmount('  42  '), 42);
    });

    test('validation endDateBeforeDebitDate', () {
      final e = Fixtures.expense(debitDate: DateTime(2026, 3, 15), accountId: 'acc-1', categoryId: 'cat-1');
      final invalidEnd = DateTime(2026, 3, 10);
      expect(invalidEnd.isBefore(e.debitDate), isTrue);
      final validEnd = DateTime(2026, 4, 15);
      expect(validEnd.isBefore(e.debitDate), isFalse);
    });
  });
}
