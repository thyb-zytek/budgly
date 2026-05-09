import 'package:app/src/models/user/user.dart';
import 'package:app/src/models/account/account.dart';
import 'package:app/src/models/category/category.dart';
import 'package:app/src/services/accounts.dart';
import 'package:app/src/services/categories.dart';
import 'package:app/src/services/category_icons.dart';
import 'package:app/src/services/supabase.dart';
import 'package:app/src/services/errors.dart';
import 'package:flutter/material.dart';

class OverviewViewModel extends ChangeNotifier {
  AccountsService _accountsService = AccountsService.instance;
  CategoriesService _categoriesService = CategoriesService.instance;
  CategoryIconsService _categoryIconsService = CategoryIconsService.instance;

  User? _user;
  List<Account> _accounts = [];
  List<Category> _categories = [];
  DateTime _selectedPeriod = DateTime.now();
  Account? _selectedAccount;

  int limitMonthsBefore = 12;
  int limitMonthsAfter = 3;
  bool _isLoading = true;

  User? get user => _user;
  bool get isLoading => _isLoading;
  List<Account> get accounts => _accounts;
  List<Category> get categories => _categories;
  Account? get firstAccount => _accounts.isNotEmpty ? _accounts.first : null;
  DateTime get selectedPeriod => _selectedPeriod;
  Account get selectedAccount => _selectedAccount!;

  void changePeriod(DateTime newPeriod) {
    _selectedPeriod = newPeriod;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  Future<void> changeAccount(Account newAccount) async {
    setLoading(true);
    _selectedAccount = newAccount;
    await loadCategoriesForAccount(newAccount.id!);
    setLoading(false);
  }

  Future<void> loadUserAccounts() async {
    setLoading(true);
    try {
      _accounts = await _accountsService.listAccountsWithSignedUrls();
      if (accounts.isNotEmpty) {
        _selectedAccount = accounts.first;
        _categories = await _categoriesService
            .listCategoriesByAccount(accounts.first.id!)
            .then(
              (cats) =>
                  cats.map((cat) {
                    return cat.copyWith(
                      icon: _categoryIconsService.getIconByCode(
                        cat.iconCode ?? '0xf624',
                      ),
                    );
                  }).toList(),
            );
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading accounts: $e');
      _accounts = [];
      _categories = [];
      ErrorService.instance.reportError();
    } finally {
      setLoading(false);
    }
  }

  Future<void> loadCategoriesForAccount(String accountId) async {
    try {
      final supabaseService = SupabaseService();
      _categories = await supabaseService.getCategoriesByAccount(accountId);
    } catch (e) {
      debugPrint('Error loading categories: $e');
      _categories = [];
    }
  }

  Future<void> refreshData() async {
    await loadUserAccounts();
  }
}
