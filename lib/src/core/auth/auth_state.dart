import 'package:budgly/src/models/user/user.dart';

class AuthState {
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
    String? errorCode,
    String? errorMessage,
    bool? isLoading,
    User? currentUser,
    bool? isGoogleSignIn,
  }) {
    return AuthState(
      formType: formType ?? this.formType,
      errorCode: errorCode,
      errorMessage: errorMessage,
      isLoading: isLoading ?? this.isLoading,
      currentUser: currentUser ?? this.currentUser,
      isGoogleSignIn: isGoogleSignIn ?? this.isGoogleSignIn,
    );
  }
}

enum AuthForm {
  signUp,
  signIn,
  resetPassword,
  verifyEmail;
}
