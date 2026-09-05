import 'package:budgly/src/services/auth/auth_service.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthService extends AuthService {
  bool signedOut = false;

  @override
  Future<void> signOut() async {
    signedOut = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SyncManager.instance.resetForTest();
    await SyncQueue.instance.clear();
  });

  tearDown(() async {
    await SyncManager.instance.resetForTest();
    await SyncQueue.instance.clear();
  });

  test('logout waits for pending mutation to synchronize before signing out', () async {
    final auth = _FakeAuthService();
    final service = ProfileService(authService: auth);

    await SyncQueue.instance.enqueue(
      id: 'profile-update',
      type: 'user_profiles',
      operation: 'update',
      payload: {'id': 'u1', 'name': 'Offline'},
    );

    var syncCalls = 0;
    SyncManager.instance.registerHandler('user_profiles', (_) async {
      syncCalls++;
    });

    await service.signOut();

    expect(syncCalls, 1);
    expect(auth.signedOut, isTrue);
    expect(await SyncQueue.instance.all(), isEmpty);
  });

  test('logout does not sign out while a pending mutation still fails', () async {
    final auth = _FakeAuthService();
    final service = ProfileService(authService: auth);

    await SyncQueue.instance.enqueue(
      id: 'profile-offline',
      type: 'user_profiles',
      operation: 'update',
      payload: {'id': 'u1'},
    );
    SyncManager.instance.registerHandler('user_profiles', (_) async {
      throw StateError('offline');
    });

    await expectLater(service.signOut(), throwsStateError);
    expect(auth.signedOut, isFalse);
    expect(await SyncQueue.instance.all(), hasLength(1));
  });
}
