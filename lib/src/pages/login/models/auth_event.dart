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

  void when({
    void Function()? submitForm,
    void Function()? googleSignIn,
    void Function()? signOut,
    void Function()? reload,
    void Function(AuthForm formType)? changeFormType,
    void Function()? resendEmailVerification,
  }) {
    if ([
          AuthEvent.signIn,
          AuthEvent.signUp,
          AuthEvent.resetPassword,
        ].any((e) => e == type) &&
        submitForm != null)
      submitForm();
    if (type == AuthEvent.googleSignIn && googleSignIn != null) googleSignIn();
    if (type == AuthEvent.signOut && signOut != null) signOut();
    if (type == AuthEvent.reloadUser && reload != null) reload();
    if (type == AuthEvent.resendEmailVerification &&
        resendEmailVerification != null) {
      resendEmailVerification();
    }
    if (type == AuthEvent.changeFormType && changeFormType != null) {
      changeFormType(formType!);
    }
  }
}
