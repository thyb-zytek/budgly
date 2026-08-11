import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/services/accounts.dart';
import 'package:flutter/material.dart';

class AccountsStore extends ChangeNotifier {
  static AccountsStore? _instance;

  static AccountsStore get instance {
    _instance ??= AccountsStore._();
    return _instance!;
  }

  final AccountsService _accountsService = AccountsService.instance;

  List<Account> _accounts = [];
  bool _isLoading = false;
  bool _hasLoaded = false;

  List<Account> get accounts => List.unmodifiable(_accounts);
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;

  AccountsStore._();

  Future<void> loadAccounts({bool forceRefresh = false}) async {
    if (_hasLoaded && !forceRefresh) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      _accounts = await _accountsService.listAccountsWithSignedUrls();
      _accounts.sort((a, b) => a.name.compareTo(b.name));
      _hasLoaded = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Busts the service-level cache AND forces a fresh fetch right away,
  /// so the store is never left empty with no data on the way.
  ///
  /// Only call this when the server-side data may differ from what we
  /// already know locally (e.g. a signed URL expired). If you just
  /// performed a local mutation, use addAccount/updateAccount/
  /// removeAccount instead - they already keep the store correct, and
  /// calling invalidateCache() afterwards would only throw that away.
  Future<void> invalidateCache() async {
    _accountsService.invalidateCache();
    await loadAccounts(forceRefresh: true);
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