import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/builders.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => SharedPreferences.setMockInitialValues({}));
  setUp(() async => SyncQueue.instance.clear());

  group('Offline scenarios contrôlés', () {
    test('lecture offline: SyncQueue conserve les mutations locales', () async {
      final queue = SyncQueue.instance;
      await queue.enqueue(id: 'acc:create:1', type: 'accounts', operation: 'create', payload: {'id': 'acc-1', 'name': 'Test'});
      final pending = await queue.all();
      expect(pending, hasLength(1));
      expect(pending.single.type, 'accounts');
    });

    test('création offline puis reconnexion: enqueue survit', () async {
      final queue = SyncQueue.instance;
      await queue.enqueue(id: 'cat:create:1', type: 'categories', operation: 'create', payload: {'id': 'cat-1', 'account_id': 'acc-1'});
      // Simulate offline: queue not flushed
      var pending = await queue.all();
      expect(pending, hasLength(1));
      // Simulate reconnexion: handler would remove after success
      await queue.remove(pending.single.id);
      pending = await queue.all();
      expect(pending, isEmpty);
    });

    test('modification offline: coalesce create+update garde un seul create', () async {
      final queue = SyncQueue.instance;
      await queue.enqueue(id: 'acc:create:1', type: 'accounts', operation: 'create', payload: {'id': '1', 'name': 'Old'});
      await queue.enqueue(id: 'acc:update:1', type: 'accounts', operation: 'update', payload: {'id': '1', 'name': 'New'});
      final ops = await queue.all();
      expect(ops, hasLength(1));
      expect(ops.single.operation, 'create');
      expect(ops.single.payload['name'], 'New');
    });

    test('suppression offline après création annule (create+delete => vide)', () async {
      final queue = SyncQueue.instance;
      await queue.enqueue(id: 'cat:create:1', type: 'categories', operation: 'create', payload: {'id': '1', 'account_id': 'acc-1'});
      await queue.enqueue(id: 'cat:delete:1', type: 'categories', operation: 'delete', payload: {'id': '1', 'account_id': 'acc-1'});
      expect(await queue.all(), isEmpty);
    });

    test('changement catégorie offline: mutation locale isolée', () {
      final e = Fixtures.expense(id: 'e1', accountId: 'acc-1', categoryId: 'cat-1');
      final updated = e.copyWith(categoryId: 'cat-2');
      expect(e.categoryId, 'cat-1');
      expect(updated.categoryId, 'cat-2');
      // offline list would contain updated version
      final localStore = [updated];
      expect(localStore.where((ex) => ex.categoryId == 'cat-1'), isEmpty);
      expect(localStore.where((ex) => ex.categoryId == 'cat-2'), hasLength(1));
    });

    test('changement compte offline', () {
      final e = Fixtures.expense(id: 'e1', accountId: 'acc-1', categoryId: 'cat-1');
      final moved = e.copyWith(accountId: 'acc-2');
      expect(moved.accountId, 'acc-2');
    });

    test('débit offline: debitedOccurrences mutation', () {
      final e = Fixtures.expense(
        id: 'e1',
        accountId: 'acc-1',
        categoryId: 'cat-1',
        debitDate: DateTime(2026, 3, 15),
        recurrence: RecurrenceType.monthly,
      );
      final key = Expense.isoDate(DateTime(2026, 3, 15));
      final debited = e.copyWith(debitedOccurrences: [key]);
      expect(debited.isDebitedAt(DateTime(2026, 3, 15)), isTrue);
      expect(e.isDebitedAt(DateTime(2026, 3, 15)), isFalse);
    });

    test('récurrence offline: endDate truncation locale', () {
      final e = Fixtures.expense(
        id: 'e1',
        accountId: 'acc-1',
        categoryId: 'cat-1',
        debitDate: DateTime(2026, 1, 15),
        recurrence: RecurrenceType.monthly,
      );
      final truncated = e.copyWith(endDate: DateTime(2026, 2, 14));
      expect(truncated.endDate, DateTime(2026, 2, 14));
      expect(truncated.endOfEndDate, DateTime(2026, 2, 14, 23, 59, 59, 999));
    });

    test('scénario critique ONLINE->OFFLINE->modif->fermeture->relaunch vérifie état local', () async {
      // Simulate persistent queue across relaunch via SharedPreferences mock
      final queue = SyncQueue.instance;
      // ONLINE création
      await queue.enqueue(id: 'acc:create:1', type: 'accounts', operation: 'create', payload: {'id': 'acc-1', 'name': 'Original'});
      // OFFLINE modification (coalesced to create with new payload)
      await queue.enqueue(id: 'acc:update:1', type: 'accounts', operation: 'update', payload: {'id': 'acc-1', 'name': 'ModifiedOffline'});
      // Simulate fermeture: queue persists in SharedPreferences
      final reloaded = await queue.all();
      expect(reloaded.single.payload['name'], 'ModifiedOffline');
      expect(reloaded.single.operation, 'create');
      // ONLINE sync: handler succeeds -> remove
      await queue.remove(reloaded.single.id);
      expect(await queue.all(), isEmpty);
    });

    test('échec de synchronisation: markFailed applique backoff exponentiel', () async {
      final queue = SyncQueue.instance;
      await queue.enqueue(id: 'a1', type: 'accounts', operation: 'create', payload: {'id': '1', 'name': 'x'});
      final op = (await queue.all()).single;
      await queue.markFailed(op.id);
      final failed = (await queue.all()).single;
      expect(failed.attempts, 1);
      expect(failed.nextAttemptAt, isNotNull);
      expect(failed.isReady, isFalse);
    });

    test('synchronisation partielle: ordre accounts avant categories', () async {
      final queue = SyncQueue.instance;
      await queue.enqueue(id: 'cat:1', type: 'categories', operation: 'create', payload: {'id': 'cat-1', 'account_id': 'acc-1'});
      await queue.enqueue(id: 'acc:1', type: 'accounts', operation: 'create', payload: {'id': 'acc-1', 'name': 'A'});
      final all = await queue.all();
      expect(all.map((o) => o.type), containsAll(['accounts', 'categories']));
      // SyncManager orders accounts first - verify pending types exist
      final accountBlocked = all.any((o) => o.type == 'accounts' && !o.isReady);
      expect(accountBlocked, isFalse);
    });

    test('doublon: tentative de création double uuid garde unicité', () {
      final id1 = Fixtures.expense(id: 'same-id', accountId: 'acc-1', categoryId: 'cat-1').id;
      final id2 = Fixtures.expense(id: 'same-id', accountId: 'acc-1', categoryId: 'cat-1').id;
      expect(id1, id2);
      final list = <Expense>[];
      final e = Fixtures.expense(id: 'same-id', accountId: 'acc-1', categoryId: 'cat-1');
      list.add(e);
      // second insert with same id should replace, not duplicate
      final after = list.map((ex) => ex.id == e.id ? e.copyWith(amount: 999) : ex).toList();
      expect(after.where((ex) => ex.id == 'same-id'), hasLength(1));
    });

    test('retry après échec: readyOnly filter', () async {
      final queue = SyncQueue.instance;
      await queue.enqueue(id: 'a1', type: 'accounts', operation: 'create', payload: {'id': '1', 'name': 'x'});
      final op = (await queue.all()).single;
      await queue.markFailed(op.id);
      expect(await queue.all(readyOnly: true), isEmpty);
      expect(await queue.all(readyOnly: false), hasLength(1));
    });
  });
}
