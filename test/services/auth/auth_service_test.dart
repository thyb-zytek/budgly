import 'package:budgly/src/core/auth/auth_exception.dart';
import 'package:budgly/src/models/user/user_profile.dart';
import 'package:budgly/src/services/auth/auth_service.dart';
import 'package:budgly/src/services/providers/supabase/user_profiles.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/builders.dart';
import 'package:mock_exceptions/mock_exceptions.dart';

class FakeUserProfileSupabase extends UserProfileSupabase {
  final Map<String, UserProfile> profiles = {};
  int getOrCreateCalls = 0;
  int updateCalls = 0;
  Map<String, dynamic>? lastUpdates;
  Object? getOrCreateError;

  @override
  Future<UserProfile?> getProfile(String userId) async {
    return profiles[userId];
  }

  @override
  Future<UserProfile> getOrCreateProfile(fb.User firebaseUser) async {
    getOrCreateCalls++;
    if (getOrCreateError != null) throw getOrCreateError!;
    return profiles[firebaseUser.uid] ?? Fixtures.profile(id: firebaseUser.uid);
  }

  @override
  Future<bool> updateProfile(String userId, Map<String, dynamic> updates) async {
    updateCalls++;
    lastUpdates = updates;
    return true;
  }
}

void main() {
  late FakeUserProfileSupabase profileSupabase;

  setUp(() {
    profileSupabase = FakeUserProfileSupabase();
  });

  MockFirebaseAuth signedInAuth({String uid = 'u1'}) => MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: uid, email: 'test@budgly.app'),
      );

  AuthService service(MockFirebaseAuth auth) => AuthService(
        auth: auth,
        userProfileSupabase: profileSupabase,
      );

  group('currentUser', () {
    test('maps the signed-in firebase user to a domain user', () {
      final auth = signedInAuth();
      final user = service(auth).currentUser;
      expect(user, isNotNull);
      expect(user!.id, 'u1');
      expect(user.email, 'test@budgly.app');
      expect(user.isAuthenticated, isTrue);
    });

    test('is null when no user is signed in', () {
      final user = service(MockFirebaseAuth(signedIn: false)).currentUser;
      expect(user, isNull);
    });
  });

  group('sign in', () {
    test('signInWithEmailAndPassword returns the user and profile', () async {
      final auth = MockFirebaseAuth(
        signedIn: false,
        mockUser: MockUser(uid: 'u1', email: 'test@budgly.app'),
      );
      profileSupabase.profiles['u1'] = Fixtures.profile(id: 'u1');

      final user = await service(auth).signInWithEmailAndPassword(
        'test@budgly.app',
        'password',
      );

      expect(user.id, 'u1');
      expect(profileSupabase.getOrCreateCalls, 1);
    });

    test('maps a FirebaseAuthException onto AuthenticationException', () async {
      final auth = MockFirebaseAuth(signedIn: false);
      whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
          .on(auth)
          .thenThrow(fb.FirebaseAuthException(code: 'invalid-credential'));

      expect(
        () => service(auth).signInWithEmailAndPassword('a@b.c', 'wrong'),
        throwsA(isA<AuthenticationException>()
            .having((e) => e.code, 'code', 'invalid-credential')),
      );
    });
  });

  group('sign up', () {
    test('signUpWithEmailAndPassword creates a user and the profile', () async {
      final auth = MockFirebaseAuth(signedIn: false);

      final user = await service(auth).signUpWithEmailAndPassword(
        'new@budgly.app',
        'password',
      );

      expect(user.email, 'new@budgly.app');
      expect(profileSupabase.getOrCreateCalls, 1);
    });

    test('signUpWithEmailAndPassword surfaces email-already-in-use',
        () async {
      final auth = MockFirebaseAuth(signedIn: false);
      whenCalling(Invocation.method(#createUserWithEmailAndPassword, null))
          .on(auth)
          .thenThrow(fb.FirebaseAuthException(code: 'email-already-in-use'));

      expect(
        () => service(auth).signUpWithEmailAndPassword('a@b.c', 'pw'),
        throwsA(isA<AuthenticationException>()
            .having((e) => e.code, 'code', 'email-already-in-use')),
      );
    });
  });

  group('password', () {
    test('changePassword reauthenticates and updates the password', () async {
      final auth = signedInAuth();
      profileSupabase.profiles['u1'] = Fixtures.profile(id: 'u1');

      final user = await service(auth).changePassword('old', 'new');

      expect(user.id, 'u1');
      expect(profileSupabase.getOrCreateCalls, 1);
    });

    test('changePassword throws when no user is signed in', () async {
      expect(
        () => service(MockFirebaseAuth(signedIn: false))
            .changePassword('old', 'new'),
        throwsA(isA<AuthenticationException>()),
      );
    });

    test('resetPassword forwards to the auth provider', () async {
      final auth = signedInAuth();
      await service(auth).resetPassword('test@budgly.app');
    });

    test('resetPassword maps provider errors onto AuthenticationException',
        () async {
      final auth = signedInAuth();
      whenCalling(Invocation.method(#sendPasswordResetEmail, null))
          .on(auth)
          .thenThrow(fb.FirebaseAuthException(code: 'user-not-found'));

      expect(
        () => service(auth).resetPassword('a@b.c'),
        throwsA(isA<AuthenticationException>()
            .having((e) => e.code, 'code', 'user-not-found')),
      );
    });
  });

  group('email verification', () {
    test('sendEmailVerification requests verification for a verified user',
        () async {
      final auth = signedInAuth();
      await service(auth).sendEmailVerification();
    });
  });

  group('profile + reload', () {
    test('onChangeName pushes the full name to the remote profile', () async {
      final auth = signedInAuth();
      await service(auth).onChangeName('Alice');

      expect(profileSupabase.updateCalls, 1);
      expect(profileSupabase.lastUpdates?['full_name'], 'Alice');
    });

    test('onChangeName throws without a signed-in user', () async {
      expect(
        () => service(MockFirebaseAuth(signedIn: false)).onChangeName('Alice'),
        throwsA(isA<AuthenticationException>()
            .having((e) => e.code, 'code', 'no-user')),
      );
    });

    test('reloadCurrentUser refetches the profile', () async {
      final auth = signedInAuth();
      profileSupabase.profiles['u1'] = Fixtures.profile(id: 'u1');

      final user = await service(auth).reloadCurrentUser();

      expect(user!.id, 'u1');
      expect(profileSupabase.getOrCreateCalls, 1);
    });

    test('reloadCurrentUser returns null when signed out', () async {
      final user = await service(MockFirebaseAuth(signedIn: false))
          .reloadCurrentUser();
      expect(user, isNull);
    });
  });
}
