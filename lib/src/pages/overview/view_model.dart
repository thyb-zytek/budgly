import 'package:budgly/src/core/loading/progressive_loader.dart';
import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/core/stores/accounts_store.dart';
import 'package:budgly/src/core/stores/categories_store.dart';
import 'package:budgly/src/core/stores/user_profile_store.dart';
import 'package:budgly/src/core/view_models/base_view_model.dart';
import 'package:budgly/src/models/budget/account_period_status.dart';
import 'package:budgly/src/models/budget/category_period_status.dart';
import 'package:budgly/src/models/user/user.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/services/errors.dart';
import 'package:flutter/material.dart';

class OverviewViewModel extends BaseViewModel {
  final AccountsStore _accountsStore = AccountsStore.instance;
  final CategoriesStore _categoriesStore = CategoriesStore.instance;
  final UserProfileStore _userProfileStore = UserProfileStore.instance;

  final VoidCallback? onNoAccounts;

  DateTime _selectedPeriod = DateTime.now();
  Account? _selectedAccount;
  AccountPeriodStatus? _accountPeriodStatus;
  Map<String, CategoryPeriodStatus> _categoryPeriodStatuses = {};

  int limitMonthsBefore = 12;
  int limitMonthsAfter = 3;

  OverviewViewModel({this.onNoAccounts});

  User? get user => _userProfileStore.currentUser;
  List<Account> get accounts => _accountsStore.accounts;
  List<Category> get categories => _selectedAccount != null 
      ? _categoriesStore.getCategoriesForAccount(_selectedAccount!.id!)
      : [];
  Account? get firstAccount => _accountsStore.accounts.isNotEmpty ? _accountsStore.accounts.first : null;
  DateTime get selectedPeriod => _selectedPeriod;
  Account get selectedAccount => _selectedAccount!;
  AccountPeriodStatus? get accountPeriodStatus => _accountPeriodStatus;
  Map<String, CategoryPeriodStatus> get categoryPeriodStatuses =>
      _categoryPeriodStatuses;

  double get incomeAmount =>
      (_accountPeriodStatus?.incomeCents ?? 0) / 100.0;

  double get outcomesAmount =>
      (_accountPeriodStatus?.totalSpentCents ?? 0) / 100.0;

  double get availableAmount =>
      (_accountPeriodStatus?.availableCents ?? 0) / 100.0;

  CategoryPeriodStatus? statusForCategory(String categoryId) {
    return _categoryPeriodStatuses[categoryId];
  }

  Future<void> changePeriod(DateTime newPeriod) async {
    _selectedPeriod = newPeriod;
    await _loadPeriodStats();
    notifyListeners();
  }

  Future<void> changeAccount(Account newAccount) async {
    setLoading(true);
    _selectedAccount = newAccount;
    await _categoriesStore.loadCategoriesForAccount(newAccount.id!);
    await _loadPeriodStats();
    setLoading(false);
  }

  Future<void> loadUserAccounts() async {
    setLoading(true);
    try {
      await ProgressiveLoader.loadProgressively(
        essentialData: () async {
          // Load accounts from store (uses cache if available)
          await _accountsStore.loadAccounts();
          await _userProfileStore.loadUserProfile();
          
          if (_accountsStore.accounts.isNotEmpty) {
            _selectedAccount = _accountsStore.accounts.first;
          } else {
            onNoAccounts?.call();
          }
        },
        secondaryData: () async {
          if (_accountsStore.accounts.isNotEmpty) {
            await _categoriesStore.loadCategoriesForAccount(_accountsStore.accounts.first.id!);
            await _loadPeriodStats();
          }
        },
        onProgress: (progress) {
          // Progress tracking for potential UI indicators
        },
      );
      notifyListeners();
    } catch (e) {
      AppLogger.error('Error loading accounts: $e', e);
      _accountsStore.invalidateCache();
      _categoriesStore.invalidateCache();
      ErrorService.instance.reportError();
    } finally {
      setLoading(false);
    }
  }

  Future<void> _loadPeriodStats() async {
    final accountId = _selectedAccount?.id;
    if (accountId == null) {
      _accountPeriodStatus = null;
      _categoryPeriodStatuses = {};
      return;
    }

    // final periodKey = BudgetPeriod.fromDateTime(_selectedPeriod).key;

    // try {
    //   final results = await Future.wait([
    //     _budgetStatusService.getAccountStatus(
    //       accountId: accountId,
    //       periodKey: periodKey,
    //     ),
    //     _budgetStatusService.getCategoryStatuses(
    //       accountId: accountId,
    //       periodKey: periodKey,
    //     ),
    //   ]);

    //   _accountPeriodStatus = results[0] as AccountPeriodStatus;
    //   final categoryStats = results[1] as List<CategoryPeriodStatus>;
    //   _categoryPeriodStatuses = {
    //     for (final stat in categoryStats) stat.categoryId: stat,
    //   };
    // } catch (e) {
    //   AppLogger.error('Error loading period stats: $e', e);
    //   _accountPeriodStatus = AccountPeriodStatus.empty(
    //     accountId: accountId,
    //     periodKey: periodKey,
    //   );
    //   _categoryPeriodStatuses = {};
    // }
  }

  Future<void> refreshData() async {
    _accountsStore.invalidateCache();
    _categoriesStore.invalidateCache();
    _userProfileStore.invalidateCache();
    await loadUserAccounts();
  }
}
