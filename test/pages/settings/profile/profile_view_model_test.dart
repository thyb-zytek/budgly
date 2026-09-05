import 'package:budgly/src/core/view_models/base_view_model.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/user/user.dart';
import 'package:budgly/src/pages/settings/profile/view_model.dart';
import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/categories/categories_service.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:budgly/src/stores/accounts.dart';
import 'package:budgly/src/stores/categories.dart';
import 'package:budgly/src/stores/profile.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeProfileServiceForProfile extends ProfileService {
  int changePasswordCalls = 0;
  int loadUserCalls = 0;
  int updateNameCalls = 0;
  int signOutCalls = 0;
  int refreshFromServerCalls = 0;
  Object? changePasswordError;
  Object? loadUserError;
  Object? updateNameError;
  Object? refreshFromServerError;
  User? user;
  String? lastUpdatedName;

  FakeProfileServiceForProfile() : super(store: ProfileStore.instance);

  @override
  User? get currentUser => user ?? ProfileStore.instance.currentUser;

  @override
  Future<void> changePassword(String oldPassword, String newPassword) async {
    changePasswordCalls++;
    if (changePasswordError != null) throw changePasswordError!;
  }

  @override
  Future<void> loadUserProfile({bool forceRefresh = false}) async {
    loadUserCalls++;
    if (loadUserError != null) throw loadUserError!;
  }

  @override
  Future<void> refreshFromServer() async {
    refreshFromServerCalls++;
    if (refreshFromServerError != null) throw refreshFromServerError!;
  }

  @override
  Future<void> updateUserName(String name) async {
    updateNameCalls++;
    lastUpdatedName = name;
    if (updateNameError != null) throw updateNameError!;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }
}

class FakeAccountsServiceForProfile extends AccountsService {
  FakeAccountsServiceForProfile() : super(store: AccountsStore.instance);

  @override
  List<Account> get accounts => seeded;
  List<Account> seeded = [];

  @override
  Future<void> loadAccounts({bool forceRefresh = false}) async {}
}

class FakeCategoriesServiceForProfile extends CategoriesService {
  FakeCategoriesServiceForProfile() : super(store: CategoriesStore.instance);

  @override
  Future<List<Category>> listCategoriesByAccount(String accountId,
      {bool forceRefresh = false}) async {
    return const [];
  }
}

void main() {
  late FakeProfileServiceForProfile fake;

  setUp(() {
    fake = FakeProfileServiceForProfile();
  });

  tearDown(() {
    ProfileStore.instance.clear();
  });

  test('validatePassword rejects empty value', () {
    final vm = ProfileViewModel(profileService: fake);
    addTearDown(vm.dispose);

    expect(vm.validatePassword(null), 'passwordRequired');
    expect(vm.validatePassword(''), 'passwordRequired');
  });

  test('validatePassword rejects mismatched confirm password', () {
    final vm = ProfileViewModel(profileService: fake);
    addTearDown(vm.dispose);

    vm.passwordController.text = 'secret1';
    expect(vm.validatePassword('secret2'), 'passwordsDoNotMatch');
  });

  test('validatePassword rejects values shorter than 6 characters', () {
    final vm = ProfileViewModel(profileService: fake);
    addTearDown(vm.dispose);

    expect(vm.validatePassword('abc'), 'passwordTooShort');
  });

  test('validatePassword returns null for a valid password', () {
    final vm = ProfileViewModel(profileService: fake);
    addTearDown(vm.dispose);

    expect(vm.validatePassword('secret1'), isNull);
  });

  test('changePassword is skipped when invalid', () async {
    final vm = ProfileViewModel(profileService: fake);
    addTearDown(vm.dispose);

    await vm.changePassword(false);

    expect(fake.changePasswordCalls, 0);
  });

  test('changePassword uses the old and new password controllers', () async {
    final vm = ProfileViewModel(profileService: fake);
    addTearDown(vm.dispose);
    vm.oldPasswordController.text = 'old-pass';
    vm.passwordController.text = 'new-pass';
    vm.confirmPasswordController.text = 'new-pass';

    await vm.changePassword(true);

    expect(fake.changePasswordCalls, 1);
    expect(vm.viewState, ViewState.success);
    expect(vm.pendingUserMessage, isNotNull);
    expect(vm.oldPasswordController.text, isEmpty);
    expect(vm.passwordController.text, isEmpty);
    expect(vm.confirmPasswordController.text, isEmpty);
  });

  test('changePassword clears the controllers even after an error', () async {
    final vm = ProfileViewModel(profileService: fake);
    fake.changePasswordError = Exception('boom');
    addTearDown(vm.dispose);
    vm.oldPasswordController.text = 'old';
    vm.passwordController.text = 'new';
    vm.confirmPasswordController.text = 'new';

    await vm.changePassword(true);

    expect(vm.hasError, isTrue);
    expect(vm.oldPasswordController.text, isEmpty);
    expect(vm.viewState, ViewState.error);
  });

  test('loadUser loads and refreshes the profile', () async {
    final vm = ProfileViewModel(profileService: fake);
    addTearDown(vm.dispose);

    await vm.loadUser();

    expect(fake.loadUserCalls, 1);
    expect(vm.viewState, ViewState.success);
  });

  test('loadUser reports an error when loading fails', () async {
    final vm = ProfileViewModel(profileService: fake);
    fake.loadUserError = Exception('offline');
    addTearDown(vm.dispose);

    await vm.loadUser();

    expect(vm.hasError, isTrue);
    expect(vm.viewState, ViewState.error);
  });

  test('onChangeName updates the user name and shows a message', () async {
    final vm = ProfileViewModel(profileService: fake);
    addTearDown(vm.dispose);

    await vm.onChangeName('New Name');

    expect(fake.updateNameCalls, 1);
    expect(fake.lastUpdatedName, 'New Name');
    expect(vm.pendingUserMessage, isNotNull);
  });

  test('onChangeName reports an error when the update fails', () async {
    final vm = ProfileViewModel(profileService: fake);
    fake.updateNameError = Exception('boom');
    addTearDown(vm.dispose);

    await vm.onChangeName('New Name');

    expect(vm.hasError, isTrue);
  });

  test('signOut signs out and clears the password controllers', () async {
    final vm = ProfileViewModel(profileService: fake);
    addTearDown(vm.dispose);
    vm.oldPasswordController.text = 'old';
    vm.passwordController.text = 'new';

    await vm.signOut();

    expect(fake.signOutCalls, 1);
    expect(vm.oldPasswordController.text, isEmpty);
    expect(vm.viewState, ViewState.success);
  });

  test('profile listeners are notified when the service changes', () {
    final vm = ProfileViewModel(profileService: fake);
    var notified = false;
    vm.addListener(() => notified = true);
    addTearDown(vm.dispose);

    ProfileStore.instance.setPreferences(currency: 'GBP');

    expect(notified, isTrue);
  });

  test('currentUser delegates to the profile service', () {
    final vm = ProfileViewModel(profileService: fake);
    addTearDown(vm.dispose);
    fake.user = User(id: 'u1', email: 'a@b.c');

    expect(vm.currentUser?.id, 'u1');
    expect(vm.currentUser?.isAuthenticated, isTrue);
  });

  test('refreshUser refreshes accounts, profile and categories when online',
      () async {
    AccountsStore.instance.setAccounts([
      const Account(id: 'a1', name: 'Main'),
    ]);
    final accounts = FakeAccountsServiceForProfile();
    final categories = FakeCategoriesServiceForProfile();
    final vm = ProfileViewModel(
      profileService: fake,
      accountsService: accounts,
      categoriesService: categories,
    );
    addTearDown(vm.dispose);

    await vm.refreshUser();

    expect(fake.refreshFromServerCalls, 1);
    expect(vm.viewState, ViewState.success);
    expect(vm.pendingUserMessage, isNotNull);
  });

  test('refreshUser reports an error when remote refresh fails', () async {
    final accounts = FakeAccountsServiceForProfile();
    final categories = FakeCategoriesServiceForProfile();
    fake.refreshFromServerError = Exception('offline');
    final vm = ProfileViewModel(
      profileService: fake,
      accountsService: accounts,
      categoriesService: categories,
    );
    addTearDown(vm.dispose);

    await vm.refreshUser();

    expect(vm.hasError, isTrue);
    expect(vm.viewState, ViewState.error);
  });
}
