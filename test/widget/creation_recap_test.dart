import 'package:budgly/src/pages/tutorial/view_model.dart';
import 'package:budgly/src/pages/tutorial/widgets/creation_recap.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/builders.dart';
import '../helpers/fake_stores.dart';
import '../helpers/pump_app.dart';
import '../pages/tutorial/tutorial_view_model_test.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    clearAllTestStores();
    Fixtures.resetSeq();
  });

  tearDown(clearAllTestStores);

  testWidgets('shows the account name and category count', (tester) async {
    final vm = TutorialViewModel(
      accountsService: FakeTutorialAccountsService(const []),
      categoriesService: FakeTutorialCategoriesService(
        icons: [Fixtures.categoryIcon()],
      ),
      budgetService: FakeTutorialBudgetService(),
      profileService: ProfileService(),
    );
    addTearDown(vm.dispose);
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });

    vm.accountNameController.text = 'Compte principal';

    await pumpApp(tester, CreationRecap(viewModel: vm));

    expect(find.text('Compte principal'), findsOneWidget);
  });
}
