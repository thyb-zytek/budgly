import 'package:budgly/src/core/view_models/base_view_model.dart';
import 'package:budgly/src/services/auth.dart'; 
import 'package:budgly/src/services/accounts.dart';
import 'package:budgly/src/core/routers/navigation_helper.dart';

class TutorialViewModel extends BaseViewModel {
  final AuthService _authService = AuthService.instance;
  final AccountsService _accountsService = AccountsService.instance;

  bool _isChecking = true;
  bool get isChecking => _isChecking;

  TutorialViewModel() {
    _checkAccountsAndRedirect();
  }

  Future<void> _checkAccountsAndRedirect() async {
    await _authService.reloadCurrentUser();
    try {
      // Charge les comptes (avec URLs signées) et les met en cache dans AccountsService
      await _accountsService.loadAccounts();
      final accounts = _accountsService.accounts;

      if (accounts.isNotEmpty) {
        // L'utilisateur a des comptes, on redirige vers l’overview
        // Les comptes sont déjà en cache côté service
        NavigationHelper.router.go(NavigationHelper.overviewPath);
        return;
      }
    } catch (e) {
      // Si la vérification échoue, on reste sur le tutoriel
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