import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SyncQueue queue;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() async {
    queue = SyncQueue.instance;
    await queue.clear();
  });

  test('coalesces create followed by update', () async {
    await queue.enqueue(
      id: 'account:create:1',
      type: 'accounts',
      operation: 'create',
      payload: {'id': '1', 'name': 'Old'},
    );
    await queue.enqueue(
      id: 'account:update:1',
      type: 'accounts',
      operation: 'update',
      payload: {'id': '1', 'name': 'New'},
    );

    final operations = await queue.all();
    expect(operations, hasLength(1));
    expect(operations.single.operation, 'create');
    expect(operations.single.payload['name'], 'New');
  });

  test('cancels create followed by delete', () async {
    await queue.enqueue(
      id: 'category:create:1',
      type: 'categories',
      operation: 'create',
      payload: {'id': '1', 'account_id': 'account'},
    );
    await queue.enqueue(
      id: 'category:delete:1',
      type: 'categories',
      operation: 'delete',
      payload: {'id': '1', 'account_id': 'account'},
    );

    expect(await queue.all(), isEmpty);
  });
}
