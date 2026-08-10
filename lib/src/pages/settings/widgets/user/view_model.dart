import 'package:budgly/src/core/routers/base.dart';
import 'package:budgly/src/core/stores/user_profile_store.dart';
import 'package:budgly/src/core/view_models/base_view_model.dart';
import 'package:budgly/src/models/user/user.dart';
import 'package:budgly/src/services/auth.dart';
import 'package:flutter/material.dart';

class UserViewModel extends BaseViewModel {
  final UserProfileStore _userProfileStore = UserProfileStore.instance;
  final AuthService _authService = AuthService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  User? get currentUser => _userProfileStore.currentUser;

  @override
  bool get isLoading => super.isLoading || _userProfileStore.isLoading;
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
      await _userProfileStore.changePassword(
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
      await _userProfileStore.loadUserProfile(forceRefresh: true);
      setLoading(false);
    } catch (e) {
      setLoading(false);
    }
  }

  Future<void> refreshUser() async {
    setLoading(true);
    try {
      await _userProfileStore.refreshUserProfile();
      setLoading(false);
    } catch (e) {
      setLoading(false);
    }
  }

  Future<void> onChangeName(String name) async {
    await _userProfileStore.updateUserName(name);
  }

  Future<void> signOut() async {
    setLoading(true);

    await _authService.signOut();
    _userProfileStore.clearUser();
    _oldPasswordController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();

    await NavigationHelper.router.pushReplacement(
      NavigationHelper.loginPath,
    );
    setLoading(false);
  }
}
