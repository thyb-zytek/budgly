import 'package:budgly/src/state/profile_providers.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/user/user.dart';
import 'package:budgly/src/models/user/user_profile.dart';
import 'package:budgly/src/pages/login/login_provider.dart';
import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/accounts/accounts_service_provider.dart';
import 'package:budgly/src/services/auth/auth_service.dart';
import 'package:budgly/src/services/auth/auth_service_provider.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuth extends AuthService {
  _FakeAuth() : super(analytics: AnalyticsService());
  @override
  User? get currentUser => null;
}

class _FakeAccounts extends AccountsService {
  _FakeAccounts([this.values = const [Account(id: 'a1', name: 'Courant')]])
    : super(
        analytics: AnalyticsService(),
        syncManager: SyncManager(
          queue: SyncQueue(),
          analytics: AnalyticsService(),
        ),
        syncQueue: SyncQueue(),
      );
  final List<Account> values;
  @override
  Future<List<Account>> loadAccounts({
    bool forceRefresh = false,
    void Function(List<Account>)? onRevalidated,
  }) async => values;
}

class _FakeProfile extends ProfileService {
  _FakeProfile(this.seeded)
    : super(
        analytics: AnalyticsService(),
        syncManager: SyncManager(
          queue: SyncQueue(),
          analytics: AnalyticsService(),
        ),
        syncQueue: SyncQueue(),
      );
  final User seeded;

  @override
  Future<User?> loadUserProfile({bool forceRefresh = false}) async => seeded;
}

ProviderContainer _container(User user, {List<Account>? accounts}) =>
    ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(_FakeAuth()),
        profileServiceProvider.overrideWithValue(_FakeProfile(user)),
        accountsServiceProvider.overrideWithValue(
          accounts == null ? _FakeAccounts() : _FakeAccounts(accounts),
        ),
      ],
    );

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('returning user resumes unfinished onboarding before overview', (
    _,
  ) async {
    final user = User(
      id: 'u1',
      emailVerified: true,
      profile: UserProfile(
        id: 'u1',
        email: 'test@example.com',
        fullName: 'Test',
        onboardingCompleted: false,
      ),
    );
    final container = _container(user);
    addTearDown(container.dispose);

    expect(
      await container
          .read(loginProvider.notifier)
          .resolvePostAuthDestination(user),
      AuthDestination.tutorial,
    );
  });

  testWidgets('completed user with an existing account goes to overview', (
    _,
  ) async {
    final user = User(
      id: 'u1',
      emailVerified: true,
      profile: UserProfile(
        id: 'u1',
        email: 'test@example.com',
        fullName: 'Test',
        onboardingCompleted: true,
      ),
    );
    final container = _container(user);
    addTearDown(container.dispose);

    expect(
      await container
          .read(loginProvider.notifier)
          .resolvePostAuthDestination(user),
      AuthDestination.overview,
    );
  });

  testWidgets(
    'completed user with zero accounts still goes to overview, not back into '
    'the tutorial (RL-01 §2: the profile flag decides, not the account count)',
    (_) async {
      final user = User(
        id: 'u1',
        emailVerified: true,
        profile: UserProfile(
          id: 'u1',
          email: 'test@example.com',
          fullName: 'Test',
          onboardingCompleted: true,
        ),
      );
      final container = _container(user, accounts: const []);
      addTearDown(container.dispose);

      expect(
        await container
            .read(loginProvider.notifier)
            .resolvePostAuthDestination(user),
        AuthDestination.overview,
      );
    },
  );
}
