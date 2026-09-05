import 'package:budgly/src/core/auth/auth_event.dart';
import 'package:budgly/src/core/auth/auth_exception.dart';
import 'package:budgly/src/core/auth/auth_state.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/user/user.dart';
import 'package:budgly/src/models/user/user_profile.dart';
import 'package:budgly/src/pages/login/view_model.dart';
import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/auth/auth_service.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAuthService extends AuthService {
  final User? user;
  FakeAuthService(this.user);
  @override
  User? get currentUser => user;

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
  final User? seededUser;
  FakeProfileService(this.seededUser);
  @override
  User? get currentUser => seededUser;

  bool shouldThrowOnLoad = false;
  bool shouldThrowOnSignOut = false;
  int loadCalls = 0;
  int signOutCalls = 0;

  @override
  Future<void> loadUserProfile({bool forceRefresh = false}) async {
    loadCalls++;
    if (shouldThrowOnLoad) throw StateError('profile offline');
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (shouldThrowOnSignOut) throw StateError('sign out failed');
  }
}

class FakeAccountsService extends AccountsService {
  final List<Account> seededAccounts;
  bool shouldThrow = false;
  FakeAccountsService(this.seededAccounts);
  @override
  List<Account> get accounts => seededAccounts;
  @override
  Future<void> loadAccounts({bool forceRefresh = false}) async {
    if (shouldThrow) throw StateError('offline');
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('initial state uses sign-in form when there is no current user', () {
    final vm = LoginViewModel(
      authService: FakeAuthService(null),
      profileService: ProfileService(),
      accountsService: FakeAccountsService(const []),
    );
    addTearDown(vm.dispose);

    expect(vm.state.formType, AuthForm.signIn);
    expect(vm.state.isLoading, isFalse);
    expect(vm.state.currentUser, isNull);
  });

  test('initial state switches to email verification for an unverified user', () {
    final user = User(id: 'u1', email: 'test@example.com', emailVerified: false);
    final vm = LoginViewModel(
      authService: FakeAuthService(user),
      profileService: ProfileService(),
      accountsService: FakeAccountsService(const []),
    );
    addTearDown(vm.dispose);

    expect(vm.state.formType, AuthForm.verifyEmail);
    expect(vm.state.currentUser, user);
    expect(vm.state.isLoading, isFalse);
  });

  test('initializeFormType selects sign-up on first launch and records the launch', () async {
    SharedPreferences.setMockInitialValues({});
    final vm = LoginViewModel(
      authService: FakeAuthService(null),
      profileService: ProfileService(),
      accountsService: FakeAccountsService(const []),
    );
    addTearDown(vm.dispose);

    await vm.initializeFormType();

    expect(vm.state.formType, AuthForm.signUp);
    expect((await SharedPreferences.getInstance()).getBool('hasLaunched'), isTrue);
  });

  test('initializeFormType selects sign-in after the first launch', () async {
    SharedPreferences.setMockInitialValues({'hasLaunched': true});
    final vm = LoginViewModel(
      authService: FakeAuthService(null),
      profileService: ProfileService(),
      accountsService: FakeAccountsService(const []),
    );
    addTearDown(vm.dispose);

    await vm.initializeFormType();

    expect(vm.state.formType, AuthForm.signIn);
  });

  test('resolvePostAuthDestination goes to overview when accounts exist', () async {
    final accounts = FakeAccountsService([const Account(id: 'a1', name: 'Compte')]);
    final vm = LoginViewModel(
      authService: FakeAuthService(null),
      profileService: ProfileService(),
      accountsService: accounts,
    );
    addTearDown(vm.dispose);

    expect(
      await vm.resolvePostAuthDestination(User(id: 'u1', emailVerified: true)),
      AuthDestination.overview,
    );
  });

  test('resolvePostAuthDestination resumes an unfinished onboarding journey', () async {
    final vm = LoginViewModel(
      authService: FakeAuthService(null),
      profileService: FakeProfileService(
        User(
          id: 'u1',
          emailVerified: true,
          profile: UserProfile(id: 'u1', email: 'test@example.com', fullName: 'Test', onboardingCompleted: false),
        ),
      ),
      accountsService: FakeAccountsService([
        const Account(id: 'a1', name: 'Compte'),
      ]),
    );
    addTearDown(vm.dispose);

    expect(
      await vm.resolvePostAuthDestination(
        User(
          id: 'u1',
          emailVerified: true,
          profile: UserProfile(id: 'u1', email: 'test@example.com', fullName: 'Test', onboardingCompleted: false),
        ),
      ),
      AuthDestination.tutorial,
    );
  });

  test('resolvePostAuthDestination falls back to tutorial without accounts', () async {
    final vm = LoginViewModel(
      authService: FakeAuthService(null),
      profileService: ProfileService(),
      accountsService: FakeAccountsService(const []),
    );
    addTearDown(vm.dispose);

    expect(
      await vm.resolvePostAuthDestination(User(id: 'u1', emailVerified: true)),
      AuthDestination.tutorial,
    );
  });

  test('resolvePostAuthDestination fails safe to tutorial when account loading fails', () async {
    final accounts = FakeAccountsService(const [])..shouldThrow = true;
    final vm = LoginViewModel(
      authService: FakeAuthService(null),
      profileService: ProfileService(),
      accountsService: accounts,
    );
    addTearDown(vm.dispose);

    expect(
      await vm.resolvePostAuthDestination(User(id: 'u1', emailVerified: true)),
      AuthDestination.tutorial,
    );
  });

  test('form validators distinguish required, malformed and valid values', () {
    final vm = LoginViewModel(
      authService: FakeAuthService(null),
      profileService: ProfileService(),
      accountsService: FakeAccountsService(const []),
    );
    addTearDown(vm.dispose);

    expect(vm.validateEmail(null), 'emailRequired');
    expect(vm.validateEmail('invalid'), 'emailInvalid');
    expect(vm.validateEmail('a@b.fr'), isNull);
    expect(vm.validatePassword(null), 'passwordRequired');
    expect(vm.validatePassword('12345'), 'passwordTooShort');
    expect(vm.validatePassword('123456'), isNull);
    vm.passwordController.text = 'secret';
    expect(vm.validateConfirmPassword(null), 'confirmPasswordRequired');
    expect(vm.validateConfirmPassword('different'), 'passwordsDoNotMatch');
    expect(vm.validateConfirmPassword('secret'), isNull);
  });

  test('changing form type clears passwords and keeps email only for reset/sign-in return', () {
    final vm = LoginViewModel(
      authService: FakeAuthService(null),
      profileService: ProfileService(),
      accountsService: FakeAccountsService(const []),
    );
    addTearDown(vm.dispose);
    vm.emailController.text = 'test@example.com';
    vm.passwordController.text = 'secret';
    vm.password2Controller.text = 'secret';

    vm.handleEvent(AuthEventParams(type: AuthEvent.changeFormType, formType: AuthForm.resetPassword));
    expect(vm.state.formType, AuthForm.resetPassword);
    expect(vm.emailController.text, 'test@example.com');
    expect(vm.passwordController.text, isEmpty);
    expect(vm.password2Controller.text, isEmpty);

    vm.handleEvent(AuthEventParams(type: AuthEvent.changeFormType, formType: AuthForm.signUp));
    expect(vm.emailController.text, isEmpty);
  });


  test('submit sign-up moves to email verification and stores the user', () async {
    final user = User(id: 'signup', email: 'new@example.com');
    final auth = FakeAuthService(null)..signUpUser = user;
    final vm = LoginViewModel(
      authService: auth,
      profileService: FakeProfileService(null),
      accountsService: FakeAccountsService(const []),
    );
    addTearDown(vm.dispose);
    vm.emailController.text = 'new@example.com';
    vm.passwordController.text = 'secret';
    await vm.handleEvent(AuthEventParams(type: AuthEvent.signUp));

    expect(vm.state.formType, AuthForm.verifyEmail);
    expect(vm.state.currentUser, user);
    expect(vm.state.isLoading, isFalse);
  });

  test('submit sign-in authenticates verified users', () async {
    final user = User(id: 'signin', emailVerified: true);
    final auth = FakeAuthService(null)..signInUser = user;
    final profile = FakeProfileService(null);
    User? authenticated;
    final vm = LoginViewModel(
      authService: auth,
      profileService: profile,
      accountsService: FakeAccountsService(const []),
      onAuthenticated: (value) => authenticated = value,
    );
    addTearDown(vm.dispose);
    await vm.handleEvent(AuthEventParams(type: AuthEvent.signIn));

    expect(authenticated, user);
    expect(profile.loadCalls, 1);
  });

  test('submit sign-in sends unverified users to email verification', () async {
    final user = User(id: 'signin-unverified', emailVerified: false);
    final auth = FakeAuthService(null)..signInUser = user;
    final vm = LoginViewModel(
      authService: auth,
      profileService: FakeProfileService(null),
      accountsService: FakeAccountsService(const []),
    );
    addTearDown(vm.dispose);
    await vm.handleEvent(AuthEventParams(type: AuthEvent.signIn));

    expect(vm.state.formType, AuthForm.verifyEmail);
    expect(vm.state.currentUser, user);
  });

  test('reset password returns to sign-in and keeps the email', () async {
    final auth = FakeAuthService(null);
    final vm = LoginViewModel(
      authService: auth,
      profileService: FakeProfileService(null),
      accountsService: FakeAccountsService(const []),
    );
    addTearDown(vm.dispose);
    vm.emailController.text = 'reset@example.com';
    vm.handleEvent(AuthEventParams(
      type: AuthEvent.changeFormType,
      formType: AuthForm.resetPassword,
    ));
    await vm.handleEvent(AuthEventParams(type: AuthEvent.resetPassword));

    expect(auth.resetCalls, 1);
    expect(vm.state.formType, AuthForm.signIn);
    expect(vm.emailController.text, 'reset@example.com');
  });

  test('authentication errors are exposed in state', () async {
    final auth = FakeAuthService(null)
      ..signInError = const AuthenticationException(
        code: 'bad-login',
        message: 'Bad credentials',
      );
    final vm = LoginViewModel(
      authService: auth,
      profileService: FakeProfileService(null),
      accountsService: FakeAccountsService(const []),
    );
    addTearDown(vm.dispose);
    await vm.handleEvent(AuthEventParams(type: AuthEvent.signIn));

    expect(vm.state.errorCode, 'bad-login');
    expect(vm.state.errorMessage, 'Bad credentials');
    expect(vm.state.isLoading, isFalse);
  });

  test('reload authenticates a newly verified user', () async {
    final user = User(id: 'reload', emailVerified: true);
    final auth = FakeAuthService(null)..reloadUser = user;
    final profile = FakeProfileService(null);
    User? authenticated;
    final vm = LoginViewModel(
      authService: auth,
      profileService: profile,
      accountsService: FakeAccountsService(const []),
      onAuthenticated: (value) => authenticated = value,
    );
    addTearDown(vm.dispose);
    await vm.handleEvent(AuthEventParams(type: AuthEvent.reloadUser));

    expect(authenticated, user);
    expect(profile.loadCalls, 1);
  });

  test('google sign-in authenticates and loads the profile', () async {
    final user = User(id: 'google', emailVerified: true);
    final auth = FakeAuthService(null)..googleUser = user;
    final profile = FakeProfileService(null);
    User? authenticated;
    final vm = LoginViewModel(
      authService: auth,
      profileService: profile,
      accountsService: FakeAccountsService(const []),
      onAuthenticated: (value) => authenticated = value,
    );
    addTearDown(vm.dispose);
    await vm.handleEvent(AuthEventParams(type: AuthEvent.googleSignIn));

    expect(authenticated, user);
    expect(profile.loadCalls, 1);
    expect(vm.state.isGoogleSignIn, isTrue);
  });

  test('google authentication errors return to the sign-in state', () async {
    final auth = FakeAuthService(null)
      ..googleError = const AuthenticationException(
        code: 'google-canceled',
        message: 'Canceled',
      );
    final vm = LoginViewModel(
      authService: auth,
      profileService: FakeProfileService(null),
      accountsService: FakeAccountsService(const []),
    );
    addTearDown(vm.dispose);
    await vm.handleEvent(AuthEventParams(type: AuthEvent.googleSignIn));

    expect(vm.state.formType, AuthForm.signIn);
    expect(vm.state.errorCode, 'google-canceled');
    expect(vm.state.isGoogleSignIn, isFalse);
  });

  test('reload keeps an unverified user on the verification state', () async {
    final user = User(id: 'reload-unverified', emailVerified: false);
    final auth = FakeAuthService(null)..reloadUser = user;
    final vm = LoginViewModel(
      authService: auth,
      profileService: FakeProfileService(null),
      accountsService: FakeAccountsService(const []),
    );
    addTearDown(vm.dispose);
    await vm.handleEvent(AuthEventParams(type: AuthEvent.reloadUser));

    expect(vm.state.currentUser, user);
    expect(vm.state.isLoading, isFalse);
  });

  test('sign-out clears the form and restores the initial form type', () async {
    final profile = FakeProfileService(User(id: 'u1'));
    final vm = LoginViewModel(
      authService: FakeAuthService(profile.currentUser),
      profileService: profile,
      accountsService: FakeAccountsService(const []),
    );
    addTearDown(vm.dispose);
    vm.emailController.text = 'user@example.com';
    vm.passwordController.text = 'secret';
    vm.password2Controller.text = 'secret';

    await vm.handleEvent(AuthEventParams(type: AuthEvent.signOut));

    expect(profile.signOutCalls, 1);
    expect(vm.state.currentUser, isNull);
    expect(vm.emailController.text, isEmpty);
    expect(vm.passwordController.text, isEmpty);
    expect(vm.state.formType, AuthForm.signUp);
  });

  test('resend verification delegates to auth service', () async {
    final auth = FakeAuthService(null);
    final vm = LoginViewModel(
      authService: auth,
      profileService: FakeProfileService(null),
      accountsService: FakeAccountsService(const []),
    );
    addTearDown(vm.dispose);
    await vm.handleEvent(AuthEventParams(type: AuthEvent.resendEmailVerification));

    expect(auth.resendCalls, 1);
    expect(vm.state.isLoading, isFalse);
  });

}
