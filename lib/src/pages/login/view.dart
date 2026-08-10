import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/routers/base.dart';
import 'package:budgly/src/core/stores/accounts_store.dart';
import 'package:budgly/src/core/auth/auth_event.dart';
import 'package:budgly/src/core/auth/auth_state.dart';
import 'package:budgly/src/pages/login/view_model.dart';
import 'package:budgly/src/pages/login/widgets/google_sign_in_button.dart';
import 'package:budgly/src/pages/login/widgets/login_appbar.dart';
import 'package:budgly/src/pages/login/widgets/login_form.dart';
import 'package:budgly/src/pages/login/widgets/reset_password_form.dart';
import 'package:budgly/src/pages/login/widgets/signup_form.dart';
import 'package:budgly/src/pages/login/widgets/verify_email.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  late LoginViewModel _viewModel = LoginViewModel(
    onAuthenticated: (user) async {
      if (mounted) {
        final store = AccountsStore.instance;
        try {
          await store.loadAccounts();
          
          if (mounted) {
            if (store.accounts.isNotEmpty) {
              context.go(NavigationHelper.overviewPath, extra: user);
            } else {
              context.go(NavigationHelper.tutorialPath);
            }
          }
        } catch (e) {
          if (mounted) {
            context.go(NavigationHelper.tutorialPath);
          }
        }
      }
    },
  );

  @override
  void initState() {
    _viewModel.handleEvent(
      AuthEventParams(
        type: AuthEvent.changeFormType,
        formType: AuthForm.signUp,
      ),
    );
    super.initState();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _onEvent(AuthEventParams event) {
    _viewModel.handleEvent(event);
  }

  String? _translateErrorMessage() {
    final tr = AppLocalizations.of(context)!;

    switch (_viewModel.state.errorCode) {
      case 'invalid-credential':
        return tr.invalidCredentials;
      case 'email-already-in-use':
        return tr.emailAlreadyInUse;
      case 'user-not-found':
        return tr.userNotFound;
      case 'canceled':
        return null;
      default:
        return _viewModel.state.errorMessage ?? tr.commonError;
    }
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(
          MediaQuery.of(context).viewInsets.bottom > 0
              ? MediaQuery.of(context).size.height / 6.15
              : MediaQuery.of(context).size.height / 3,
        ),
        child: AppBar(toolbarHeight: 0, flexibleSpace: LoginAppbar()),
      ),
      extendBody: true,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(top: 24),
        child: AnimatedBuilder(
          animation: Listenable.merge([_viewModel]),
          builder: (context, child) {
            if (_viewModel.state.isLoading) {
              String loadingMessage;
              if (_viewModel.state.isGoogleSignIn) {
                loadingMessage = AppLocalizations.of(context)!.googleSigningIn;
              } else {
                switch (_viewModel.state.formType) {
                  case AuthForm.signIn:
                    loadingMessage = AppLocalizations.of(context)!.signingIn;
                    break;
                  case AuthForm.signUp:
                    loadingMessage = AppLocalizations.of(context)!.signingUp;
                    break;
                  case AuthForm.resetPassword:
                    loadingMessage = AppLocalizations.of(context)!.resettingPassword;
                    break;
                  case AuthForm.verifyEmail:
                    loadingMessage = AppLocalizations.of(context)!.verifyingEmail;
                    break;
                }
              }
              
              return Center(
                child: Column(
                  spacing: 16,
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      loadingMessage,
                      style: theme.textTheme.titleMedium,
                    ),
                    const CircularProgressIndicator(),
                  ],
                ),
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_viewModel.state.errorCode != null)
                  _translateErrorMessage() != null ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      _translateErrorMessage()!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ) : const SizedBox.shrink(),
                switch (_viewModel.state.formType) {
                  AuthForm.signUp => SignUpForm(
                    formKey: _viewModel.formKey,
                    emailController: _viewModel.emailController,
                    passwordController: _viewModel.passwordController,
                    password2Controller: _viewModel.password2Controller,
                    validateEmail: _viewModel.validateEmail,
                    validatePassword: _viewModel.validatePassword,
                    validateConfirmPassword: _viewModel.validateConfirmPassword,
                    onSignInPressed:
                        () => _onEvent(
                          AuthEventParams(
                            type: AuthEvent.changeFormType,
                            formType: AuthForm.signIn,
                          ),
                        ),
                    onSubmitForm:
                        () => _onEvent(AuthEventParams(type: AuthEvent.signUp)),
                  ),
                  AuthForm.signIn => LoginForm(
                    formKey: _viewModel.formKey,
                    emailController: _viewModel.emailController,
                    passwordController: _viewModel.passwordController,
                    validateEmail: _viewModel.validateEmail,
                    validatePassword: _viewModel.validatePassword,
                    onSignUpPressed:
                        () => _onEvent(
                          AuthEventParams(
                            type: AuthEvent.changeFormType,
                            formType: AuthForm.signUp,
                          ),
                        ),
                    onSubmitForm:
                        () => _onEvent(AuthEventParams(type: AuthEvent.signIn)),
                    onResetPassword:
                        () => _onEvent(
                          AuthEventParams(
                            type: AuthEvent.changeFormType,
                            formType: AuthForm.resetPassword,
                            keepEmail: true,
                          ),
                        ),
                  ),
                  AuthForm.resetPassword => ResetPasswordForm(
                    formKey: _viewModel.formKey,
                    emailController: _viewModel.emailController,
                    validateEmail: _viewModel.validateEmail,
                    onSubmitForm:
                        () => _onEvent(
                          AuthEventParams(type: AuthEvent.resetPassword),
                        ),
                    onSignInPressed:
                        () => _onEvent(
                          AuthEventParams(
                            type: AuthEvent.changeFormType,
                            formType: AuthForm.signIn,
                          ),
                        ),
                  ),
                  AuthForm.verifyEmail => VerifyEmail(
                    email:
                        _viewModel.state.currentUser?.email ??
                        _viewModel.emailController.text,
                    onResendPressed:
                        () => _onEvent(
                          AuthEventParams(
                            type: AuthEvent.resendEmailVerification,
                          ),
                        ),
                    onSignInPressed:
                        () =>
                            _onEvent(AuthEventParams(type: AuthEvent.signOut)),
                    onReload: () {
                      _onEvent(AuthEventParams(type: AuthEvent.reloadUser));
                    },
                  ),
                },
                ([
                      AuthForm.signUp,
                      AuthForm.signIn,
                      AuthForm.resetPassword,
                    ].contains(_viewModel.state.formType))
                    ? Padding(
                      padding: const EdgeInsets.all(16.0).add(
                        EdgeInsets.only(
                          bottom:
                              MediaQuery.of(context).viewInsets.bottom > 0
                                  ? MediaQuery.of(context).viewInsets.bottom + 8
                                  : 0,
                        ),
                      ),
                      child: GoogleSignInButton(
                        onPressed:
                            () => _onEvent(
                              AuthEventParams(type: AuthEvent.googleSignIn),
                            ),
                      ),
                    )
                    : const SizedBox.shrink(),
              ],
            );
          },
        ),
      ),
    );
  }
}
