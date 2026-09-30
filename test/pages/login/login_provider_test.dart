import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:budgly/src/core/auth/auth_exception.dart';
import 'package:budgly/src/core/auth/auth_state.dart';
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
import 'package:budgly/src/state/profile_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAuthService extends AuthService {
  FakeAuthService(this.user) : super(analytics: AnalyticsService());
  final User? user;

  User? signInUser;
  User? signUpUser;
  User? googleUser;
  User? reloadUser;
  Object? signInError;
  Object? signUpError;
  Object? googleError;
  Object? reloadError;
  Object? resetError;
  Object? resendError;
  int resetCalls = 0;
  int resendCalls = 0;

  @override
  User? get currentUser => user;

  @override
  fb.User? get firebaseUser => null;

  @override
  Future<User> signInWithEmailAndPassword(String email, String password) async {
    if (signInError != null) throw signInError!;
    return signInUser!;
  }

  @override
  Future<User> signUpWithEmailAndPassword(String email, String password) async {
    if (signUpError != null) throw signUpError!;
    return signUpUser!;
  }

  @override
  Future<User> signInWithGoogle() async {
    if (googleError != null) throw googleError!;
    return googleUser!;
  }

  @override
  Future<User?> reloadCurrentUser() async {
    if (reloadError != null) throw reloadError!;
    return reloadUser;
  }

  @override
  Future<void> resetPassword(String email) async {
    resetCalls++;
    if (resetError != null) throw resetError!;
  }

  @override
  Future<void> sendEmailVerification() async {
    resendCalls++;
    if (resendError != null) throw resendError!;
  }
}

class FakeProfileService extends ProfileService {
  FakeProfileService({this.userToReturn})
    : super(
        analytics: AnalyticsService(),
        syncManager: SyncManager(
          queue: SyncQueue(),
          analytics: AnalyticsService(),
        ),
        syncQueue: SyncQueue(),
      );
  final User? userToReturn;
  bool shouldThrowOnLoad = false;
  bool shouldThrowOnSignOut = false;
  int loadCalls = 0;
  int signOutCalls = 0;

  @override
  Future<User?> loadUserProfile({bool forceRefresh = false}) async {
    loadCalls++;
    if (shouldThrowOnLoad) throw StateError('profile offline');
    return userToReturn;
  }

  @override
  Future<User?> refreshFromServer() async => null;

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (shouldThrowOnSignOut) throw StateError('sign out failed');
  }
}

class FakeAccountsService extends AccountsService {
  FakeAccountsService(this.seededAccounts)
    : super(
        analytics: AnalyticsService(),
        syncManager: SyncManager(
          queue: SyncQueue(),
          analytics: AnalyticsService(),
        ),
        syncQueue: SyncQueue(),
      );
  final List<Account> seededAccounts;
  bool shouldThrow = false;

  @override
  Future<List<Account>> loadAccounts({
    bool forceRefresh = false,
    void Function(List<Account>)? onRevalidated,
  }) async {
    if (shouldThrow) throw StateError('offline');
    return seededAccounts;
  }
}

ProviderContainer _container({
  required FakeAuthService auth,
  FakeProfileService? profile,
  FakeAccountsService? accounts,
}) {
  final container = ProviderContainer(
    overrides: [
      authServiceProvider.overrideWithValue(auth),
      profileServiceProvider.overrideWithValue(profile ?? FakeProfileService()),
      accountsServiceProvider.overrideWithValue(
        accounts ?? FakeAccountsService(const []),
      ),
    ],
  );
  // Keep loginProvider alive so the async sign-in flow completes, mirroring
  // the LoginPage widget that watches it in production.
  container.listen(loginProvider, (_, _) {});
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('initial state uses sign-in when there is no current user', () {
    final container = _container(auth: FakeAuthService(null));
    addTearDown(container.dispose);
    final state = container.read(loginProvider);
    expect(state.formType, AuthForm.signIn);
    expect(state.isLoading, isFalse);
    expect(state.currentUser, isNull);
  });

  test('initial state uses email verification for an unverified user', () {
    const user = User(
      id: 'u1',
      email: 'user@example.com',
      emailVerified: false,
    );
    final container = _container(auth: FakeAuthService(user));
    addTearDown(container.dispose);
    final state = container.read(loginProvider);
    expect(state.formType, AuthForm.verifyEmail);
    expect(state.currentUser, user);
  });

  test(
    'initializeFormType selects sign-up on first launch and records it',
    () async {
      final container = _container(auth: FakeAuthService(null));
      addTearDown(container.dispose);
      await container.read(loginProvider.notifier).initializeFormType();
      expect(container.read(loginProvider).formType, AuthForm.signUp);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('hasLaunched'), isTrue);
    },
  );

  test('initializeFormType selects sign-in after the first launch', () async {
    SharedPreferences.setMockInitialValues({'hasLaunched': true});
    final container = _container(auth: FakeAuthService(null));
    addTearDown(container.dispose);
    await container.read(loginProvider.notifier).initializeFormType();
    expect(container.read(loginProvider).formType, AuthForm.signIn);
  });

  test('validators distinguish required, malformed and valid values', () {
    expect(validateLoginEmail(null), 'emailRequired');
    expect(validateLoginEmail('invalid'), 'emailInvalid');
    expect(validateLoginEmail('a@b.fr'), isNull);
    expect(validateLoginPassword(null), 'passwordRequired');
    expect(validateLoginPassword('12345'), 'passwordTooShort');
    expect(validateLoginPassword('123456'), isNull);
    expect(
      validateLoginConfirmPassword(null, 'secret'),
      'confirmPasswordRequired',
    );
    expect(
      validateLoginConfirmPassword('different', 'secret'),
      'passwordsDoNotMatch',
    );
    expect(validateLoginConfirmPassword('secret', 'secret'), isNull);
  });

  test('changing form type clears authentication state', () {
    final container = _container(auth: FakeAuthService(null));
    addTearDown(container.dispose);
    container
        .read(loginProvider.notifier)
        .changeFormType(AuthForm.resetPassword);
    expect(container.read(loginProvider).formType, AuthForm.resetPassword);
    expect(container.read(loginProvider).errorCode, isNull);
    expect(container.read(loginProvider).isLoading, isFalse);
  });

  test('sign-up moves to email verification', () async {
    const user = User(id: 'u1', email: 'new@example.com', emailVerified: false);
    final auth = FakeAuthService(null)..signUpUser = user;
    final profile = FakeProfileService(userToReturn: user);
    final container = _container(auth: auth, profile: profile);
    addTearDown(container.dispose);
    final result = await container
        .read(loginProvider.notifier)
        .signUp(email: 'new@example.com', password: 'secret');
    final state = container.read(loginProvider);
    expect(result, isNull);
    expect(state.formType, AuthForm.verifyEmail);
    expect(state.currentUser, user);
    expect(state.isLoading, isFalse);
  });

  test(
    'verified sign-in returns the authenticated user and loads profile',
    () async {
      const user = User(
        id: 'u1',
        email: 'user@example.com',
        emailVerified: true,
      );
      final auth = FakeAuthService(null)..signInUser = user;
      final profile = FakeProfileService(userToReturn: user);
      final container = _container(auth: auth, profile: profile);
      addTearDown(container.dispose);
      final result = await container
          .read(loginProvider.notifier)
          .signIn(email: user.email!, password: 'secret');
      expect(result, user);
      expect(profile.loadCalls, greaterThanOrEqualTo(1));
      final session = container.read(profileSessionProvider);
      expect(session.hasLoaded, isTrue);
      expect(session.currentUser, user);
      expect(container.read(loginProvider).isLoading, isFalse);
    },
  );

  test('unverified sign-in switches to email verification', () async {
    const user = User(
      id: 'u1',
      email: 'user@example.com',
      emailVerified: false,
    );
    final auth = FakeAuthService(null)..signInUser = user;
    final container = _container(auth: auth);
    addTearDown(container.dispose);
    final result = await container
        .read(loginProvider.notifier)
        .signIn(email: user.email!, password: 'secret');
    expect(result, isNull);
    expect(container.read(loginProvider).formType, AuthForm.verifyEmail);
    expect(container.read(loginProvider).currentUser, user);
  });

  test('reset password returns to sign-in', () async {
    final auth = FakeAuthService(null);
    final container = _container(auth: auth);
    addTearDown(container.dispose);
    await container
        .read(loginProvider.notifier)
        .resetPassword('reset@example.com');
    expect(auth.resetCalls, 1);
    expect(container.read(loginProvider).formType, AuthForm.signIn);
    expect(container.read(loginProvider).isLoading, isFalse);
  });

  test('authentication errors are exposed in state', () async {
    final auth = FakeAuthService(null)
      ..signInError = const AuthenticationException(
        code: 'bad-login',
        message: 'Bad credentials',
      );
    final container = _container(auth: auth);
    addTearDown(container.dispose);
    await container
        .read(loginProvider.notifier)
        .signIn(email: 'a@b.fr', password: 'secret');
    final state = container.read(loginProvider);
    expect(state.errorCode, 'bad-login');
    expect(state.errorMessage, 'Bad credentials');
    expect(state.isLoading, isFalse);
  });

  test('google sign-in returns the user and loads profile', () async {
    const user = User(
      id: 'u1',
      email: 'google@example.com',
      emailVerified: true,
    );
    final auth = FakeAuthService(null)..googleUser = user;
    final profile = FakeProfileService(userToReturn: user);
    final container = _container(auth: auth, profile: profile);
    addTearDown(container.dispose);
    expect(
      await container.read(loginProvider.notifier).signInWithGoogle(),
      user,
    );
    expect(profile.loadCalls, greaterThanOrEqualTo(1));
    final session = container.read(profileSessionProvider);
    expect(session.hasLoaded, isTrue);
    expect(session.currentUser, user);
    expect(container.read(loginProvider).isGoogleSignIn, isFalse);
  });

  test('sign-out clears the authenticated state', () async {
    const user = User(id: 'u1', email: 'user@example.com', emailVerified: true);
    final auth = FakeAuthService(user);
    final profile = FakeProfileService();
    final container = _container(auth: auth, profile: profile);
    addTearDown(container.dispose);
    await container.read(loginProvider.notifier).signOut();
    expect(profile.signOutCalls, 1);
    expect(container.read(loginProvider).currentUser, isNull);
    expect(container.read(loginProvider).formType, AuthForm.signUp);
  });

  test(
    'post-auth routing goes to overview when onboarding is completed '
    '(RL-01 §2: the profile flag decides, not whether accounts exist)',
    () async {
      final user = User(
        id: 'u1',
        emailVerified: true,
        profile: UserProfile(
          id: 'u1',
          email: 'user@example.com',
          fullName: 'User',
          onboardingCompleted: true,
        ),
      );
      final container = _container(auth: FakeAuthService(null));
      addTearDown(container.dispose);
      expect(
        await container
            .read(loginProvider.notifier)
            .resolvePostAuthDestination(user),
        AuthDestination.overview,
      );
    },
  );

  test('post-auth routing goes to overview even with zero accounts once '
      'onboarding is completed (the user may have deleted them all)', () async {
    final user = User(
      id: 'u1',
      emailVerified: true,
      profile: UserProfile(
        id: 'u1',
        email: 'user@example.com',
        fullName: 'User',
        onboardingCompleted: true,
      ),
    );
    final container = _container(
      auth: FakeAuthService(null),
      accounts: FakeAccountsService(const []),
    );
    addTearDown(container.dispose);
    expect(
      await container
          .read(loginProvider.notifier)
          .resolvePostAuthDestination(user),
      AuthDestination.overview,
    );
  });

  test(
    'post-auth routing enters the tutorial when there is no profile yet '
    '(e.g. a brand-new sign-up before the profile has been created)',
    () async {
      const user = User(id: 'u1', emailVerified: true);
      final container = _container(
        auth: FakeAuthService(null),
        accounts: FakeAccountsService([const Account(id: 'a1', name: 'Main')]),
      );
      addTearDown(container.dispose);
      expect(
        await container
            .read(loginProvider.notifier)
            .resolvePostAuthDestination(user),
        AuthDestination.tutorial,
      );
    },
  );

  test('post-auth routing resumes unfinished onboarding', () async {
    final user = User(
      id: 'u1',
      emailVerified: true,
      profile: UserProfile(
        id: 'u1',
        email: 'user@example.com',
        fullName: 'User',
        onboardingCompleted: false,
      ),
    );
    final container = _container(
      auth: FakeAuthService(null),
      accounts: FakeAccountsService([const Account(id: 'a1', name: 'Main')]),
    );
    addTearDown(container.dispose);
    expect(
      await container
          .read(loginProvider.notifier)
          .resolvePostAuthDestination(user),
      AuthDestination.tutorial,
    );
  });
}
