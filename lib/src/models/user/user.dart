import 'package:firebase_auth/firebase_auth.dart' as firebase;

import 'user_profile.dart';

enum AuthProvider { google, email }

class User {
  final String id;
  final String? email;
  final bool emailVerified;
  final Uri? avatarUrl;
  final AuthProvider provider;
  final UserProfile? profile;

  User({
    required this.id,
    this.email,
    this.emailVerified = false,
    this.avatarUrl,
    this.provider = AuthProvider.email,
    this.profile,
  });

  bool get hasProfile => profile != null;

  bool get isAuthenticated => id.isNotEmpty;

  bool get isGoogleUser => provider == AuthProvider.google;

  factory User.fromFirebaseUser(
    firebase.User firebaseUser, {
    UserProfile? profile,
  }) {
    return User(
      id: firebaseUser.uid,
      email: firebaseUser.email,
      emailVerified: firebaseUser.emailVerified,
      avatarUrl:
          firebaseUser.photoURL != null
              ? Uri.parse(firebaseUser.photoURL!)
              : null,
      provider:
          firebaseUser.providerData.first.providerId == 'google.com'
              ? AuthProvider.google
              : AuthProvider.email,
      profile: profile,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String?,
      emailVerified: json['email_verified'] as bool? ?? false,
      avatarUrl:
          json['avatar_url'] != null
              ? Uri.parse(json['avatar_url'] as String)
              : null,
      profile:
          json['profile'] != null
              ? UserProfile.fromJson(json['profile'] as Map<String, dynamic>)
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'email_verified': emailVerified,
      'avatar_url': avatarUrl?.toString(),
      'profile': profile?.toJson(),
    };
  }

  User copyWith({
    String? id,
    String? email,
    bool? emailVerified,
    Uri? avatarUrl,
    UserProfile? profile,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      emailVerified: emailVerified ?? this.emailVerified,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      profile: profile ?? this.profile,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is User && other.id == id && other.email == email;
  }

  @override
  int get hashCode => id.hashCode ^ email.hashCode;
}
