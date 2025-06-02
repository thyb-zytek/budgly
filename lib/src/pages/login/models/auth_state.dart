import 'package:app/src/models/user/user.dart';

class AuthState {
  final AuthForm formType;
  final String? errorCode;
  final String? errorMessage;
  final bool isLoading;
  final User? currentUser;

  AuthState({
    this.formType = AuthForm.signUp,
    this.errorCode,
    this.errorMessage,
    this.isLoading = false,
    this.currentUser,
  });

  AuthState copyWith({
    AuthForm? formType,
    String? errorCode,
    String? errorMessage,
    bool? isLoading,
    User? currentUser,
  }) {
    return AuthState(
      formType: formType ?? this.formType,
      errorCode: errorCode,
      errorMessage: errorMessage,
      isLoading: isLoading ?? this.isLoading,
      currentUser: currentUser ?? this.currentUser,
    );
  }
}

enum AuthForm {
  signUp,
  signIn,
  resetPassword,
  verifyEmail;
}
