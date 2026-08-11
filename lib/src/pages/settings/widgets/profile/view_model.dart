import 'package:budgly/src/core/routers/base.dart';
import 'package:budgly/src/core/stores/accounts.dart';
import 'package:budgly/src/core/stores/categories.dart';
import 'package:budgly/src/core/stores/profile.dart';
import 'package:budgly/src/core/view_models/base_view_model.dart';
import 'package:budgly/src/models/user/user.dart';
import 'package:budgly/src/services/auth.dart';
import 'package:flutter/material.dart';

class ProfileViewModel extends BaseViewModel {
  final ProfileStore _profileStore = ProfileStore.instance;
  final AccountsStore _accountsStore = AccountsStore.instance;
  final CategoriesStore _categoriesStore = CategoriesStore.instance;
  final AuthService _authService = AuthService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  User? get currentUser => _profileStore.currentUser;

  @override
  bool get isLoading => super.isLoading || _profileStore.isLoading;
  GlobalKey<FormState> get formKey => _formKey;
  TextEditingController get oldPasswordController => _oldPasswordController;
  TextEditingController get passwordController => _passwordController;
  TextEditingController get confirmPasswordController =>
      _confirmPasswordController;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'passwordRequired';
    if (_passwordController.text.isNotEmpty &&
        value != _passwordController.text) {
      return 'passwordsDoNotMatch';
    }
    if (value.length < 6) return 'passwordTooShort';

    return null;
  }

  Future<void> changePassword() async {
    setLoading(true);
    if (!_formKey.currentState!.validate()) {
      setLoading(false);
      return;
    }
    try {
      await _profileStore.changePassword(
        _oldPasswordController.value.text,
        _passwordController.value.text,
      );
    } catch (e) {
      rethrow;
    } finally {
      _oldPasswordController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
      setLoading(false);
    }
  }

  Future<void> loadUser() async {
    try {
      await _profileStore.loadUserProfile(forceRefresh: true);
      setLoading(false);
    } catch (e) {
      setLoading(false);
    }
  }

  Future<void> refreshUser() async {
    setLoading(true);
    try {
      await _accountsStore.invalidateCache();
      await _categoriesStore.invalidateCache();
      await _profileStore.refreshUserProfile();
      setLoading(false);
    } catch (e) {
      setLoading(false);
    }
  }

  Future<void> onChangeName(String name) async {
    await _profileStore.updateUserName(name);
  }

  Future<void> signOut() async {
    setLoading(true);

    await _authService.signOut();
    _profileStore.clearUser();
    _oldPasswordController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();

    await NavigationHelper.router.pushReplacement(
      NavigationHelper.loginPath,
    );
    setLoading(false);
  }
}
