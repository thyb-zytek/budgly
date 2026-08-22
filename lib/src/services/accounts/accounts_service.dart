import 'dart:io';

import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/services/cache/cache_controller.dart';
import 'package:budgly/src/stores/accounts.dart';
import 'package:budgly/src/services/providers/supabase/accounts.dart';
import 'package:budgly/src/services/providers/supabase/storage.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';

class AccountsService {
  static AccountsService? _instance;

  static AccountsService get instance {
    _instance ??= AccountsService._();
    return _instance!;
  }

  final AccountSupabase _accountSupabase;
  final StorageSupabase _storageSupabase;
  final fb.FirebaseAuth _auth;
  final String _bucketId = AppConstants.bucketAccounts;

  final CacheController<String> _cache =
      CacheController<String>(ttl: AppConstants.cacheValidityMedium);
  final AccountsStore _store;
  static const String _cacheKey = 'accounts';

  AccountsService({
    AccountSupabase? accountSupabase,
    StorageSupabase? storageSupabase,
    fb.FirebaseAuth? auth,
    AccountsStore? store,
  })  : _accountSupabase = accountSupabase ?? AccountSupabase(),
        _storageSupabase = storageSupabase ?? StorageSupabase(),
        _auth = auth ?? fb.FirebaseAuth.instance,
        _store = store ?? AccountsStore.instance;

  AccountsService._() : this();

  Listenable get changeNotifier => _store;
  List<Account> get accounts => _store.accounts;
  bool get isLoading => _store.isLoading;
  bool get hasLoaded => _store.hasLoaded;

  void invalidateCache() {
    _cache.invalidate();
    _store.setLoaded(false);
  }

  String get _currentUserId {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }
    return user.uid;
  }

  Future<void> loadAccounts({bool forceRefresh = false}) async {
    if (!forceRefresh && _store.hasLoaded && _cache.isFresh(_cacheKey)) return;

    final inFlight = _cache.inFlight(_cacheKey);
    if (inFlight != null) return inFlight;

    final future = _loadAccounts(forceRefresh: forceRefresh);
    _cache.track(_cacheKey, future);
    try {
      await future;
    } finally {
      _cache.untrack(_cacheKey, future);
    }
  }

  Future<void> _loadAccounts({required bool forceRefresh}) async {
    final generation = _cache.generation;
    _store.beginLoading();
    try {
      final accounts = await _fetchAccountsWithSignedUrls(forceRefresh: forceRefresh);
      if (generation != _cache.generation) return;
      _store.setAccounts(accounts);
      _store.setLoaded(true);
    } finally {
      _store.endLoading();
    }
  }

  Future<List<Account>> _fetchAccountsWithSignedUrls({
    bool forceRefresh = false,
  }) async {
    final cacheValid = !forceRefresh &&
        _store.accounts.isNotEmpty &&
        _cache.isFresh(_cacheKey);

    if (cacheValid) {
      if (_store.accounts.any(
        (acc) => acc.picture != null && acc.pictureUrl == null,
      )) {
        return _loadSignedUrlsForCachedAccounts();
      }
      return _store.accounts;
    }

    final userId = _currentUserId;
    final rows = await _accountSupabase.listByUserId(userId);
    final freshAccounts = await _withSignedUrls(rows);
    _cache.markFresh(_cacheKey);
    return freshAccounts;
  }

  Future<List<Account>> _withSignedUrls(List<Account> accounts) async {
    final userId = _currentUserId;
    return Future.wait(
      accounts.map((account) async {
        if (account.picture != null && account.id != null) {
          try {
            final objectKey = '$userId/${account.id}/${account.picture}';
            final pictureUrl = await _storageSupabase.getSignedUrl(
              bucketId: _bucketId,
              filePath: objectKey,
            );
            return account.copyWith(pictureUrl: pictureUrl);
          } catch (_) {
            return account;
          }
        }
        return account;
      }),
    );
  }

  Future<List<Account>> _loadSignedUrlsForCachedAccounts() async {
    final accountsWithUrls = _store.accounts
        .where((acc) => acc.picture == null || acc.pictureUrl != null)
        .toList();
    final accountsWithoutUrls = _store.accounts
        .where((acc) => acc.picture != null && acc.pictureUrl == null)
        .toList();
    final resolved = await _withSignedUrls(accountsWithoutUrls);
    return [...accountsWithUrls, ...resolved];
  }

  Future<Account> createAccount(Account account) async {
    final generation = _cache.generation;
    final created = await _accountSupabase.create(
      account.copyWith(userId: _currentUserId),
    );
    if (created != null) {
      if (generation == _cache.generation) _store.addAccount(created);
      return created;
    }
    throw Exception('Failed to create account');
  }

  Future<Account> updateAccount(Account account) async {
    final generation = _cache.generation;
    final updated = await _accountSupabase.update(account);
    if (updated != null) {
      // The DB row carries no signed URL: preserve the existing one when
      // the underlying picture file did not change.
      final merged =
          (updated.picture != null && updated.picture == account.picture)
              ? updated.copyWith(pictureUrl: account.pictureUrl)
              : updated;
      if (generation == _cache.generation) _store.updateAccount(merged);
      return merged;
    }
    throw Exception('Failed to update account');
  }

  void updateLocalAccount(Account account) {
    _store.updateAccount(account);
  }

  Future<bool> deleteAccount(String accountId) async {
    final generation = _cache.generation;
    final deleted = await _accountSupabase.delete(accountId);
    if (deleted) {
      if (generation == _cache.generation) _store.removeAccount(accountId);
      return deleted;
    }
    throw Exception('Failed to delete account');
  }

  Future<String?> uploadPicture(
    File file,
    String accountId,
    String fileName,
  ) async {
    return _storageSupabase.uploadFile(
      bucketId: _bucketId,
      filePath: file.absolute.path,
      userId: _currentUserId,
      prefix: accountId,
      fileName: fileName,
    );
  }

  Future<String?> getSignedUrl(String path, String accountId) async {
    final fullPath = '$_currentUserId/$accountId/$path';
    try {
      return await _storageSupabase.getSignedUrl(
        bucketId: _bucketId,
        filePath: fullPath,
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> deletePicture(String path, String accountId) async {
    final fullPath = '$_currentUserId/$accountId/$path';
    return _storageSupabase.deleteFile(
      bucketId: _bucketId,
      filePath: fullPath,
    );
  }

  Future<void> deleteAccountFolder(String accountId) async {
    final folderPath = '$_currentUserId/$accountId';
    await _storageSupabase.deleteFolder(
      bucketId: _bucketId,
      folderPath: folderPath,
    );
  }

  Account? getAccountById(String id) {
    return _store.getAccountById(id);
  }

  void clearLocalAccounts() {
    _cache.invalidate();
    _store.clearLocalAccounts();
  }
}