import 'dart:convert';

import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/user/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalCache {
  static const _accountsPrefix = 'offline.accounts.';
  static const _categoriesPrefix = 'offline.categories.';
  static const _profilePrefix = 'offline.profile.';

  static final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  Future<void> saveAccounts(String userId, List<Account> accounts) async {
    final prefs = await _prefs;
    await prefs.setString(
      '$_accountsPrefix$userId',
      jsonEncode(accounts.map((account) => account.toJson()).toList()),
    );
  }


  Future<List<Account>?> loadAccounts(String userId) async {
    final prefs = await _prefs;
    final raw = prefs.getString('$_accountsPrefix$userId');
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .map((item) => Account.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e, st) {
      AppLogger.error('Failed to load cached accounts', e, st);
      return const [];
    }
  }

  Future<void> saveCategories(
    String accountId,
    List<Category> categories,
  ) async {
    final prefs = await _prefs;
    await prefs.setString(
      '$_categoriesPrefix$accountId',
      jsonEncode(categories.map((category) => category.toJson()).toList()),
    );
  }


  Future<List<Category>?> loadCategories(String accountId) async {
    final prefs = await _prefs;
    final raw = prefs.getString('$_categoriesPrefix$accountId');
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .map((item) => Category.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e, st) {
      AppLogger.error('Failed to load cached categories', e, st);
      return const [];
    }
  }

  Future<void> saveProfile(String userId, UserProfile profile) async {
    final prefs = await _prefs;
    await prefs.setString(
      '$_profilePrefix$userId',
      jsonEncode(profile.toJson()),
    );
  }

  Future<UserProfile?> loadProfile(String userId) async {
    final prefs = await _prefs;
    final raw = prefs.getString('$_profilePrefix$userId');
    if (raw == null) return null;

    try {
      return UserProfile.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (e, st) {
      AppLogger.error('Failed to load cached profile', e, st);
      return null;
    }
  }

  Future<void> clearUser(String userId) async {
    final prefs = await _prefs;
    await Future.wait([
      prefs.remove('$_accountsPrefix$userId'),
      prefs.remove('$_profilePrefix$userId'),
    ]);
  }

  Future<void> clearAccount(String accountId) async {
    final prefs = await _prefs;
    await prefs.remove('$_categoriesPrefix$accountId');
  }
}
