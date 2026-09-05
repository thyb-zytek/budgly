import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/user/user_profile.dart';
import 'package:budgly/src/stores/accounts.dart';
import 'package:budgly/src/stores/categories.dart';
import 'package:budgly/src/stores/expenses.dart';
import 'package:budgly/src/services/offline/local_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/builders.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  setUp(() {
    AccountsStore.instance.clearLocalAccounts();
    CategoriesStore.instance.clearAll();
    ExpensesStore.instance.clearAll();
  });

  group('Persistent local cache CRUD', () {
    test('account cache create/read/update/delete lifecycle', () async {
      final cache = LocalCacheForTest();
      final first = Fixtures.account(id: 'a1', name: 'Compte A');
      final updated = first.copyWith(name: 'Compte A modifié');

      await cache.saveAccounts('u1', [first]);
      expect((await cache.loadAccounts('u1'))!.single.name, 'Compte A');

      await cache.saveAccounts('u1', [updated]);
      expect((await cache.loadAccounts('u1'))!.single.name, 'Compte A modifié');

      await cache.clearUser('u1');
      expect(await cache.loadAccounts('u1'), isNull);
    });

    test('category cache create/read/update/delete lifecycle', () async {
      final cache = LocalCacheForTest();
      final first = Fixtures.category(id: 'c1', accountId: 'a1', name: 'Food');
      final updated = first.copyWith(name: 'Alimentation');

      await cache.saveCategories('a1', [first]);
      expect((await cache.loadCategories('a1'))!.single.name, 'Food');

      await cache.saveCategories('a1', [updated]);
      expect((await cache.loadCategories('a1'))!.single.name, 'Alimentation');

      await cache.clearAccount('a1');
      expect(await cache.loadCategories('a1'), isNull);
    });

    test('profile cache create/read/update/delete lifecycle', () async {
      final cache = LocalCacheForTest();
      final first = Fixtures.profile(id: 'u1', fullName: 'Alexis');
      final updated = first.copyWith(fullName: 'Alexis Updated');

      await cache.saveProfile('u1', first);
      expect((await cache.loadProfile('u1'))!.fullName, 'Alexis');

      await cache.saveProfile('u1', updated);
      expect((await cache.loadProfile('u1'))!.fullName, 'Alexis Updated');

      await cache.clearUser('u1');
      expect(await cache.loadProfile('u1'), isNull);
    });
  });

  group('In-memory cache propagation', () {
    test('account CRUD notifies every active consumer', () {
      final store = AccountsStore.instance;
      var screenA = 0;
      var screenB = 0;
      void listenerA() => screenA++;
      void listenerB() => screenB++;
      store.addListener(listenerA);
      store.addListener(listenerB);
      addTearDown(() {
        store.removeListener(listenerA);
        store.removeListener(listenerB);
      });

      final account = Fixtures.account(id: 'a1', name: 'A');
      store.addAccount(account);
      store.updateAccount(account.copyWith(name: 'A updated'));
      store.removeAccount('a1');

      expect(screenA, 3);
      expect(screenB, 3);
    });

    test('category CRUD propagates to all active consumers', () {
      final store = CategoriesStore.instance;
      var notifications = 0;
      void listener() => notifications++;
      store.addListener(listener);
      addTearDown(() => store.removeListener(listener));

      final category = Fixtures.category(id: 'c1', accountId: 'a1', name: 'Food');
      store.addCategory(category);
      store.updateCategory(category.copyWith(name: 'Food updated'));
      store.removeCategory('c1');

      expect(notifications, 3);
      expect(store.getCategoriesForAccount('a1'), isEmpty);
    });
  });
}

/// Adapter kept in tests so cache CRUD tests do not couple their intent to a
/// particular production import layout.
class LocalCacheForTest {
  final _cache = LocalCache();
  Future<void> saveAccounts(String userId, List<Account> value) => _cache.saveAccounts(userId, value);
  Future<List<Account>?> loadAccounts(String userId) => _cache.loadAccounts(userId);
  Future<void> saveCategories(String id, List<Category> value) => _cache.saveCategories(id, value);
  Future<List<Category>?> loadCategories(String id) => _cache.loadCategories(id);
  Future<void> saveProfile(String id, UserProfile value) => _cache.saveProfile(id, value);
  Future<UserProfile?> loadProfile(String id) => _cache.loadProfile(id);
  Future<void> clearUser(String id) => _cache.clearUser(id);
  Future<void> clearAccount(String id) => _cache.clearAccount(id);
}
