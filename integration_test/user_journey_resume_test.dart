import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/user/user.dart';
import 'package:budgly/src/models/user/user_profile.dart';
import 'package:budgly/src/pages/login/view_model.dart';
import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/auth/auth_service.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

class _FakeAuth extends AuthService {
  @override
  User? get currentUser => null;
}

class _FakeAccounts extends AccountsService {
  @override
  List<Account> get accounts => const [Account(id: 'a1', name: 'Courant')];

  @override
  Future<void> loadAccounts({bool forceRefresh = false}) async {}
}

class _FakeProfile extends ProfileService {
  final User seeded;
  _FakeProfile(this.seeded);

  @override
  User? get currentUser => seeded;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('returning user resumes unfinished onboarding before overview', (_) async {
    final user = User(
      id: 'u1',
      emailVerified: true,
      profile: UserProfile(id: 'u1', email: 'test@example.com', fullName: 'Test', onboardingCompleted: false),
    );
    final vm = LoginViewModel(
      authService: _FakeAuth(),
      profileService: _FakeProfile(user),
      accountsService: _FakeAccounts(),
    );
    addTearDown(vm.dispose);

    expect(
      await vm.resolvePostAuthDestination(user),
      AuthDestination.tutorial,
    );
  });

  testWidgets('completed user with an existing account goes to overview', (_) async {
    final user = User(
      id: 'u1',
      emailVerified: true,
      profile: UserProfile(id: 'u1', email: 'test@example.com', fullName: 'Test', onboardingCompleted: true),
    );
    final vm = LoginViewModel(
      authService: _FakeAuth(),
      profileService: _FakeProfile(user),
      accountsService: _FakeAccounts(),
    );
    addTearDown(vm.dispose);

    expect(
      await vm.resolvePostAuthDestination(user),
      AuthDestination.overview,
    );
  });
}
