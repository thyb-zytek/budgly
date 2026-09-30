import 'package:budgly/src/core/auth/auth_state.dart';
import 'package:budgly/src/pages/login/login_provider.dart';
import 'package:budgly/src/pages/login/widgets/google_sign_in_button.dart';
import 'package:budgly/src/pages/login/widgets/login_form.dart';
import 'package:budgly/src/pages/login/widgets/reset_password_form.dart';
import 'package:budgly/src/pages/login/widgets/signup_form.dart';
import 'package:budgly/src/pages/login/widgets/verify_email.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:flutter/material.dart';

class LoginFormSwitcher extends StatelessWidget {
  final AuthState state;
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController password2Controller;
  final void Function(AuthForm) onChangeFormType;
  final Future<void> Function() onSubmitSignIn;
  final Future<void> Function() onSubmitSignUp;
  final Future<void> Function() onResetPassword;
  final Future<void> Function() onGoogleSignIn;
  final Future<void> Function() onResendVerification;
  final Future<void> Function() onReload;
  final Future<void> Function() onSignOut;

  const LoginFormSwitcher({
    super.key,
    required this.state,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.password2Controller,
    required this.onChangeFormType,
    required this.onSubmitSignIn,
    required this.onSubmitSignUp,
    required this.onResetPassword,
    required this.onGoogleSignIn,
    required this.onResendVerification,
    required this.onReload,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final formType = state.formType;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        switch (formType) {
          AuthForm.signUp => SignUpForm(
            formKey: formKey,
            emailController: emailController,
            passwordController: passwordController,
            password2Controller: password2Controller,
            validateEmail: validateLoginEmail,
            validatePassword: validateLoginPassword,
            validateConfirmPassword: (value) =>
                validateLoginConfirmPassword(value, passwordController.text),
            onSignInPressed: () => onChangeFormType(AuthForm.signIn),
            onSubmitForm: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              await onSubmitSignUp();
            },
          ),
          AuthForm.signIn => LoginForm(
            formKey: formKey,
            emailController: emailController,
            passwordController: passwordController,
            validateEmail: validateLoginEmail,
            validatePassword: validateLoginPassword,
            onSignUpPressed: () => onChangeFormType(AuthForm.signUp),
            onSubmitForm: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              await onSubmitSignIn();
            },
            onResetPassword: () => onChangeFormType(AuthForm.resetPassword),
          ),
          AuthForm.resetPassword => ResetPasswordForm(
            formKey: formKey,
            emailController: emailController,
            validateEmail: validateLoginEmail,
            onSubmitForm: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              await onResetPassword();
            },
            onSignInPressed: () => onChangeFormType(AuthForm.signIn),
          ),
          AuthForm.verifyEmail => VerifyEmail(
            email: state.currentUser?.email ?? emailController.text,
            onResendPressed: onResendVerification,
            onSignInPressed: onSignOut,
            onReload: onReload,
          ),
        },
        if ([
          AuthForm.signUp,
          AuthForm.signIn,
          AuthForm.resetPassword,
        ].contains(formType))
          Padding(
            padding: EdgeInsets.all(
              BudglySpacing.xl,
            ).add(EdgeInsets.only(bottom: isKeyboardOpen ? 8 : 0)),
            child: GoogleSignInButton(onPressed: onGoogleSignIn),
          ),
      ],
    );
  }
}
