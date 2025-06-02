class AuthError {
  final String code;
  final String message;

  AuthError(this.code, this.message);
}

enum AuthErrorCode {
  emailRequired,
  emailInvalid,
  passwordRequired,
  passwordTooShort,
  passwordsDoNotMatch,
  signUpError,
  signInError,
  resetPasswordError,
  googleSignInError,
  signOutError,
  userNotFound,
  invalidCredentials,
  unknownError,
  emailAlreadyInUse, wrongPassword;

  String get code {
    return toString().split('.').last;
  }
}
