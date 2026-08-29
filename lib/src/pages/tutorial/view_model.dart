import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/core/extensions/amount.dart';
import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/core/view_models/base_view_model.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/account/account_editing_data.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/category/category_editing_data.dart';
import 'package:budgly/src/models/category/category_icon.dart';
import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/auth/auth_service.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:budgly/src/services/categories/categories_service.dart';
import 'package:budgly/src/services/budget/account_budgets_service.dart';
import 'package:budgly/src/services/image/image_service.dart';
import 'package:budgly/src/services/image/account_image_helper.dart';
import 'package:budgly/src/shared/domain/view_models/account_form_view_model.dart';
import 'package:budgly/src/shared/domain/view_models/category_form_view_model.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TutorialViewModel extends BaseViewModel implements AccountFormViewModel, CategoryFormViewModel {
  final AuthService _authService;
  final AccountsService _accountsService;
  final CategoriesService _categoriesService;
  final AccountBudgetsService _budgetService;
  final ProfileService _profileService;

  int _currentStep = 0;
  bool _isInitializing = true;

  SharedPreferences? _prefs;

  String get _stepStorageKey =>
      AppConstants.tutorialStepKey(_authService.currentUser?.id ?? 'anonymous');

  late final TextEditingController accountNameController;
  late final TextEditingController categoryNameController;
  late final TextEditingController revenueController;

  Color _accountColor = Colors.primaries[0];
  String? _accountPicture;

  Color _categoryColor = Colors.primaries[4];
  CategoryIcon? _categoryIcon;
  bool _isAddingCategory = false;
  final List<Category> _createdCategories = [];

  Account? _createdAccount;
  bool _hasRevenue = false;

  late final CategoryEditingData _categoryEditingData = CategoryEditingData(
    nameController: categoryNameController,
    color: _categoryColor,
    icon: _categoryIcon ?? AppConstants.defaultCategoryIcon,
    availableIcons: _categoriesService.availableIcons,
  );

  int get currentStep => _currentStep;
  int get totalSteps => 4;
  bool get isInitializing => _isInitializing;
  bool get canGoBack => _currentStep > 0;

  Color get accountColor => _createdAccount?.color ?? _editingData.color;

  String? get accountPicture {
    final savedUrl = _createdAccount?.pictureUrl;
    if (savedUrl != null) return savedUrl;
    return _editingData.picture;
  }

  bool get isLocalPicture {
    final picture = accountPicture;
    return picture != null && !picture.startsWith('http');
  }

  Color get categoryColor => _categoryColor;
  CategoryIcon? get categoryIcon => _categoryIcon;
  List<CategoryIcon> get availableIcons => _categoriesService.availableIcons;
  bool get isAddingCategory => _isAddingCategory;
  List<Category> get createdCategories => List.unmodifiable(_createdCategories);
  bool get hasCategories => _createdCategories.isNotEmpty;

  Account? get createdAccount => _createdAccount;

  bool get hasRevenue => _hasRevenue;

  String get currencyCode => _profileService.currency;

  int get amountDecimalPlaces => _profileService.amountDecimalPlaces;

  String get accountInitial {
    final name = accountNameController.text;
    return name.isNotEmpty ? name[0].toUpperCase() : 'C';
  }

  TutorialViewModel({
    AuthService? authService,
    AccountsService? accountsService,
    CategoriesService? categoriesService,
    AccountBudgetsService? budgetService,
    ProfileService? profileService,
  })  : _authService = authService ?? AuthService.instance,
        _accountsService = accountsService ?? AccountsService.instance,
        _categoriesService = categoriesService ?? CategoriesService.instance,
        _budgetService = budgetService ?? AccountBudgetsService.instance,
        _profileService = profileService ?? ProfileService.instance {
    accountNameController = TextEditingController(text: '');
    categoryNameController = TextEditingController(text: '');
    revenueController = TextEditingController(text: '');
    AnalyticsService.instance.track('onboarding_started');
    AnalyticsService.instance.track('onboarding_step_started', {'step': 0});
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      var hasExistingAccount = false;

      // Preferences, accounts and the static icon catalogue are independent.
      // Keep startup work parallel and let the account-dependent work begin as
      // soon as the local account list is available.
      final accountsFuture = _accountsService.loadAccounts();
      final iconsFuture = _categoriesService.loadAvailableIcons();

      try {
        await accountsFuture;
        if (_accountsService.accounts.isNotEmpty) {
          hasExistingAccount = true;
          await _adoptExistingAccount(_accountsService.accounts.first);
        }
      } catch (e, stackTrace) {
        AppLogger.error(
          'Failed to adopt existing account in tutorial',
          e,
          stackTrace,
        );
      }

      await iconsFuture;
      if (_categoriesService.availableIcons.isNotEmpty) {
        _categoryIcon = _categoryIcon ?? _categoriesService.availableIcons.firstWhere(
          (i) => i.iconName == AppConstants.defaultCategoryIcon.iconName,
          orElse: () => AppConstants.defaultCategoryIcon,
        );
        _categoryEditingData.icon = _categoryIcon!;
      }
      _categoryEditingData.availableIcons = _categoriesService.availableIcons;

      if (hasExistingAccount) {
        final savedStep = _prefs?.getInt(_stepStorageKey);
        _currentStep = (savedStep ?? 1).clamp(1, totalSteps - 1).toInt();
      }
    } finally {
      _isInitializing = false;
      if (!isDisposed) notifyListeners();
    }
  }

  Future<void> _adoptExistingAccount(Account account) async {
    _createdAccount = account;
    accountNameController.text = account.name;

    if (account.id == null) return;
    try {
      final now = DateTime.now();
      await Future.wait([
        _loadExistingCategories(account.id!),
        _loadExistingRevenue(account.id!, now.year, now.month),
      ]);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to prefill tutorial from existing account', e, stackTrace);
    }
  }

  Future<void> _loadExistingCategories(String accountId) async {
    final categories = await _categoriesService.listCategoriesByAccount(accountId);
    _createdCategories
      ..clear()
      ..addAll(categories);
    if (_createdCategories.isNotEmpty) _cycleCategoryDefaults();
  }

  Future<void> _loadExistingRevenue(
    String accountId,
    int year,
    int month,
  ) async {
    await _budgetService.loadRevenue(accountId, year, month);
    _hasRevenue = _budgetService.getRevenue(accountId, year, month) > 0;
  }

  void nextStep() {
    if (_currentStep < totalSteps - 1) {
      final previousStep = _currentStep;
      _currentStep++;
      AnalyticsService.instance.track('onboarding_step_completed', {'step': previousStep});
      AnalyticsService.instance.track('onboarding_step_started', {'step': _currentStep});
      _persistStep();
      notifyListeners();
    }
  }

  void previousStep() {
    if (_currentStep > 0) {
      _currentStep--;
      AnalyticsService.instance.track('onboarding_step_started', {'step': _currentStep});
      _persistStep();
      notifyListeners();
    }
  }

  Future<void> _persistStep() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setInt(_stepStorageKey, _currentStep);
  }

  Future<void> completeTutorial() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final uid = _authService.currentUser?.id ?? 'anonymous';
      await _prefs!.remove(AppConstants.tutorialStepKey(uid));
      await _prefs!.setBool(AppConstants.tutorialCompletedKey(uid), true);
      await ProfileService.instance.completeOnboarding();
      AnalyticsService.instance.track('onboarding_completed');
    } catch (e, stackTrace) {
      // Getting the user stuck on the last onboarding screen would be worse
      // than a local persistence hiccup — log it, but always let them
      // proceed to the app. ProfileService.completeOnboarding() already
      // has its own offline-first retry for the remote side.
      AppLogger.error('Failed to finalize onboarding completion', e, stackTrace);
    }
  }

  void setAccountColor(Color color) {
    _accountColor = color;
    _editingData.color = color;
    notifyListeners();
  }

  void setAccountPicture(String? path) {
    _accountPicture = path;
    _editingData.picture = path;
    _editingData.isLocalPicture = path != null && !path.startsWith('http');
    notifyListeners();
  }

  @override
  Future<String?> pickImage(BuildContext context) async {
    final path = await ImageService.pickAndCropImage(context);
    if (path != null) {
      _accountPicture = path;
      _editingData.picture = path;
      _editingData.isLocalPicture = true;
    }
    return path;
  }

  void setCategoryColor(Color color) {
    _categoryColor = color;
    _categoryEditingData.color = color;
    notifyListeners();
  }

  void setCategoryIcon(CategoryIcon icon) {
    _categoryIcon = icon;
    _categoryEditingData.icon = icon;
    notifyListeners();
  }

  late final AccountEditingData _editingData = AccountEditingData(
    nameController: accountNameController,
    color: _accountColor,
    picture: _accountPicture,
  );

  bool get isAccountValid => accountNameController.text.trim().isNotEmpty;
  bool get isCategoryValid => categoryNameController.text.trim().isNotEmpty;

  @override
  AccountEditingData get editingData => _editingData;

  Future<ImageProcessResult?> _prepareImage() async {
    return AccountImageHelper.prepareImage(
      _editingData.picture,
      isLocal: _editingData.isLocalPicture,
    );
  }

  Future<Account> _uploadAndLinkImage(Account account, ImageProcessResult image) async {
    return AccountImageHelper.uploadAndLinkImage(_accountsService, account, image);
  }

  @override
  Future<void> createAccount(Account account) async {
    if (!isAccountValid) return;
    setLoading(true);
    try {
      final imageToUpload = await _prepareImage();

      Account newAccount = Account(
        name: accountNameController.text.trim(),
        color: _editingData.color,
        picture: imageToUpload?.fileName,
      );
      _createdAccount = await _accountsService.createAccount(newAccount);

      if (imageToUpload != null && _createdAccount != null) {
        _createdAccount = await _uploadAndLinkImage(_createdAccount!, imageToUpload);
        _accountsService.updateLocalAccount(_createdAccount!);
      }
      if (_createdAccount != null) {
        AnalyticsService.instance.track('tutorial_account_created');
        await _persistStep();
      }
    } finally {
      setLoading(false);
    }
  }

  @override
  Future<void> updateAccount(Account account) async {
    if (account.id == null) return;
    setLoading(true);
    try {
      String? currentFileName = account.picture;
      ImageProcessResult? imageToUpload;

      if (_editingData.picture != account.pictureUrl) {
        if (account.picture != null) {
          await _accountsService.deletePicture(account.picture!, account.id!);
          currentFileName = null;
        }

        imageToUpload = await _prepareImage();
        if (imageToUpload != null) currentFileName = imageToUpload.fileName;
      }

      Account updatedAccount = account.copyWith(
        name: accountNameController.text.trim(),
        color: _editingData.color,
        picture: currentFileName,
      );

      _createdAccount = await _accountsService.updateAccount(updatedAccount);

      if (imageToUpload != null && _createdAccount != null) {
        _createdAccount = await _uploadAndLinkImage(_createdAccount!, imageToUpload);
        _accountsService.updateLocalAccount(_createdAccount!);
      } else if (_editingData.picture != null &&
          !_editingData.isLocalPicture &&
          _createdAccount != null) {
        _createdAccount = _createdAccount!.copyWith(pictureUrl: account.pictureUrl);
        _accountsService.updateLocalAccount(_createdAccount!);
      }
    } finally {
      setLoading(false);
    }
  }

  @override
  Future<void> removeAccount(Account account) async {
    _createdAccount = null;
    notifyListeners();
  }

  @override
  void cancelEdit() {}

  Future<bool> addCategory() async {
    if (!isCategoryValid || _createdAccount?.id == null) return false;
    _isAddingCategory = true;
    notifyListeners();
    try {
      final category = Category(
        name: categoryNameController.text.trim(),
        color: _categoryColor,
        icon: _categoryIcon,
        accountId: _createdAccount!.id!,
      );
      final created = await _categoriesService.createCategory(category);
      _createdCategories.add(created);
      AnalyticsService.instance.track('tutorial_category_created');
      categoryNameController.clear();
      _cycleCategoryDefaults();
      return true;
    } catch (e, st) {
      AppLogger.error('Failed to create category in tutorial', e, st);
      return false;
    } finally {
      _isAddingCategory = false;
      notifyListeners();
    }
  }

  @override
  CategoryEditingData get categoryEditingData => _categoryEditingData;

  @override
  Future<void> createCategory(Category category) async {}

  @override
  Future<void> updateCategory(Category category) async {}

  @override
  Future<void> removeCategory(Category category) async {
    if (category.id == null) return;
    final index = _createdCategories.indexWhere((c) => c.id == category.id);
    if (index == -1) return;

    _createdCategories.removeAt(index);
    notifyListeners();

    try {
      await _categoriesService.deleteCategory(category.id!);
    } catch (e, st) {
      AppLogger.error('Failed to delete category in tutorial', e, st);
      _createdCategories.insert(index, category);
      notifyListeners();
    }
  }

  void _cycleCategoryDefaults() {
    final colorIndex = _createdCategories.length % Colors.primaries.length;
    _categoryColor = Colors.primaries[colorIndex];
    _categoryIcon = AppConstants.defaultCategoryIcon;
  }

  Future<void> saveRevenue() async {
    if (_createdAccount?.id == null) return;
    final value = parseAmount(revenueController.text);
    if (value == null || value <= 0) return;

    final now = DateTime.now();
    await _budgetService.setRevenue(_createdAccount!.id!, now.year, now.month, value);
    _hasRevenue = true;
    AnalyticsService.instance.track('tutorial_budget_created');
    notifyListeners();
  }

  Future<void> signOut() async {
    await _profileService.signOut();
  }

  @override
  void dispose() {
    accountNameController.dispose();
    categoryNameController.dispose();
    revenueController.dispose();
    super.dispose();
  }
}
