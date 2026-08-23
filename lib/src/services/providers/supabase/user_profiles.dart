import 'package:budgly/src/models/user/user_profile.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:budgly/src/services/providers/supabase/client.dart';

class UserProfileSupabase {
  sb.SupabaseClient get _client => supabase;

  Future<UserProfile?> getProfile(String userId) async {
    try {
      return await _getProfile(userId);
    } on sb.PostgrestException catch (e) {
      if (e.code == 'PGRST116') return null;
      if (!_isJwtError(e)) rethrow;

      // Supabase is using the Firebase ID token supplied by the
      // `accessToken` callback. A Supabase `refreshSession()` does not refresh
      // that Firebase token, so force-refresh Firebase and retry the request.
      final firebaseUser = fb.FirebaseAuth.instance.currentUser;
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
      fullName: firebaseUser.displayName ??
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
    await _client.from('user_profiles').update(updates).eq('user_id', userId);
    return true;
  }
}
