import 'package:app/l10n/app_localizations.dart';
import 'package:app/src/core/routers/base.dart';
import 'package:app/src/pages/login/models/auth_event.dart';
import 'package:app/src/pages/login/models/auth_state.dart';
import 'package:app/src/pages/login/view_model.dart';
import 'package:app/src/pages/login/widgets/google_sign_in_button.dart';
import 'package:app/src/pages/login/widgets/login_appbar.dart';
import 'package:app/src/pages/login/widgets/login_form.dart';
import 'package:app/src/pages/login/widgets/reset_password_form.dart';
import 'package:app/src/pages/login/widgets/signup_form.dart';
import 'package:app/src/pages/login/widgets/verify_email.dart';
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
    onAuthenticated: () {
      if (mounted) {
        context.go(NavigationHelper.overviewPath);
      }
    },
  );

  @override
  void initState() {
    if (_viewModel.state.currentUser != null &&
        !_viewModel.state.currentUser!.emailVerified) {
      _viewModel.handleEvent(
        AuthEventParams(
          type: AuthEvent.changeFormType,
          formType: AuthForm.verifyEmail,
        ),
      );
    } else {
      _viewModel.handleEvent(
        AuthEventParams(
          type: AuthEvent.changeFormType,
          formType: AuthForm.signUp,
        ),
      );
    }
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
    AppLocalizations tr = AppLocalizations.of(context)!;

    switch (_viewModel.state.errorCode) {
      case 'invalid-credential':
        return tr.invalidCredentials;
      case 'email-already-in-use':
        return tr.emailAlreadyInUse;
      case 'user-not-found':
        return tr.userNotFound;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(
          MediaQuery.of(context).viewInsets.bottom > 0
              ? kToolbarHeight
              : MediaQuery.of(context).size.height / 3,
        ),
        child: AppBar(toolbarHeight: 0, flexibleSpace: LoginAppbar()),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            AnimatedBuilder(
              animation: Listenable.merge([_viewModel]),
              builder: (context, child) {
                if (_viewModel.state.isLoading) {
                  return Column(
                    spacing: 16,
                    children: [
                      Text(AppLocalizations.of(context)!.connecting, style: theme.textTheme.titleMedium),
                      const CircularProgressIndicator(),
                    ],
                  );
                }
                return Column(
                  children: [
                    if (_viewModel.state.errorCode != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          _translateErrorMessage() ??
                              _viewModel.state.errorMessage ??
                              "An error occurred",
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    switch (_viewModel.state.formType) {
                      AuthForm.signUp => SignUpForm(
                        formKey: _viewModel.formKey,
                        emailController: _viewModel.emailController,
                        passwordController: _viewModel.passwordController,
                        password2Controller: _viewModel.password2Controller,
                        validateEmail: _viewModel.validateEmail,
                        validatePassword: _viewModel.validatePassword,
                        validateConfirmPassword:
                            _viewModel.validateConfirmPassword,
                        onSignInPressed:
                            () => _onEvent(
                              AuthEventParams(
                                type: AuthEvent.changeFormType,
                                formType: AuthForm.signIn,
                              ),
                            ),
                        onSubmitForm:
                            () => _onEvent(
                              AuthEventParams(type: AuthEvent.signUp),
                            ),
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
                        onSubmitForm: () => _onEvent(AuthEventParams(type: AuthEvent.signIn)),
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
                            () => _onEvent(
                              AuthEventParams(type: AuthEvent.signOut),
                            ),
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
                          padding: EdgeInsets.all(
                            24,
                          ).add(EdgeInsets.only(bottom: 16)),
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
          ],
        ),
      ),
    );
  }
}
