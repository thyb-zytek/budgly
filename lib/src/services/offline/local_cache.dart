import 'dart:convert';

import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/user/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalCache {
  static const _accountsPrefix = 'offline.accounts.';
  static const _categoriesPrefix = 'offline.categories.';
  static const _profilePrefix = 'offline.profile.';
  static const _undebitedBannerPrefix = 'undebited.banner.dismissedAt.';

  // Resolve lazily so Flutter test bootstrap can install the in-memory
  // SharedPreferences implementation before the first platform call.
  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

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


  Future<void> saveUndebitedBannerDismissedAt(
    String accountId, {
    required Period period,
    required DateTime value,
  }) async {
    final prefs = await _prefs;
    await prefs.setString(
      '$_undebitedBannerPrefix$accountId',
      '${period.year}-${period.month}|${value.toIso8601String()}',
    );
  }

  /// The dismissal is scoped to the reporting [Period] it was recorded in, so
  /// the banner can reappear when the app is opened for a new month.
  Future<({Period period, DateTime at})?> loadUndebitedBannerDismissedAt(
    String accountId,
  ) async {
    final prefs = await _prefs;
    final raw = prefs.getString('$_undebitedBannerPrefix$accountId');
    if (raw == null) return null;

    final parts = raw.split('|');
    if (parts.length != 2) return null;
    final periodParts = parts[0].split('-');
    if (periodParts.length != 2) return null;

    final year = int.tryParse(periodParts[0]);
    final month = int.tryParse(periodParts[1]);
    final at = DateTime.tryParse(parts[1]);
    if (year == null || month == null || at == null) return null;

    return (period: Period(year: year, month: month), at: at);
  }

  /// Removes the persisted undebited-banner dismissal so a later refresh can
  /// re-arm the banner without waiting for the redisplay interval to elapse.
  Future<void> clearUndebitedBannerDismissedAt(String accountId) async {
    final prefs = await _prefs;
    await prefs.remove('$_undebitedBannerPrefix$accountId');
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
