import 'dart:async';
import 'dart:convert';

import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/user/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Last-known server state, persisted per user/account for cache-first reads.
///
/// A single instance must be shared by every service (see
/// `localCacheProvider`): mutations use [updateAccounts] / [updateCategories],
/// which serialize their read-modify-write cycle with cache writes coming from
/// background revalidation. Without this, two overlapping cycles could each
/// read the same snapshot and the last writer would silently discard the
/// other's change.
///
/// A payload that cannot be decoded is quarantined under a `.corrupt.` key and
/// reported as *absent* (`null`), so callers fall back to the server instead of
/// presenting a corrupted cache as "the user has no data".
class LocalCache {
  /// Bump when a cached model's JSON shape changes in a way `fromJson` can't
  /// safely absorb (a new required field, a renamed/retyped field, ...).
  /// Every cache key embeds this version, so a bump makes every entry written
  /// under the previous version invisible (`load...` returns `null`, exactly
  /// like a first run) instead of risking a silent bad decode of stale data —
  /// this is a *stronger* guarantee than the per-read corruption handling
  /// below, which only catches a decode that outright throws.
  /// [purgeObsoleteCacheEntries] can be called once at startup to reclaim the
  /// storage of entries left behind by a previous version.
  static const _schemaVersion = 1;
  static const _namespace = 'offline.v$_schemaVersion.';

  static const _accountsPrefix = '${_namespace}accounts.';
  static const _categoriesPrefix = '${_namespace}categories.';
  static const _profilePrefix = '${_namespace}profile.';
  static const _undebitedBannerPrefix = '${_namespace}undebited_banner.';

  /// Prefixes used before schema versioning existed (the real case on every
  /// device today, since `_schemaVersion` starts at 1). Kept as an explicit
  /// list rather than "anything starting with `offline.`" so this can never
  /// reach into an unrelated namespace, such as `SyncQueue`'s
  /// `offline.pending_sync.v2` key. The next time `_schemaVersion` is bumped,
  /// add that version's four prefixes here too.
  static const _obsoletePrefixes = <String>[
    'offline.accounts.',
    'offline.categories.',
    'offline.profile.',
    'undebited.banner.dismissedAt.',
  ];

  // Resolve lazily so Flutter test bootstrap can install the in-memory
  // SharedPreferences implementation before the first platform call.
  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<void> _lock = Future<void>.value();

  Future<T> _serialized<T>(Future<T> Function() action) {
    final previous = _lock;
    final release = Completer<void>();
    _lock = previous.then((_) => release.future);
    return previous.then((_) => action()).whenComplete(release.complete);
  }

  Future<void> _quarantine(String key, String raw) async {
    try {
      final prefs = await _prefs;
      await prefs.setString('$key.corrupt', raw);
      await prefs.remove(key);
    } catch (e, st) {
      AppLogger.error('Failed to quarantine cached data ($key)', e, st);
    }
  }

  Future<void> saveAccounts(String userId, List<Account> accounts) =>
      _serialized(() => _saveAccounts(userId, accounts));

  Future<void> _saveAccounts(String userId, List<Account> accounts) async {
    final prefs = await _prefs;
    await prefs.setString(
      '$_accountsPrefix$userId',
      jsonEncode(accounts.map((account) => account.toJson()).toList()),
    );
  }

  /// Atomically replaces the cached accounts with `transform(current)`.
  ///
  /// [transform] may be asynchronous (for example to merge pending queue
  /// operations); it runs while the cache lock is held, so no other cache
  /// write can interleave. It must not call other [LocalCache] write methods
  /// and should avoid slow work such as network calls. Returning `null` leaves
  /// the cache untouched (used when there is no cache to patch yet).
  Future<List<Account>?> updateAccounts(
    String userId,
    FutureOr<List<Account>?> Function(List<Account>? current) transform,
  ) => _serialized(() async {
    final current = await _loadAccounts(userId);
    final next = await transform(current);
    if (next == null) return current;
    await _saveAccounts(userId, next);
    return next;
  });

  Future<List<Account>?> loadAccounts(String userId) =>
      _serialized(() => _loadAccounts(userId));

  Future<List<Account>?> _loadAccounts(String userId) async {
    final prefs = await _prefs;
    final key = '$_accountsPrefix$userId';
    final raw = prefs.getString(key);
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .map(
            (item) => Account.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    } catch (e, st) {
      AppLogger.error('Failed to load cached accounts', e, st);
      await _quarantine(key, raw);
      return null;
    }
  }

  Future<void> saveCategories(String accountId, List<Category> categories) =>
      _serialized(() => _saveCategories(accountId, categories));

  Future<void> _saveCategories(
    String accountId,
    List<Category> categories,
  ) async {
    final prefs = await _prefs;
    await prefs.setString(
      '$_categoriesPrefix$accountId',
      jsonEncode(categories.map((category) => category.toJson()).toList()),
    );
  }

  /// Atomically replaces the cached categories of [accountId]; same contract
  /// as [updateAccounts].
  Future<List<Category>?> updateCategories(
    String accountId,
    FutureOr<List<Category>?> Function(List<Category>? current) transform,
  ) => _serialized(() async {
    final current = await _loadCategories(accountId);
    final next = await transform(current);
    if (next == null) return current;
    await _saveCategories(accountId, next);
    return next;
  });

  Future<List<Category>?> loadCategories(String accountId) =>
      _serialized(() => _loadCategories(accountId));

  Future<List<Category>?> _loadCategories(String accountId) async {
    final prefs = await _prefs;
    final key = '$_categoriesPrefix$accountId';
    final raw = prefs.getString(key);
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .map(
            (item) => Category.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    } catch (e, st) {
      AppLogger.error('Failed to load cached categories', e, st);
      await _quarantine(key, raw);
      return null;
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
    final key = '$_profilePrefix$userId';
    final raw = prefs.getString(key);
    if (raw == null) return null;

    try {
      return UserProfile.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (e, st) {
      AppLogger.error('Failed to load cached profile', e, st);
      await _quarantine(key, raw);
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

  /// Removes every cache entry (including quarantined blobs) left behind by a
  /// previous [_schemaVersion]. Safe to call repeatedly; a no-op once the
  /// device has nothing older than the current version. Meant to be called
  /// once, best-effort, at startup (see `syncBootstrapProvider`) — never
  /// awaited by anything the user is waiting on.
  Future<void> purgeObsoleteCacheEntries() async {
    try {
      final prefs = await _prefs;
      final obsolete = prefs.getKeys().where(
        (key) => _obsoletePrefixes.any(key.startsWith),
      );
      for (final key in obsolete) {
        await prefs.remove(key);
      }
    } catch (e, st) {
      AppLogger.error('Failed to purge obsolete local cache entries', e, st);
    }
  }

  Future<void> clearUser(String userId) => _serialized(() async {
    final prefs = await _prefs;
    await Future.wait([
      prefs.remove('$_accountsPrefix$userId'),
      prefs.remove('$_profilePrefix$userId'),
    ]);
  });

  Future<void> clearAccount(String accountId) => _serialized(() async {
    final prefs = await _prefs;
    await prefs.remove('$_categoriesPrefix$accountId');
  });
}
