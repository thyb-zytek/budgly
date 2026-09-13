import 'package:budgly/src/core/auth/auth_session.dart';
import 'package:budgly/src/core/auth/auth_session_provider.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockFirebaseAuth mockAuth;
  late AuthSessionNotifier notifier;
  late ProviderContainer container;

  setUp(() {
    mockAuth = MockFirebaseAuth(signedIn: false);
    notifier = AuthSessionNotifier(auth: mockAuth);
    container = ProviderContainer(
      overrides: [authSessionProvider.overrideWithValue(notifier)],
    );
    addTearDown(container.dispose);
    addTearDown(notifier.dispose);
  });

  test('initial revision is 0', () {
    expect(container.read(authSessionRevisionProvider), 0);
  });

  test('increments on every auth state change', () async {
    container.read(authSessionRevisionProvider); // ensure build() ran, listener attached

    var notifications = 0;
    container.listen(authSessionRevisionProvider, (previous, next) => notifications++);

    await mockAuth.signInWithEmailAndPassword(
      email: 'test@budgly.app',
      password: 'password',
    );
    await Future<void>.delayed(Duration.zero);

    expect(container.read(authSessionRevisionProvider), greaterThanOrEqualTo(1));
    expect(notifications, greaterThanOrEqualTo(1));
  });

  test('authSessionProvider exposes the overridden notifier', () {
    expect(container.read(authSessionProvider), same(notifier));
  });

  test('disposing the container detaches the listener without error', () async {
    final localMockAuth = MockFirebaseAuth(signedIn: false);
    final localNotifier = AuthSessionNotifier(auth: localMockAuth);
    addTearDown(localNotifier.dispose);
    final localContainer = ProviderContainer(
      overrides: [authSessionProvider.overrideWithValue(localNotifier)],
    );
    localContainer.read(authSessionRevisionProvider);
    localContainer.dispose();

    // Must not throw: if ref.onDispose hadn't removed the listener, this
    // would try to mutate a disposed Notifier's state from the callback.
    await localMockAuth.signInWithEmailAndPassword(
      email: 'test@budgly.app',
      password: 'password',
    );
    await Future<void>.delayed(Duration.zero);
  });
}
