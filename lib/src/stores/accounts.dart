import 'package:budgly/src/models/account/account.dart';
import 'package:flutter/material.dart';

class AccountsStore extends ChangeNotifier {
  static AccountsStore? _instance;

  static AccountsStore get instance {
    _instance ??= AccountsStore._();
    return _instance!;
  }

  List<Account> _accounts = [];
  bool _hasLoaded = false;

  List<Account> get accounts => List.unmodifiable(_accounts);
  bool get hasLoaded => _hasLoaded;

  AccountsStore._();

  void setAccounts(List<Account> accounts) {
    final next = List<Account>.from(accounts)
      ..sort((a, b) => a.name.compareTo(b.name));
    if (_hasLoaded && _sameAccounts(_accounts, next)) return;

    _accounts = next;
    _hasLoaded = true;
    notifyListeners();
  }

  bool _sameAccounts(List<Account> a, List<Account> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final left = a[i];
      final right = b[i];
      if (left.id != right.id ||
          left.userId != right.userId ||
          left.name != right.name ||
          left.picture != right.picture ||
          left.pictureUrl != right.pictureUrl ||
          left.color != right.color) {
        return false;
      }
    }
    return true;
  }



  Account? getAccountById(String id) {
    for (final account in _accounts) {
      if (account.id == id) return account;
    }
    return null;
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
    final before = _accounts.length;
    _accounts.removeWhere((account) => account.id == accountId);
    if (_accounts.length != before) notifyListeners();
  }

  void clearLocalAccounts() {
    if (_accounts.isEmpty && !_hasLoaded) return;
    _accounts.clear();
    _hasLoaded = false;
    notifyListeners();
  }
}
