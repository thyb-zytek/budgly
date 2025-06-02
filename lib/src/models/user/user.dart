import 'package:firebase_auth/firebase_auth.dart' as firebase;

class User {
  final String id;
  final String email;
  final String name;
  final bool emailVerified;

  final String? photoURL;

  User({
    required this.id,
    required this.email,
    required this.name,
    this.emailVerified = false,
    this.photoURL = null,
  });

  factory User.fromFirebaseUser(firebase.User user) {
    return User(
      id: user.uid,
      email: user.email!,
      name: user.displayName ?? '',
      emailVerified: user.emailVerified,
      photoURL: user.photoURL,
    );
  }
}
