import 'package:budgly/src/core/view_models/base_view_model.dart';
import 'package:budgly/src/services/auth.dart';
import 'package:budgly/src/services/accounts.dart';
import 'package:budgly/src/core/routers/base.dart';

class TutorialViewModel extends BaseViewModel {
  final AuthService _authService = AuthService();
  final AccountsService _accountsService = AccountsService.instance;

  bool _isChecking = true;
  bool get isChecking => _isChecking;

  TutorialViewModel() {
    _checkAccountsAndRedirect();
  }

  Future<void> _checkAccountsAndRedirect() async {
    await _authService.reloadCurrentUser();
    try {
        // Load accounts with signed URLs and cache them in AccountsService
        final accounts = await _accountsService.listAccountsWithSignedUrls();
        if (accounts.isNotEmpty) {
          // User has accounts, redirect to overview
          // Accounts are now cached with signed URLs and will be used by overview page
          NavigationHelper.router.go(NavigationHelper.overviewPath);
          return;
        }
      } catch (e) {
        // If checking accounts fails, stay on tutorial
      }
    
    _isChecking = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _accountsService.invalidateCache();
    notifyListeners();
  }

}
