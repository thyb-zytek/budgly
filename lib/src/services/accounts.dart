import 'dart:io';

import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/stores/accounts.dart';
import 'providers/supabase/accounts.dart';
import 'providers/supabase/storage.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

class AccountsService {
  static AccountsService? _instance;

  static AccountsService get instance {
    _instance ??= AccountsService._();
    return _instance!;
  }

  final AccountSupabase _accountSupabase = AccountSupabase();
  final StorageSupabase _storageSupabase = StorageSupabase();
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  final String _bucketId = AppConstants.bucketAccounts;
  
  final AccountsStore _store = AccountsStore.instance; 

  DateTime? _lastFetch;
  Future<void>? _loadFuture;
  int _sessionGeneration = 0;
  static const Duration _cacheValidity = AppConstants.cacheValidityMedium;

  AccountsService._();

  List<Account> get accounts => _store.accounts;
  bool get isLoading => _store.isLoading;
  bool get hasLoaded => _store.hasLoaded;

  void invalidateCache() {
    _sessionGeneration++;
    _lastFetch = null;
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
    final cacheValid = !forceRefresh &&
        _store.hasLoaded &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < _cacheValidity;

    if (cacheValid) return;
    if (_loadFuture != null) return _loadFuture!;

    final future = _loadAccounts(forceRefresh: forceRefresh);
    _loadFuture = future;
    try {
      await future;
    } finally {
      if (identical(_loadFuture, future)) _loadFuture = null;
    }
  }

  Future<void> _loadAccounts({required bool forceRefresh}) async {
    final generation = _sessionGeneration;
    _store.beginLoading();
    try {
      final accounts = await _fetchAccountsWithSignedUrls(forceRefresh: forceRefresh);
      if (generation != _sessionGeneration) return;
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
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < _cacheValidity;

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
    _lastFetch = DateTime.now();
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
    final generation = _sessionGeneration;
    final created = await _accountSupabase.create(
      account.copyWith(userId: _currentUserId),
    );
    if (created != null) {
      if (generation == _sessionGeneration) _store.addAccount(created);
      return created;
    }
    throw Exception('Failed to create account');
  }

  Future<Account> updateAccount(Account account) async {
    final generation = _sessionGeneration;
    final updated = await _accountSupabase.update(account);
    if (updated != null) {
      if (generation == _sessionGeneration) _store.updateAccount(updated);
      return updated;
    }
    throw Exception('Failed to update account');
  }

  void updateLocalAccount(Account account) {
    _store.updateAccount(account);
  }

  Future<bool> deleteAccount(String accountId) async {
    final generation = _sessionGeneration;
    final deleted = await _accountSupabase.delete(accountId);
    if (deleted) {
      if (generation == _sessionGeneration) _store.removeAccount(accountId);
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

  Account? getAccountById(String id) {
    return _store.getAccountById(id);
  }

  void clearLocalAccounts() {
    _store.clearLocalAccounts();
    invalidateCache();
  }
}