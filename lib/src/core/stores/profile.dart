import 'package:budgly/src/models/user/user.dart';
import 'package:budgly/src/services/auth.dart';
import 'package:flutter/material.dart';

class ProfileStore extends ChangeNotifier {
  static ProfileStore? _instance;
  
  static ProfileStore get instance {
    _instance ??= ProfileStore._();
    return _instance!;
  }

  final AuthService _authService = AuthService();
  
  User? _currentUser;
  bool _isLoading = false;
  bool _hasLoaded = false;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;

  ProfileStore._() {
    _currentUser = _authService.currentUser;
    // Auto-load user profile when store is created
    loadUserProfile();
  }

  Future<void> loadUserProfile({bool forceRefresh = false}) async {
    if (_hasLoaded && !forceRefresh && _currentUser != null) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      _currentUser = await _authService.reloadCurrentUser();
      _hasLoaded = true;
    } catch (e) {
      _currentUser ??= _authService.currentUser;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshUserProfile() async {
    _isLoading = true;
    notifyListeners();

    try {
      _currentUser = await _authService.reloadCurrentUser();
    } catch (e) {
      // Handle error silently or log it
      print('Error refreshing user profile: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateUserName(String name) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.onChangeName(name);
      _currentUser = await _authService.reloadCurrentUser();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> changePassword(String oldPassword, String newPassword) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.changePassword(oldPassword, newPassword);
      _currentUser = await _authService.reloadCurrentUser();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void invalidateCache() {
    _hasLoaded = false;
    _currentUser = _authService.currentUser;
    notifyListeners();
  }

  void clearUser() {
    _currentUser = null;
    _hasLoaded = false;
    notifyListeners();
  }
}