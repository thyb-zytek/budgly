import 'dart:async';

import 'auth_state.dart';

enum AuthEvent {
  signIn,
  signUp,
  googleSignIn,
  resetPassword,
  signOut,
  changeFormType,
  reloadUser,
  resendEmailVerification,
}

class AuthEventParams {
  final AuthEvent type;
  final AuthForm? formType;
  final bool? keepEmail;

  AuthEventParams({required this.type, this.formType, this.keepEmail});

  Future<void> when({
    FutureOr<void> Function(bool isValid)? submitForm,
    FutureOr<void> Function()? googleSignIn,
    FutureOr<void> Function()? signOut,
    FutureOr<void> Function()? reload,
    FutureOr<void> Function(AuthForm formType)? changeFormType,
    FutureOr<void> Function()? resendEmailVerification,
  }) async {
    if ([
          AuthEvent.signIn,
          AuthEvent.signUp,
          AuthEvent.resetPassword,
        ].any((e) => e == type) &&
        submitForm != null) {
      await submitForm(true);
    }
    if (type == AuthEvent.googleSignIn && googleSignIn != null) await googleSignIn();
    if (type == AuthEvent.signOut && signOut != null) await signOut();
    if (type == AuthEvent.reloadUser && reload != null) await reload();
    if (type == AuthEvent.resendEmailVerification &&
        resendEmailVerification != null) {
      await resendEmailVerification();
    }
    if (type == AuthEvent.changeFormType && changeFormType != null) {
      changeFormType(formType!);
    }
  }
}
