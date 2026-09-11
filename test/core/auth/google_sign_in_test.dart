import 'package:budgly/src/core/auth/google_sign_in.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GoogleSignInInitializer', () {
    test('ensureInitialized memoizes the same future across calls', () {
      final future = Future<void>.value();
      GoogleSignInInitializer.reinitializeForTest(future: future);

      expect(GoogleSignInInitializer.ensureInitialized(), same(future));
      expect(GoogleSignInInitializer.ensureInitialized(), same(future));
    });

    test('reinitializeForTest replaces the cached future', () {
      final first = Future<void>.value();
      GoogleSignInInitializer.reinitializeForTest(future: first);
      expect(GoogleSignInInitializer.ensureInitialized(), same(first));

      final second = Future<void>.value();
      GoogleSignInInitializer.reinitializeForTest(future: second);
      expect(GoogleSignInInitializer.ensureInitialized(), same(second));
    });

    test('reinitializeForTest(null) clears the cache so the next call re-initializes', () {
      final first = Future<void>.value();
      GoogleSignInInitializer.reinitializeForTest(future: first);
      expect(GoogleSignInInitializer.ensureInitialized(), same(first));

      GoogleSignInInitializer.reinitializeForTest();
      // Re-seed immediately so the real (platform-dependent) initialize()
      // call is never actually reached by this test.
      final replacement = Future<void>.value();
      GoogleSignInInitializer.reinitializeForTest(future: replacement);
      expect(GoogleSignInInitializer.ensureInitialized(), same(replacement));
      expect(GoogleSignInInitializer.ensureInitialized(), isNot(same(first)));
    });
  });
}
