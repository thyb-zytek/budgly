import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/services/offline/local_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('LocalCache resolves SharedPreferences lazily after test bootstrap', () async {
    final cache = LocalCache();
    const account = Account(
      id: 'a1',
      userId: 'u1',
      name: 'Main',
    );
    await cache.saveAccounts('u1', [account]);
    final loaded = await cache.loadAccounts('u1');
    expect(loaded, isNotNull);
    expect(loaded!.single.id, 'a1');
  });
}
