import 'package:budgly/src/core/auth/auth_session.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notifies listeners when the injected auth session changes', () async {
    final auth = MockFirebaseAuth(signedIn: false);
    final notifier = AuthSessionNotifier(auth: auth);
    var notifications = 0;
    notifier.addListener(() => notifications++);

    await auth.signInWithEmailAndPassword(
      email: 'test@budgly.app',
      password: 'password',
    );
    await Future<void>.delayed(Duration.zero);

    expect(notifications, greaterThanOrEqualTo(1));
    notifier.dispose();
  });
}
