import 'package:budgly/src/models/user/user.dart';
import 'package:budgly/src/pages/settings/profile/tab.dart';
import 'package:budgly/src/pages/settings/profile/view_model.dart';
import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/categories/categories_service.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

class _FakeProfileService extends ProfileService {
  User? user;

  @override
  User? get currentUser => user;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

class _NoopAccountsService extends AccountsService {}

class _NoopCategoriesService extends CategoriesService {}

void main() {
  testWidgets('renders the injected view model\'s user instead of creating its own', (
    tester,
  ) async {
    final profileService = _FakeProfileService()
      ..user = User(id: 'u1', email: 'test@example.com');
    final viewModel = ProfileViewModel(
      profileService: profileService,
      accountsService: _NoopAccountsService(),
      categoriesService: _NoopCategoriesService(),
    );

    await pumpApp(tester, ProfileTab(injectedViewModel: viewModel));

    expect(find.text('test@example.com'), findsWidgets);

    viewModel.dispose();
  });

  testWidgets('unmounting the tab does not dispose an injected view model', (
    tester,
  ) async {
    final profileService = _FakeProfileService()
      ..user = User(id: 'u1', email: 'test@example.com');
    final viewModel = ProfileViewModel(
      profileService: profileService,
      accountsService: _NoopAccountsService(),
      categoriesService: _NoopCategoriesService(),
    );

    await pumpApp(tester, ProfileTab(injectedViewModel: viewModel));
    await tester.pumpWidget(const SizedBox.shrink());

    expect(viewModel.isDisposed, isFalse);

    viewModel.dispose();
  });
}
