import 'package:budgly/src/core/routers/navigation_helper.dart';
import 'package:budgly/src/services/accounts.dart';
import 'package:budgly/src/services/categories.dart';
import 'package:budgly/src/services/profile.dart';
import 'package:budgly/src/core/view_models/base_view_model.dart';
import 'package:budgly/src/models/user/user.dart';
import 'package:flutter/material.dart';

class ProfileViewModel extends BaseViewModel {
  final ProfileService _profileService = ProfileService.instance;
  
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  ProfileViewModel() {
    _profileService.addListener(_onServiceChanged);
  }

  void _onServiceChanged() {
    if (!isDisposed) notifyListeners();
  }

  User? get currentUser => _profileService.currentUser;

  @override
  bool get isLoading => super.isLoading || _profileService.isLoading;
  GlobalKey<FormState> get formKey => _formKey;
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

  Future<void> changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    
    setLoading(true);
    try {
      await _profileService.changePassword(
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
      await _profileService.loadUserProfile(forceRefresh: true);
    } finally {
      setLoading(false);
    }
  }

  Future<void> refreshUser() async {
    setLoading(true);
    try {
      final accountsService = AccountsService.instance;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        accountsService.invalidateCache();
        CategoriesService.instance.invalidateCache();
        final firstAccount = accountsService.accounts.isNotEmpty
            ? accountsService.accounts.first.id
            : null;
        if (firstAccount != null) {
          CategoriesService.instance.listCategoriesByAccount(firstAccount);
        }
      });

      await _profileService.loadUserProfile(forceRefresh: true);
    } finally {
      setLoading(false);
    }
  }

  Future<void> onChangeName(String name) async {
    await _profileService.updateUserName(name);
  }

  Future<void> signOut() async {
    setLoading(true);

    await _profileService.signOut();
    AccountsService.instance.clearLocalAccounts();
    CategoriesService.instance.invalidateCache();
    
    _oldPasswordController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();

    await NavigationHelper.router.pushReplacement(NavigationHelper.loginPath);
    setLoading(false);
  }
}