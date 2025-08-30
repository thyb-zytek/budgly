import 'package:app/src/models/user/user_profile.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:app/src/models/account/account.dart';
import 'package:app/src/models/category/category.dart';

class SupabaseService {
  final sb.SupabaseClient _supabase = sb.Supabase.instance.client;

  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  Future<UserProfile?> getProfile(String userId) async {
    try {
      final response =
          await _supabase
              .from('user_profiles')
              .select()
              .eq('user_id', userId)
              .single();
      return UserProfile.fromJson(response);
    } on sb.PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        return null;
      }
      print('Error getting user profile: ${e.message}');
      return null;
    }
  }

  Future<UserProfile> createProfile(
    String userId,
    Map<String, dynamic> json,
  ) async {
    try {
      json.remove("accounts");

      try {
        final response =
            await _supabase
                .from('user_profiles')
                .update(json)
                .eq('user_id', userId)
                .select()
                .single();
        return UserProfile.fromJson(response);
      } catch (e) {
        final response =
            await _supabase
                .from('user_profiles')
                .insert(json)
                .select()
                .single();
        return UserProfile.fromJson(response);
      }
    } catch (e) {
      print('Error creating/updating profile: $e');
      rethrow;
    }
  }

  Future<UserProfile> getOrCreateProfile(fb.User firebaseUser) async {
    try {
      final profile = await getProfile(firebaseUser.uid);
      if (profile == null) {
        return createProfile(
          firebaseUser.uid,
          UserProfile(
            id: firebaseUser.uid,
            email: firebaseUser.email!,
            fullName:
                firebaseUser.displayName ??
                firebaseUser.email!.split('@').first,
          ).toJson(),
        );
      }
      return profile;
    } on sb.PostgrestException {
      rethrow;
    }
  }

  Future<bool> updateProfile(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _supabase.from('user_profiles').update(updates).eq('user_id', userId);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Account Operations
  Future<List<Account>> getUserAccounts(String userId) async {
    try {
      final response = await _supabase
          .from('accounts')
          .select()
          .eq('user_id', userId);

      return (response as List<dynamic>)
          .map((json) => Account.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting user accounts: $e');
      return [];
    }
  }

  Future<Account?> createAccount(Account account) async {
    try {
      final response =
          await _supabase
              .from('accounts')
              .insert(account.toJson())
              .select()
              .single();
      return Account.fromJson(response);
    } catch (e) {
      print('Error creating account: $e');
      return null;
    }
  }

  Future<bool> updateAccount(Account account) async {
    try {
      await _supabase
          .from('accounts')
          .update(account.toJson())
          .eq('id', account.id);
      return true;
    } catch (e) {
      print('Error updating account: $e');
      return false;
    }
  }

  Future<bool> deleteAccount(String accountId) async {
    try {
      await _supabase.from('accounts').delete().eq('id', accountId);
      return true;
    } catch (e) {
      print('Error deleting account: $e');
      return false;
    }
  }

  // Category Operations
  Future<List<Category>> getCategoriesByAccount(String accountId) async {
    try {
      final response = await _supabase
          .from('categories')
          .select()
          .eq('account_id', accountId);

      return (response as List<dynamic>)
          .map((json) => Category.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting categories: $e');
      return [];
    }
  }

  Future<Category?> createCategory(Category category) async {
    try {
      final response =
          await _supabase
              .from('categories')
              .insert(category.toJson())
              .select()
              .single();
      return Category.fromJson(response);
    } catch (e) {
      print('Error creating category: $e');
      return null;
    }
  }

  Future<bool> updateCategory(Category category) async {
    try {
      await _supabase
          .from('categories')
          .update(category.toJson())
          .eq('id', category.id);
      return true;
    } catch (e) {
      print('Error updating category: $e');
      return false;
    }
  }

  Future<bool> deleteCategory(String categoryId) async {
    try {
      await _supabase.from('categories').delete().eq('id', categoryId);
      return true;
    } catch (e) {
      print('Error deleting category: $e');
      return false;
    }
  }
}
