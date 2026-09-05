import 'package:budgly/src/services/auth/auth_service.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuth extends AuthService {
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
    await SyncManager.instance.resetForTest();
    await SyncQueue.instance.clear();
  });

  tearDown(() async {
    await SyncManager.instance.resetForTest();
    await SyncQueue.instance.clear();
  });

  testWidgets('logout waits for a recoverable pending mutation', (_) async {
    final auth = _FakeAuth();
    final service = ProfileService(authService: auth);

    await SyncQueue.instance.enqueue(
      id: 'integration-profile',
      type: 'user_profiles',
      operation: 'update',
      payload: {'id': 'u1', 'full_name': 'Offline'},
    );
    SyncManager.instance.registerHandler('user_profiles', (_) async {});

    await service.signOut();

    expect(auth.signedOut, isTrue);
    expect(await SyncQueue.instance.all(), isEmpty);
  });

  testWidgets('logout remains blocked while synchronization is unavailable', (_) async {
    final auth = _FakeAuth();
    final service = ProfileService(authService: auth);

    await SyncQueue.instance.enqueue(
      id: 'integration-profile-offline',
      type: 'user_profiles',
      operation: 'update',
      payload: {'id': 'u1', 'full_name': 'Offline'},
    );
    SyncManager.instance.registerHandler('user_profiles', (_) async {
      throw StateError('offline');
    });

    await expectLater(service.signOut(), throwsStateError);
    expect(auth.signedOut, isFalse);
    expect(await SyncQueue.instance.all(), hasLength(1));
  });
}
