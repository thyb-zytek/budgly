import 'package:budgly/src/models/user/user_profile.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:budgly/src/services/providers/supabase/client.dart';

class UserProfileSupabase {
  final sb.SupabaseClient? _injected;
  final fb.FirebaseAuth? _authInput;
  late final sb.SupabaseClient _client = _injected ?? supabase;

  UserProfileSupabase({sb.SupabaseClient? client, fb.FirebaseAuth? auth})
    : _injected = client,
      _authInput = auth;

  Future<UserProfile?> getProfile(String userId) async {
    try {
      return await _getProfile(userId);
    } on sb.PostgrestException catch (e) {
      if (e.code == 'PGRST116') return null;
      if (!_isJwtError(e)) rethrow;

      final firebaseUser = (_authInput ?? fb.FirebaseAuth.instance).currentUser;
      if (firebaseUser == null) rethrow;
      await firebaseUser.getIdToken(true);
      return await _getProfile(userId);
    }
  }

  Future<UserProfile?> _getProfile(String userId) async {
    try {
      final response = await _client
          .from('user_profiles')
          .select()
          .eq('user_id', userId)
          .single();
      return UserProfile.fromJson(response);
    } on sb.PostgrestException catch (e) {
      if (e.code == 'PGRST116') return null;
      rethrow;
    }
  }

  bool _isJwtError(sb.PostgrestException e) =>
      e.code == 'PGRST303' || e.message.toLowerCase().contains('jwt');

  Future<UserProfile> createProfile(
    String userId,
    Map<String, dynamic> json,
  ) async {
    final payload = Map<String, dynamic>.from(json)
      ..remove('accounts')
      ..['user_id'] = userId;

    final response = await _client
        .from('user_profiles')
        .upsert(payload, onConflict: 'user_id')
        .select()
        .single();

    return UserProfile.fromJson(response);
  }

  Future<UserProfile> getOrCreateProfile(fb.User firebaseUser) async {
    final profile = await getProfile(firebaseUser.uid);
    if (profile != null) return profile;

    final payload = UserProfile(
      id: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      fullName:
          firebaseUser.displayName ??
          firebaseUser.email?.split('@').first ??
          'User',
      onboardingCompleted: false,
    ).toJson();

    try {
      return await createProfile(firebaseUser.uid, payload);
    } on sb.PostgrestException catch (e) {
      if (!_isJwtError(e)) rethrow;
      await firebaseUser.getIdToken(true);
      return await createProfile(firebaseUser.uid, payload);
    }
  }

  Future<bool> updateProfile(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    final rows = await _client
        .from('user_profiles')
        .update(updates)
        .eq('user_id', userId)
        .select('user_id');
    if (rows.isEmpty) {
      // An UPDATE that matches no row succeeds silently. Reporting success
      // here would make the sync queue drop the patch for good, so surface it
      // as a (transient) failure: the row is created the next time the
      // profile is loaded online, and the queued patch is retried after that.
      throw ProfileNotProvisionedException(userId);
    }
    return true;
  }
}

/// Thrown when a profile patch targets a `user_profiles` row that does not
/// exist yet. Treated as a transient sync failure (never classified as
/// permanent): the row appears once the profile has been provisioned online.
class ProfileNotProvisionedException implements Exception {
  const ProfileNotProvisionedException(this.userId);

  final String userId;

  @override
  String toString() =>
      'ProfileNotProvisionedException: no user_profiles row for $userId';
}
