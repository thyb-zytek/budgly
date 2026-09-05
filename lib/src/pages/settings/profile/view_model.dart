import 'package:budgly/src/core/auth/auth_exception.dart';
import 'package:budgly/src/core/errors/app_user_message.dart';
import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/categories/categories_service.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:budgly/src/core/view_models/base_view_model.dart';
import 'package:budgly/src/models/user/user.dart';
import 'package:flutter/material.dart';

class ProfileViewModel extends BaseViewModel {
  final ProfileService _profileService;
  final AccountsService _accountsService;
  final CategoriesService _categoriesService;

  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  ProfileViewModel({
    ProfileService? profileService,
    AccountsService? accountsService,
    CategoriesService? categoriesService,
  })  : _profileService = profileService ?? ProfileService.instance,
        _accountsService = accountsService ?? AccountsService.instance,
        _categoriesService = categoriesService ?? CategoriesService.instance {
    _profileService.addListener(_onServiceChanged);
  }

  void _onServiceChanged() {
    if (!isDisposed) notifyListeners();
  }

  User? get currentUser => _profileService.currentUser;

  TextEditingController get oldPasswordController => _oldPasswordController;
  TextEditingController get passwordController => _passwordController;
  TextEditingController get confirmPasswordController => _confirmPasswordController;

  @override
  void dispose() {
    _profileService.removeListener(_onServiceChanged);
    _oldPasswordController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'passwordRequired';
    if (_passwordController.text.isNotEmpty && value != _passwordController.text) {
      return 'passwordsDoNotMatch';
    }
    if (value.length < 6) return 'passwordTooShort';
    return null;
  }

  Future<void> changePassword(bool isValid) async {
    if (!isValid) return;

    setLoading(true);
    try {
      await _profileService.changePassword(
        _oldPasswordController.value.text,
        _passwordController.value.text,
      );
      setSuccessMessage(const AppUserMessage.success(AppMessageKey.passwordChanged));
    } catch (e, stackTrace) {
      final userMessage = e is AuthenticationException && e.code == 'password-change-failed'
          ? const AppUserMessage.error(AppMessageKey.passwordChangeFailed)
          : null; // let setError classify anything else generically
      setError(e, stackTrace: stackTrace, userMessage: userMessage);
    } finally {
      _oldPasswordController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
      setLoading(false);
    }
  }

  Future<void> loadUser() async {
    setLoading(true);
    try {
      await _profileService.loadUserProfile(forceRefresh: true);
    } catch (e, stackTrace) {
      setError(e, stackTrace: stackTrace);
    } finally {
      setLoading(false);
    }
  }

  Future<void> refreshUser() async {
    setLoading(true);
    try {
      // Replay every pending local mutation. Offline-first: we only replace
      // the local data with fresh server data once we are sure all pending
      // mutations reached the server (i.e. we are online). Otherwise we bail
      // out and keep the existing local data intact.
      final online = await ProfileService.flushPendingMutations();
      if (!online) {
        throw StateError('offline: pending mutations could not be flushed');
      }

      // Online: safe to overwrite local caches/stores with server data.
      await Future.wait([
        _accountsService.loadAccounts(forceRefresh: true),
        _profileService.refreshFromServer(),
      ]);

      final firstAccount = _accountsService.accounts.isNotEmpty
          ? _accountsService.accounts.first.id
          : null;
      if (firstAccount != null) {
        await _categoriesService.listCategoriesByAccount(
          firstAccount,
          forceRefresh: true,
        );
      }

      AnalyticsService.instance.track('profile_refresh', const {'status': 'success'});
      setSuccessMessage(const AppUserMessage.success(AppMessageKey.profileRefreshed));
    } catch (e, stackTrace) {
      AnalyticsService.instance.track('profile_refresh', const {'status': 'failed'});
      setError(
        e,
        stackTrace: stackTrace,
        userMessage: const AppUserMessage.error(AppMessageKey.refreshProfileFailed),
      );
    } finally {
      setLoading(false);
    }
  }

  Future<void> onChangeName(String name) async {
    try {
      await _profileService.updateUserName(name);
      setSuccessMessage(const AppUserMessage.success(AppMessageKey.nameChanged));
    } catch (e, stackTrace) {
      setError(e, stackTrace: stackTrace);
    }
  }

  Future<void> signOut() async {
    setLoading(true);
    try {
      await _profileService.signOut();
      _oldPasswordController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
    } finally {
      setLoading(false);
    }
  }
}
