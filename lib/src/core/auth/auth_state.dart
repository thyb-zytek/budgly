import 'package:budgly/src/models/user/user.dart';

class AuthState {
  static const _sentinel = Object();

  final AuthForm formType;
  final String? errorCode;
  final String? errorMessage;
  final bool isLoading;
  final User? currentUser;
  final bool isGoogleSignIn;

  AuthState({
    this.formType = AuthForm.signUp,
    this.errorCode,
    this.errorMessage,
    this.isLoading = false,
    this.currentUser,
    this.isGoogleSignIn = false,
  });

  AuthState copyWith({
    AuthForm? formType,
    Object? errorCode = _sentinel,
    Object? errorMessage = _sentinel,
    bool? isLoading,
    Object? currentUser = _sentinel,
    bool? isGoogleSignIn,
  }) {
    return AuthState(
      formType: formType ?? this.formType,
      errorCode:
          errorCode == _sentinel ? this.errorCode : errorCode as String?,
      errorMessage:
          errorMessage == _sentinel ? this.errorMessage : errorMessage as String?,
      isLoading: isLoading ?? this.isLoading,
      currentUser: currentUser == _sentinel ? this.currentUser : currentUser as User?,
      isGoogleSignIn: isGoogleSignIn ?? this.isGoogleSignIn,
    );
  }
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthState &&
          other.formType == formType &&
          other.errorCode == errorCode &&
          other.errorMessage == errorMessage &&
          other.isLoading == isLoading &&
          other.currentUser == currentUser &&
          other.isGoogleSignIn == isGoogleSignIn;

  @override
  int get hashCode => Object.hash(
        formType,
        errorCode,
        errorMessage,
        isLoading,
        currentUser,
        isGoogleSignIn,
      );

}

enum AuthForm {
  signUp,
  signIn,
  resetPassword,
  verifyEmail;
}
