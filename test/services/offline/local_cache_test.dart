import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/user/user_profile.dart';
import 'package:budgly/src/services/offline/local_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late LocalCache cache;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() async {
    cache = LocalCache();
  });

  tearDown(() async {
    // LocalCache keeps a static reference to SharedPreferences, so the mock
    // store must not be re-created between tests (that would orphan the
    // already-resolved instance). Instead, clear the keys we touched.
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      'offline.accounts.user-1',
      'offline.accounts.user-2',
      'offline.accounts.nobody',
      'offline.categories.acc-1',
      'offline.categories.acc-2',
      'offline.categories.nobody',
      'offline.profile.user-1',
      'offline.profile.nobody',
    ]) {
      await prefs.remove(key);
    }
  });

  Account buildAccount({
    String id = 'acc-1',
    String? userId = 'user-1',
    String name = 'Checking',
  }) {
    return Account(id: id, userId: userId, name: name, color: Colors.blue);
  }

  Category buildCategory({
    String? id = 'cat-1',
    String accountId = 'acc-1',
    String name = 'Groceries',
  }) {
    return Category(
      id: id,
      name: name,
      color: Colors.green,
      iconCode: '0x10',
      accountId: accountId,
    );
  }

  UserProfile buildProfile() {
    return UserProfile(
      id: 'user-1',
      email: 'a@b.c',
      fullName: 'Ada',
      color: Colors.red,
      themeMode: 'dark',
      currency: 'USD',
      amountDecimalPlaces: 1,
      language: 'en',
      onboardingCompleted: true,
      createdAt: DateTime(2026, 1, 2, 3, 4, 5),
      updatedAt: DateTime(2026, 2, 3, 4, 5, 6),
    );
  }

  group('accounts cache', () {
    test('round-trips accounts through save/load', () async {
      final account = buildAccount();
      await cache.saveAccounts('user-1', [account]);

      final loaded = await cache.loadAccounts('user-1');
      expect(loaded, isNotNull);
      expect(loaded, hasLength(1));
      expect(loaded!.single.id, 'acc-1');
      expect(loaded.single.name, 'Checking');
      expect(loaded.single.userId, 'user-1');
    });

    test('storage is isolated per user id', () async {
      await cache.saveAccounts('user-1', [buildAccount(name: 'A')]);
      await cache.saveAccounts('user-2', [buildAccount(name: 'B', userId: 'user-2')]);

      final user1 = await cache.loadAccounts('user-1');
      final user2 = await cache.loadAccounts('user-2');
      expect(user1!.single.name, 'A');
      expect(user2!.single.name, 'B');
      expect(user1.single.name, isNot(user2.single.name));
    });

    test('returns null when nothing was cached for a user', () async {
      expect(await cache.loadAccounts('nobody'), isNull);
    });

    test('returns empty list when cached JSON is corrupted', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('offline.accounts.user-1', 'not-valid-json');
      final loaded = await cache.loadAccounts('user-1');
      expect(loaded, isEmpty);
    });
  });

  group('categories cache', () {
    test('round-trips categories through save/load', () async {
      final category = buildCategory();
      await cache.saveCategories('acc-1', [category]);

      final loaded = await cache.loadCategories('acc-1');
      expect(loaded, isNotNull);
      expect(loaded, hasLength(1));
      expect(loaded!.single.id, 'cat-1');
      expect(loaded.single.name, 'Groceries');
      expect(loaded.single.accountId, 'acc-1');
    });

    test('storage is isolated per account id', () async {
      await cache.saveCategories('acc-1', [buildCategory(name: 'A')]);
      await cache.saveCategories('acc-2',
          [buildCategory(id: 'cat-2', accountId: 'acc-2', name: 'B')]);

      final acc1 = await cache.loadCategories('acc-1');
      final acc2 = await cache.loadCategories('acc-2');
      expect(acc1!.single.name, 'A');
      expect(acc2!.single.name, 'B');
    });

    test('returns null when nothing was cached for an account', () async {
      expect(await cache.loadCategories('nobody'), isNull);
    });

    test('returns empty list when cached JSON is corrupted', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('offline.categories.acc-1', 'garbage[[[');
      expect(await cache.loadCategories('acc-1'), isEmpty);
    });

    test('clearAccount removes only that account categories', () async {
      await cache.saveCategories('acc-1', [buildCategory()]);
      await cache.saveCategories('acc-2',
          [buildCategory(id: 'cat-2', accountId: 'acc-2')]);

      await cache.clearAccount('acc-1');

      expect(await cache.loadCategories('acc-1'), isNull);
      expect(await cache.loadCategories('acc-2'), isNotNull);
    });
  });

  group('profile cache', () {
    test('round-trips a profile through save/load', () async {
      final profile = buildProfile();
      await cache.saveProfile('user-1', profile);

      final loaded = await cache.loadProfile('user-1');
      expect(loaded, isNotNull);
      expect(loaded!.fullName, 'Ada');
      expect(loaded.email, 'a@b.c');
      expect(loaded.currency, 'USD');
      expect(loaded.amountDecimalPlaces, 1);
      expect(loaded.language, 'en');
    });

    test('returns null when nothing was cached for a user', () async {
      expect(await cache.loadProfile('nobody'), isNull);
    });

    test('returns null when cached JSON is corrupted', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('offline.profile.user-1', '{{not json');
      expect(await cache.loadProfile('user-1'), isNull);
    });
  });

  group('clearUser', () {
    test('removes accounts and profile for a user', () async {
      await cache.saveAccounts('user-1', [buildAccount()]);
      final account = buildAccount();
      await cache.saveAccounts('user-1', [account]);
      await cache.saveProfile('user-1', buildProfile());

      await cache.clearUser('user-1');

      expect(await cache.loadAccounts('user-1'), isNull);
      expect(await cache.loadProfile('user-1'), isNull);
    });

    test('does not affect other users data', () async {
      await cache.saveAccounts('user-1', [buildAccount()]);
      await cache.saveAccounts('user-2', [buildAccount(userId: 'user-2')]);

      await cache.clearUser('user-1');

      expect(await cache.loadAccounts('user-2'), isNotNull);
    });
  });
}
