import 'package:budgly/src/core/auth/auth_event.dart';
import 'package:budgly/src/core/auth/auth_state.dart';
import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/core/auth/auth_exception.dart';
import 'package:budgly/src/core/view_models/base_view_model.dart';
import 'package:budgly/src/models/user/user.dart';
import 'package:budgly/src/services/auth.dart';
import 'package:budgly/src/services/profile.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginViewModel extends BaseViewModel {
  final AuthService _authService = AuthService.instance;
  final ProfileService _profileService = ProfileService.instance;
  
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _password2Controller = TextEditingController();
  final Function(User)? onAuthenticated;

  static const String _formTypeKey = AppConstants.loginFormTypeKey;
  AuthState _state = AuthState();

  LoginViewModel({this.onAuthenticated}) {
    _initialize();
  }

  AuthState get state => _state;
  GlobalKey<FormState> get formKey => _formKey;
  TextEditingController get emailController => _emailController;
  TextEditingController get passwordController => _passwordController;
  TextEditingController get password2Controller => _password2Controller;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _password2Controller.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    final currentUser = _authService.currentUser;

    if (currentUser != null && !currentUser.emailVerified) {
      if (isDisposed) return;
      _setState(
        currentUser: currentUser,
        formType: AuthForm.verifyEmail,
        isLoading: false,
        isGoogleSignIn: false,
      );
      return;
    }

    final savedFormType = await _loadFormType();
    if (isDisposed) return;
    _setState(formType: savedFormType, isLoading: false, isGoogleSignIn: false);
  }

  Future<AuthForm> _loadFormType() async {
    final prefs = await SharedPreferences.getInstance();
    final formTypeString = prefs.getString(_formTypeKey);
    return formTypeString != null
        ? AuthForm.values.firstWhere(
            (e) => e.toString() == formTypeString,
            orElse: () => AuthForm.signIn,
          )
        : AuthForm.signIn;
  }

  Future<void> _saveFormType(AuthForm formType) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_formTypeKey, formType.toString());
  }

  void _setState({
    AuthForm? formType,
    String? errorCode,
    String? errorMessage,
    bool? isLoading,
    User? currentUser,
    bool? isGoogleSignIn,
  }) {
    _state = _state.copyWith(
      formType: formType,
      errorCode: errorCode,
      errorMessage: errorMessage,
      isLoading: isLoading,
      currentUser: currentUser,
      isGoogleSignIn: isGoogleSignIn,
    );
    if (!isDisposed) notifyListeners();
  }

  void handleEvent(AuthEventParams event) {
    _setState(
      isLoading: ![
        AuthEvent.resendEmailVerification,
        AuthEvent.reloadUser,
      ].contains(event.type),
      errorCode: null,
      errorMessage: null,
      isGoogleSignIn: event.type == AuthEvent.googleSignIn,
    );

    event.when(
      resendEmailVerification: _handleResendEmailVerification,
      reload: _handleReload,
      submitForm: _handleSubmitForm,
      googleSignIn: _handleGoogleSignIn,
      signOut: _handleSignOut,
      changeFormType: _handleChangeFormType,
    );
  }

  Future<void> _handleReload() async {
    try {
      final user = await _authService.reloadCurrentUser();
      if (user != null && user.emailVerified) {
        await _profileService.loadUserProfile(forceRefresh: true);
        if (!isDisposed) {
          _setState(isLoading: true, currentUser: user, isGoogleSignIn: false);
        }
        onAuthenticated?.call(user);
      } else if (!isDisposed) {
        _setState(currentUser: user, isLoading: false, isGoogleSignIn: false);
      }
    } on AuthenticationException catch (e) {
      if (!isDisposed) {
        _setState(errorCode: e.code, errorMessage: e.message, isLoading: false, isGoogleSignIn: false);
      }
    } catch (e) {
      if (!isDisposed) {
        _setState(errorCode: 'reloadError', errorMessage: e.toString(), isLoading: false, isGoogleSignIn: false);
      }
    }
  }

  Future<void> _handleSubmitForm() async {
    if (!_formKey.currentState!.validate()) {
      _setState(isLoading: false, isGoogleSignIn: false);
      return;
    }

    try {
      switch (_state.formType) {
        case AuthForm.signUp:
          final user = await _authService.signUpWithEmailAndPassword(
            _emailController.text,
            _passwordController.text,
          );
          if (!isDisposed) {
            _setState(
              isLoading: false,
              currentUser: user,
              formType: AuthForm.verifyEmail,
              isGoogleSignIn: false,
            );
          }
          break;

        case AuthForm.signIn:
          final user = await _authService.signInWithEmailAndPassword(
            _emailController.text,
            _passwordController.text,
          );
          if (user.emailVerified) {
            await _profileService.loadUserProfile(forceRefresh: true);
            onAuthenticated?.call(user);
          } else if (!isDisposed) {
            _setState(
              isLoading: false,
              currentUser: user,
              formType: AuthForm.verifyEmail,
              isGoogleSignIn: false,
            );
          }
          break;

        case AuthForm.resetPassword:
          await _authService.resetPassword(_emailController.text);
          if (!isDisposed) {
            _setState(isLoading: false, formType: AuthForm.signIn, isGoogleSignIn: false);
          }
          break;

        case AuthForm.verifyEmail:
          _clearForm(keepEmail: true);
          await _saveFormType(AuthForm.signIn);
          _setState(formType: AuthForm.signIn, isGoogleSignIn: false);
          break;
      }
    } on AuthenticationException catch (e) {
      if (!isDisposed) {
        _setState(isLoading: false, errorCode: e.code, errorMessage: e.message, isGoogleSignIn: false);
      }
    } catch (e) {
      if (!isDisposed) {
        _setState(isLoading: false, errorCode: 'unknownError', errorMessage: e.toString(), isGoogleSignIn: false);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      final user = await _authService.signInWithGoogle();
      await _profileService.loadUserProfile(forceRefresh: true);
      onAuthenticated?.call(user);
    } on AuthenticationException catch (e) {
      if (!isDisposed) {
        _setState(
          isLoading: false,
          formType: AuthForm.signIn,
          errorCode: e.code,
          errorMessage: e.message,
          isGoogleSignIn: false,
        );
      }
    } catch (e) {
      if (!isDisposed) {
        _setState(
          isLoading: false,
          formType: AuthForm.signIn,
          errorCode: 'googleSignInError',
          errorMessage: e.toString(),
          isGoogleSignIn: false,
        );
      }
    }
  }

  Future<void> _handleSignOut() async {
    try {
      await _profileService.signOut();
      if (!isDisposed) {
        _clearForm();
        _setState(
          currentUser: null,
          formType: _state.formType == AuthForm.resetPassword ? AuthForm.signIn : AuthForm.signUp,
          isLoading: false,
          isGoogleSignIn: false,
        );
      }
    } catch (e) {
      if (!isDisposed) {
        _setState(errorCode: 'signOutError', errorMessage: e.toString(), isLoading: false, isGoogleSignIn: false);
      }
    }
  }

  void _handleChangeFormType(AuthForm formType) {
    _clearForm(
      keepEmail: formType == AuthForm.resetPassword ||
          (formType == AuthForm.signIn && _state.formType == AuthForm.resetPassword),
    );
    _setState(
      formType: formType,
      isLoading: false,
      errorCode: null,
      errorMessage: null,
      isGoogleSignIn: false,
    );
  }

  Future<void> _handleResendEmailVerification() async {
    try {
      await _authService.sendEmailVerification();
    } on AuthenticationException catch (e) {
      if (!isDisposed) {
        _setState(isLoading: false, errorCode: e.code, errorMessage: e.message, isGoogleSignIn: false);
      }
    } catch (e) {
      if (!isDisposed) {
        _setState(isLoading: false, errorCode: 'unknownError', errorMessage: e.toString(), isGoogleSignIn: false);
      }
    }
  }

  void _clearForm({bool keepEmail = false}) {
    _formKey.currentState?.reset();
    if (!keepEmail) _emailController.clear();
    _passwordController.clear();
    _password2Controller.clear();
  }

  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'emailRequired';
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) return 'emailInvalid';
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'passwordRequired';
    if (value.length < 6) return 'passwordTooShort';
    return null;
  }

  String? validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'confirmPasswordRequired';
    if (value != _passwordController.text) return 'passwordsDoNotMatch';
    return null;
  }
}
