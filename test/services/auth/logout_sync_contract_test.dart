import 'package:budgly/src/services/auth/auth_service.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';

class _FakeAuthService extends AuthService {
  bool signedOut = false;

  _FakeAuthService({required super.analytics});

  @override
  Future<void> signOut() async {
    signedOut = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await testSyncManager.resetForTest();
    await testSyncQueue.clear();
  });

  tearDown(() async {
    await testSyncManager.resetForTest();
    await testSyncQueue.clear();
  });

  test('logout first replays pending mutations, then signs out', () async {
    final analytics = AnalyticsService();
    final auth = _FakeAuthService(analytics: analytics);
    final service = ProfileService(
      authService: auth,
      analytics: analytics,
      syncManager: testSyncManager,
      syncQueue: testSyncQueue,
    );

    await testSyncQueue.enqueue(
      id: 'profile-update',
      type: 'user_profiles',
      operation: 'update',
      payload: {'id': 'u1', 'name': 'Offline'},
    );

    var syncCalls = 0;
    testSyncManager.registerHandler('user_profiles', (_) async {
      syncCalls++;
    });

    await service.signOut();

    expect(syncCalls, 1);
    expect(auth.signedOut, isTrue);
    expect(await testSyncQueue.all(), isEmpty);
  });

  test(
    'logout still signs out when a pending mutation keeps failing, and keeps it queued',
    () async {
      final analytics = AnalyticsService();
      final auth = _FakeAuthService(analytics: analytics);
      final service = ProfileService(
        authService: auth,
        analytics: analytics,
        syncManager: testSyncManager,
        syncQueue: testSyncQueue,
      );

      await testSyncQueue.enqueue(
        id: 'profile-offline',
        type: 'user_profiles',
        operation: 'update',
        payload: {'id': 'u1'},
      );
      testSyncManager.registerHandler('user_profiles', (_) async {
        throw StateError('offline');
      });

      // A failing/offline queue must never trap the user in the app.
      await service.signOut();

      expect(auth.signedOut, isTrue);
      // Nothing is lost: the operation stays durable for the next sign-in of
      // the user who created it.
      expect(await testSyncQueue.all(), hasLength(1));
    },
  );
}
