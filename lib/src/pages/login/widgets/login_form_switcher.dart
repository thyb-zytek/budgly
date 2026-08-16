import 'package:budgly/src/core/auth/auth_event.dart';
import 'package:budgly/src/core/auth/auth_state.dart';
import 'package:budgly/src/pages/login/view_model.dart';
import 'package:budgly/src/pages/login/widgets/google_sign_in_button.dart';
import 'package:budgly/src/pages/login/widgets/login_form.dart';
import 'package:budgly/src/pages/login/widgets/reset_password_form.dart';
import 'package:budgly/src/pages/login/widgets/signup_form.dart';
import 'package:budgly/src/pages/login/widgets/verify_email.dart';
import 'package:flutter/material.dart';

class LoginFormSwitcher extends StatelessWidget {
  final LoginViewModel viewModel;
  final void Function(AuthEventParams) onEvent;

  const LoginFormSwitcher({
    super.key,
    required this.viewModel,
    required this.onEvent,
  });

  @override
  Widget build(BuildContext context) {
    final formType = viewModel.state.formType;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        switch (formType) {
          AuthForm.signUp => SignUpForm(
              formKey: viewModel.formKey,
              emailController: viewModel.emailController,
              passwordController: viewModel.passwordController,
              password2Controller: viewModel.password2Controller,
              validateEmail: viewModel.validateEmail,
              validatePassword: viewModel.validatePassword,
              validateConfirmPassword: viewModel.validateConfirmPassword,
              onSignInPressed: () => onEvent(
                AuthEventParams(type: AuthEvent.changeFormType, formType: AuthForm.signIn),
              ),
              onSubmitForm: () => onEvent(AuthEventParams(type: AuthEvent.signUp)),
            ),
          AuthForm.signIn => LoginForm(
              formKey: viewModel.formKey,
              emailController: viewModel.emailController,
              passwordController: viewModel.passwordController,
              validateEmail: viewModel.validateEmail,
              validatePassword: viewModel.validatePassword,
              onSignUpPressed: () => onEvent(
                AuthEventParams(type: AuthEvent.changeFormType, formType: AuthForm.signUp),
              ),
              onSubmitForm: () => onEvent(AuthEventParams(type: AuthEvent.signIn)),
              onResetPassword: () => onEvent(
                AuthEventParams(
                  type: AuthEvent.changeFormType,
                  formType: AuthForm.resetPassword,
                  keepEmail: true,
                ),
              ),
            ),
          AuthForm.resetPassword => ResetPasswordForm(
              formKey: viewModel.formKey,
              emailController: viewModel.emailController,
              validateEmail: viewModel.validateEmail,
              onSubmitForm: () => onEvent(AuthEventParams(type: AuthEvent.resetPassword)),
              onSignInPressed: () => onEvent(
                AuthEventParams(type: AuthEvent.changeFormType, formType: AuthForm.signIn),
              ),
            ),
          AuthForm.verifyEmail => VerifyEmail(
              email: viewModel.state.currentUser?.email ?? viewModel.emailController.text,
              onResendPressed: () => onEvent(
                AuthEventParams(type: AuthEvent.resendEmailVerification),
              ),
              onSignInPressed: () => onEvent(AuthEventParams(type: AuthEvent.signOut)),
              onReload: () => onEvent(AuthEventParams(type: AuthEvent.reloadUser)),
            ),
        },
        if ([AuthForm.signUp, AuthForm.signIn, AuthForm.resetPassword].contains(formType))
          Padding(
            padding: EdgeInsets.all(24).add(
              EdgeInsets.only(bottom: isKeyboardOpen ? 8 : 0),
            ),
            child: GoogleSignInButton(
              onPressed: () => onEvent(
                AuthEventParams(type: AuthEvent.googleSignIn),
              ),
            ),
          ),
      ],
    );
  }
}