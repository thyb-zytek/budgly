import 'package:app/src/core/exceptions/auth_exceptions.dart';
import 'package:app/src/models/user/user.dart';
import 'package:app/src/pages/login/models/auth_event.dart';
import 'package:app/src/pages/login/models/auth_state.dart';
import 'package:app/src/services/auth_service.dart';
import 'package:flutter/material.dart';

import 'models/auth_error.dart';

class LoginViewModel with ChangeNotifier {
  final AuthService _authService = AuthService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _password2Controller = TextEditingController();
  final VoidCallback? onAuthenticated;

  AuthState _state = AuthState();

  LoginViewModel({VoidCallback? onAuthenticated})
    : onAuthenticated = onAuthenticated {
    if (_authService.currentUser != null &&
        !_authService.currentUser!.emailVerified) {
      _setState(
        currentUser: _authService.currentUser,
        formType: AuthForm.verifyEmail,
        isLoading: false,
      );
    } else {
      _setState(formType: AuthForm.signUp, isLoading: false);
    }
  }

  AuthState get state => _state;

  GlobalKey<FormState> get formKey => _formKey;

  TextEditingController get emailController => _emailController;

  TextEditingController get passwordController => _passwordController;

  TextEditingController get password2Controller => _password2Controller;

  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _password2Controller.dispose();
    super.dispose();
  }

  void _setState({
    AuthForm? formType,
    String? errorCode,
    String? errorMessage,
    bool? isLoading,
    User? currentUser,
  }) {
    _state = _state.copyWith(
      formType: formType,
      errorCode: errorCode,
      errorMessage: errorMessage,
      isLoading: isLoading,
      currentUser: currentUser,
    );
    notifyListeners();
  }

  void handleEvent(AuthEventParams event) {
    _setState(
      isLoading:
          ![
            AuthEvent.resendEmailVerification,
            AuthEvent.reloadUser,
            AuthEvent.googleSignIn,
          ].any((e) => e == event.type),
      errorCode: null,
      errorMessage: null,
    );

    event.when(
      resendEmailVerification: () => _handleResendEmailVerification(),
      reload: () => _handleReload(),
      submitForm: () => _handleSubmitForm(),
      googleSignIn: () => _handleGoogleSignIn(),
      signOut: () => _handleSignOut(),
      changeFormType: (formType) => _handleChangeFormType(formType),
    );
  }

  void _handleReload() {
    _authService
        .reloadCurrentUser()
        .then((user) {
          if (user != null && user.emailVerified) {
            _setState(isLoading: true, currentUser: user);
            onAuthenticated?.call();
          }
          _setState(
            currentUser: user,
            errorCode: _state.errorCode,
            errorMessage: _state.errorMessage,
          );
        })
        .catchError((error) {
          final authError =
              error is AuthenticationException
                  ? AuthError(error.code, error.message)
                  : AuthError('reloadError', error.toString());
          _setState(
            errorCode: authError.code,
            errorMessage: authError.message,
            isLoading: false,
          );
        });
  }

  void _handleSubmitForm() {
    if (!_formKey.currentState!.validate()) {
      _setState(isLoading: false);
      return;
    }

    switch (_state.formType) {
      case AuthForm.signUp:
        _authService
            .signUpWithEmailAndPassword(
              _emailController.text,
              _passwordController.text,
            )
            .then(
              (user) => _setState(
                isLoading: false,
                currentUser: user,
                formType: AuthForm.verifyEmail,
              ),
            )
            .catchError((error) {
              _setState(
                isLoading: false,
                errorCode:
                    error is AuthenticationException
                        ? error.code
                        : 'unknownError',
                errorMessage:
                    error is AuthenticationException
                        ? error.message
                        : error.toString(),
              );
            });
        break;
      case AuthForm.resetPassword:
        _authService
            .resetPassword(_emailController.text)
            .then((_) => _setState(isLoading: false, formType: AuthForm.signIn))
            .catchError((error) {
              _setState(
                isLoading: false,
                errorCode:
                    error is AuthenticationException
                        ? error.code
                        : 'unknownError',
                errorMessage:
                    error is AuthenticationException
                        ? error.message
                        : error.toString(),
              );
            });

        break;
      case AuthForm.signIn:
        _authService
            .signInWithEmailAndPassword(
              _emailController.text,
              _passwordController.text,
            )
            .then((user) {
              if (user.emailVerified) {
                onAuthenticated?.call();
              } else {
                _setState(
                  isLoading: false,
                  currentUser: user,
                  formType: AuthForm.verifyEmail,
                );
              }
            })
            .catchError((error) {
              _setState(
                isLoading: false,
                errorCode:
                    error is AuthenticationException
                        ? error.code
                        : 'unknownError',
                errorMessage:
                    error is AuthenticationException
                        ? error.message
                        : error.toString(),
              );
            });

        break;
      case AuthForm.verifyEmail:
        _clearForm(keepEmail: true);
        _setState(formType: AuthForm.signIn);
        break;
    }
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      _authService.signInWithGoogle().then((user) {
        onAuthenticated?.call();
      });
    } on Exception catch (e) {
      final error = AuthError('googleSignInError', e.toString());
      _setState(
        errorCode: error.code,
        errorMessage: error.message,
        isLoading: false,
      );
    }
  }

  void _handleSignOut() {
    _authService
        .signOut()
        .then((_) {
          _clearForm();
          _setState(
            currentUser: null,
            formType:
                _state.formType == AuthForm.resetPassword
                    ? AuthForm.signIn
                    : AuthForm.signUp,
            isLoading: false,
          );
        })
        .catchError((e) {
          final error = AuthError('signOutError', e.toString());
          _setState(
            errorCode: error.code,
            errorMessage: error.message,
            isLoading: false,
          );
        });
  }

  void _clearForm({bool keepEmail = false}) {
    _formKey.currentState?.reset();
    if (!keepEmail) {
      _emailController.clear();
    }
    _passwordController.clear();
    _password2Controller.clear();
  }

  void _handleChangeFormType(AuthForm formType) {
    _clearForm(
      keepEmail:
          formType == AuthForm.resetPassword ||
          (formType == AuthForm.signIn &&
              _state.formType == AuthForm.resetPassword),
    );
    _setState(
      formType: formType,
      isLoading: false,
      errorCode: null,
      errorMessage: null,
    );
  }

  void _handleResendEmailVerification() {
    _authService.sendEmailVerification().catchError((error) {
      _setState(
        isLoading: false,
        errorCode:
            error is AuthenticationException ? error.code : 'unknownError',
        errorMessage:
            error is AuthenticationException ? error.message : error.toString(),
      );
    });
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
