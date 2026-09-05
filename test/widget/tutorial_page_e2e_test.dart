import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/category/category_icon.dart';
import 'package:budgly/src/models/user/user_profile.dart';
import 'package:budgly/src/pages/tutorial/view.dart';
import 'package:budgly/src/pages/tutorial/view_model.dart';
import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/auth/auth_service.dart';
import 'package:budgly/src/services/budget/account_budgets_service.dart';
import 'package:budgly/src/services/categories/categories_service.dart';
import 'package:budgly/src/services/categories/category_icons_service.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:budgly/src/services/providers/supabase/accounts.dart';
import 'package:budgly/src/services/providers/supabase/categories.dart';
import 'package:budgly/src/services/providers/supabase/storage.dart';
import 'package:budgly/src/services/providers/supabase/user_profiles.dart';
import 'package:budgly/src/stores/accounts.dart';
import 'package:budgly/src/stores/categories.dart';
import 'package:budgly/src/stores/profile.dart';
import 'package:budgly/l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmptyAccountSupabase extends AccountSupabase {
  @override
  Future<List<Account>> listByUserId(String userId) async => <Account>[];
}

class NoopStorage extends StorageSupabase {}

class EmptyCategorySupabase extends CategorySupabase {
  @override
  Future<List<Category>> listByAccountId(String accountId) async =>
      <Category>[];
}

class EmptyCategoryIcons extends CategoryIconsService {
  @override
  Future<List<CategoryIcon>> getIcons() async => <CategoryIcon>[];
}

class NoopUserProfileSupabase extends UserProfileSupabase {
  @override
  Future<UserProfile?> getProfile(String userId) async => null;

  @override
  Future<UserProfile> getOrCreateProfile(fb.User firebaseUser) async =>
      UserProfile(id: '', email: '', fullName: '');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFirebaseAuth auth;
  late AuthService authService;
  late AccountsService accountsService;
  late CategoriesService categoriesService;
  late ProfileService profileService;
  late TutorialViewModel viewModel;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SyncManager.instance.resetForTest();
    await SyncQueue.instance.clear();
    AccountsStore.instance.clearLocalAccounts();
    CategoriesStore.instance.clearAll();
    ProfileStore.instance.clear();

    auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'u1', email: 'test@budgly.app'),
    );
    authService = AuthService(
      auth: auth,
      userProfileSupabase: NoopUserProfileSupabase(),
    );
    accountsService = AccountsService(
      auth: auth,
      accountSupabase: EmptyAccountSupabase(),
      storageSupabase: NoopStorage(),
    );
    categoriesService = CategoriesService(
      categorySupabase: EmptyCategorySupabase(),
      categoryIconsService: EmptyCategoryIcons(),
    );
    profileService = ProfileService(
      store: ProfileStore.instance,
      profileSupabase: NoopUserProfileSupabase(),
    );
    viewModel = TutorialViewModel(
      authService: authService,
      accountsService: accountsService,
      categoriesService: categoriesService,
      budgetService: AccountBudgetsService.instance,
      profileService: profileService,
    );
  });

  tearDown(() async {
    if (!viewModel.isDisposed) viewModel.dispose();
    await SyncManager.instance.resetForTest();
    await SyncQueue.instance.clear();
  });

  Future<void> pumpTutorial(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 740));
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('fr')],
        theme: ThemeData.light(useMaterial3: true),
        home: TutorialPage(injectedViewModel: viewModel),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    // Let the VM's real async init complete (SharedPreferences, etc.) via runAsync,
    // then pump the widget to reflect the new state.
    await tester.runAsync(() async {
      var attempts = 0;
      while (viewModel.isInitializing && attempts < 40) {
        await Future.delayed(const Duration(milliseconds: 50));
        attempts++;
      }
    });
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('welcomes the user then advances and steps back through the page',
      (tester) async {
    await pumpTutorial(tester);

    expect(viewModel.currentStep, 0);

    await tester.tap(find.text('Commencer'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
    expect(viewModel.currentStep, 1);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
    expect(viewModel.currentStep, 0);
  });

  testWidgets('system back on the first step opens the logout dialog',
      (tester) async {
    await pumpTutorial(tester);

    expect(viewModel.currentStep, 0);
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Annuler'), findsOneWidget);
  });
}
