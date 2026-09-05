import 'package:budgly/src/core/auth/auth_event.dart';
import 'package:budgly/src/core/auth/auth_exception.dart';
import 'package:budgly/src/core/auth/auth_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthState', () {
    test('defaults to sign-up and idle state', () {
      final state = AuthState();
      expect(state.formType, AuthForm.signUp);
      expect(state.isLoading, isFalse);
      expect(state.isGoogleSignIn, isFalse);
      expect(state.errorCode, isNull);
      expect(state.errorMessage, isNull);
      expect(state.currentUser, isNull);
    });

    test('copyWith updates selected fields and preserves nulls by default', () {
      final original = AuthState(
        formType: AuthForm.signIn,
        errorCode: 'emailInvalid',
        errorMessage: 'bad email',
        isLoading: true,
        isGoogleSignIn: true,
      );
      final next = original.copyWith(formType: AuthForm.resetPassword, isLoading: false);
      expect(next.formType, AuthForm.resetPassword);
      expect(next.isLoading, isFalse);
      expect(next.errorCode, 'emailInvalid');
      expect(next.errorMessage, 'bad email');
      expect(next.isGoogleSignIn, isTrue);
    });

    test('copyWith can explicitly clear error fields', () {
      final original = AuthState(errorCode: 'x', errorMessage: 'y');
      final next = original.copyWith(errorCode: null, errorMessage: null);
      expect(next.errorCode, isNull);
      expect(next.errorMessage, isNull);
    });

    test('equality and hashCode use all state fields', () {
      final a = AuthState(formType: AuthForm.signIn, isLoading: true);
      final b = AuthState(formType: AuthForm.signIn, isLoading: true);
      final c = AuthState(formType: AuthForm.signUp, isLoading: true);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });

  group('AuthEventParams', () {
    test('submit events invoke submitForm', () {
      for (final type in [AuthEvent.signIn, AuthEvent.signUp, AuthEvent.resetPassword]) {
        var called = false;
        AuthEventParams(type: type).when(submitForm: (valid) => called = valid);
        expect(called, isTrue);
      }
    });

    test('dispatches specialized callbacks only for matching event', () {
      var google = 0;
      var signOut = 0;
      var reload = 0;
      var resend = 0;
      var formChanges = 0;
      AuthEventParams(type: AuthEvent.googleSignIn).when(googleSignIn: () => google++);
      AuthEventParams(type: AuthEvent.signOut).when(signOut: () => signOut++);
      AuthEventParams(type: AuthEvent.reloadUser).when(reload: () => reload++);
      AuthEventParams(type: AuthEvent.resendEmailVerification).when(resendEmailVerification: () => resend++);
      AuthEventParams(type: AuthEvent.changeFormType, formType: AuthForm.signIn)
          .when(changeFormType: (_) => formChanges++);
      expect(google, 1);
      expect(signOut, 1);
      expect(reload, 1);
      expect(resend, 1);
      expect(formChanges, 1);
    });
  });

  test('AuthenticationException exposes code/message and useful toString', () {
    const error = AuthenticationException(message: 'Invalid', code: 'auth/invalid');
    expect(error.message, 'Invalid');
    expect(error.code, 'auth/invalid');
    expect(error.toString(), contains('auth/invalid'));
    expect(error.toString(), contains('Invalid'));
  });
}
