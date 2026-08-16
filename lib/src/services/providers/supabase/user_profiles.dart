import 'package:budgly/src/models/user/user_profile.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:budgly/src/services/providers/supabase/client.dart';

class UserProfileSupabase {
  sb.SupabaseClient get _client => supabase;

  Future<UserProfile?> getProfile(String userId) async {
    try {
      final response =
          await _client.from('user_profiles').select().eq('user_id', userId).single();
      return UserProfile.fromJson(response);
    } on sb.PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        return null;
      }
      // Handle JWT errors - usually due to clock sync issues
      if (e.code == 'PGRST303' || e.message.contains('JWT')) {
        // Try to refresh the auth session
        try {
          await sb.Supabase.instance.client.auth.refreshSession();
          // Retry the request
          final response =
              await _client.from('user_profiles').select().eq('user_id', userId).single();
          return UserProfile.fromJson(response);
        } catch (_) {
          rethrow;
        }
      }
      rethrow;
    }
  }

  Future<UserProfile> createProfile(
    String userId,
    Map<String, dynamic> json,
  ) async {
    json.remove('accounts');

    try {
      final response =
          await _client
              .from('user_profiles')
              .update(json)
              .eq('user_id', userId)
              .select()
              .single();
      return UserProfile.fromJson(response);
    } catch (_) {
      final response =
          await _client.from('user_profiles').insert(json).select().single();
      return UserProfile.fromJson(response);
    }
  }

  Future<UserProfile> getOrCreateProfile(fb.User firebaseUser) async {
    final profile = await getProfile(firebaseUser.uid);
    if (profile != null) {
      return profile;
    }
    return createProfile(
      firebaseUser.uid,
      UserProfile(
        id: firebaseUser.uid,
        email: firebaseUser.email!,
        fullName:
            firebaseUser.displayName ?? firebaseUser.email!.split('@').first,
      ).toJson(),
    );
  }

  Future<bool> updateProfile(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    await _client.from('user_profiles').update(updates).eq('user_id', userId);
    return true;
  }
}
