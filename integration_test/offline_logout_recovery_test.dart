import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/auth/auth_service.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sync_test_harness.dart';

class _FakeAuth extends AuthService {
  _FakeAuth() : super(analytics: AnalyticsService());
  bool signedOut = false;

  @override
  Future<void> signOut() async {
    signedOut = true;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await integrationSyncManager.resetForTest();
    await integrationSyncQueue.clear();
  });

  tearDown(() async {
    await integrationSyncManager.resetForTest();
    await integrationSyncQueue.clear();
  });

  testWidgets('logout waits for a recoverable pending mutation', (_) async {
    final auth = _FakeAuth();
    final service = ProfileService(
      authService: auth,
      syncManager: integrationSyncManager,
      syncQueue: integrationSyncQueue,
      analytics: AnalyticsService(),
    );

    await integrationSyncQueue.enqueue(
      id: 'integration-profile',
      type: 'user_profiles',
      operation: 'update',
      payload: {'id': 'u1', 'full_name': 'Offline'},
    );
    integrationSyncManager.registerHandler('user_profiles', (_) async {});

    await service.signOut();

    expect(auth.signedOut, isTrue);
    expect(await integrationSyncQueue.all(), isEmpty);
  });

  testWidgets(
    'logout is never blocked by unavailable synchronization and keeps the pending change',
    (_) async {
      final auth = _FakeAuth();
      final service = ProfileService(
        authService: auth,
        syncManager: integrationSyncManager,
        syncQueue: integrationSyncQueue,
        analytics: AnalyticsService(),
      );

      await integrationSyncQueue.enqueue(
        id: 'integration-profile-offline',
        type: 'user_profiles',
        operation: 'update',
        payload: {'id': 'u1', 'full_name': 'Offline'},
      );
      integrationSyncManager.registerHandler('user_profiles', (_) async {
        throw StateError('offline');
      });

      await service.signOut();

      expect(auth.signedOut, isTrue);
      // Durable and owner-scoped: it is replayed when the same user signs in
      // again instead of being lost or trapping the user in the app.
      expect(await integrationSyncQueue.all(), hasLength(1));
    },
  );
}
