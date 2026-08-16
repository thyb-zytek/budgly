import 'package:budgly/src/models/account/account.dart';
import 'package:flutter/material.dart';

class AccountsStore extends ChangeNotifier {
  static AccountsStore? _instance;

  static AccountsStore get instance {
    _instance ??= AccountsStore._();
    return _instance!;
  }

  List<Account> _accounts = [];
  bool _isLoading = false;
  bool _hasLoaded = false;

  List<Account> get accounts => List.unmodifiable(_accounts);
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;

  AccountsStore._();

  void setAccounts(List<Account> accounts) {
    _accounts = List.from(accounts);
    _accounts.sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setLoaded(bool loaded) {
    _hasLoaded = loaded;
    notifyListeners();
  }

  Account? getAccountById(String id) {
    try {
      return _accounts.firstWhere((account) => account.id == id);
    } catch (_) {
      return null;
    }
  }

  void addAccount(Account account) {
    _accounts.add(account);
    _accounts.sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
  }

  void updateAccount(Account account) {
    final index = _accounts.indexWhere((a) => a.id == account.id);
    if (index != -1) {
      _accounts[index] = account;
      _accounts.sort((a, b) => a.name.compareTo(b.name));
      notifyListeners();
    }
  }

  void removeAccount(String accountId) {
    _accounts.removeWhere((account) => account.id == accountId);
    notifyListeners();
  }

  void clearLocalAccounts() {
    _accounts.clear();
    _hasLoaded = false;
    notifyListeners();
  }
}