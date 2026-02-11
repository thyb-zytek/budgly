import 'package:app/src/core/routers/base.dart';
import 'package:app/src/models/user/user.dart';
import 'package:app/src/services/auth.dart';
import 'package:app/src/services/supabase.dart';
import 'package:flutter/material.dart';

class UserViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final SupabaseService _supabaseService = SupabaseService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;

  User? get currentUser => _authService.currentUser;

  bool get isLoading => _isLoading;
  GlobalKey<FormState> get formKey => _formKey;
  TextEditingController get oldPasswordController => _oldPasswordController;
  TextEditingController get passwordController => _passwordController;
  TextEditingController get confirmPasswordController =>
      _confirmPasswordController;

  @override
  void dispose() {
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
    _isLoading = true;
    notifyListeners();
    if (!_formKey.currentState!.validate()) {
      _isLoading = false;
      notifyListeners();
    }
    try {
      await _authService.changePassword(
        _oldPasswordController.value.text,
        _passwordController.value.text,
      );
    } catch (e) {
      rethrow;
    } finally {
      _oldPasswordController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshUser() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.reloadCurrentUser();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> onChangeName(String name) async {
    _isLoading = true;
    notifyListeners();

    final changed = await _supabaseService.updateProfile(
      _authService.currentUser!.id,
      {"full_name": name},
    );
    if (changed) {
      await _authService.reloadCurrentUser();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    await _authService.signOut();
    _passwordController.clear();
    _confirmPasswordController.clear();

    final result = await NavigationHelper.router.pushReplacement(
      NavigationHelper.loginPath,
    );
    if (result != null) {
      _isLoading = false;
      notifyListeners();
    }
  }
}
