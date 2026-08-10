import 'dart:io';

import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/models/account/account.dart';
import 'supabase/account_supabase.dart';
import 'supabase/storage_supabase.dart';
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

  List<Account> _accounts = [];
  DateTime? _lastFetch;

  static const Duration _cacheValidity = AppConstants.cacheValidityMedium;

  AccountsService._();

  void invalidateCache() {
    // Reassign to a fresh list instead of clearing in place: any list
    // previously handed out by listAccounts()/listAccountsWithSignedUrls()
    // (or callers of this class) must stay untouched by this reset.
    _accounts = [];
    _lastFetch = null;
  }

  String get _currentUserId {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }
    return user.uid;
  }

  Future<List<Account>> listAccountsWithSignedUrls() async {
    if (_accounts.isNotEmpty &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < _cacheValidity) {
      // If accounts are cached but don't have signed URLs, load them
      if (_accounts.any((acc) => acc.picture != null && acc.pictureUrl == null)) {
        return await _loadSignedUrlsForCachedAccounts();
      }
      // Never hand out the internal cache list by reference: callers
      // (e.g. AccountsStore) would end up aliasing it, and any later
      // in-place mutation here (invalidateCache, delete, ...) would
      // silently wipe out their own list too.
      return List<Account>.from(_accounts);
    }

    final userId = _currentUserId;
    final rows = await _accountSupabase.listByUserId(userId);
    final freshAccounts = await Future.wait(
      rows.map((account) async {
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

    _accounts
      ..clear()
      ..addAll(freshAccounts);
    _lastFetch = DateTime.now();
    return List<Account>.from(_accounts);
  }

  Future<List<Account>> _loadSignedUrlsForCachedAccounts() async {
    final userId = _currentUserId;
    final accountsWithUrls = await Future.wait(
      _accounts.map((account) async {
        if (account.picture != null && account.id != null && account.pictureUrl == null) {
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

    _accounts
      ..clear()
      ..addAll(accountsWithUrls);
    return List<Account>.from(_accounts);
  }

  Future<List<Account>> listAccounts() async {
    _accounts = await _accountSupabase.listByUserId(_currentUserId);
    return List<Account>.from(_accounts);
  }

  Future<Account> getAccountDetails(String accountId) async {
    return _accounts.firstWhere(
      (account) => account.id == accountId && account.userId == _currentUserId,
    );
  }

  Future<Account> createAccount(Account account) async {
    final created = await _accountSupabase.create(
      account.copyWith(userId: _currentUserId),
    );
    if (created != null) {
      _accounts.add(created);
      return created;
    }
    throw Exception('Failed to create account');
  }

  Future<Account> updateAccount(Account account) async {
    final updated = await _accountSupabase.update(account);
    if (updated != null) {
      _accounts =
          _accounts.map((acc) => acc.id == account.id ? updated : acc).toList();
      return updated;
    }
    throw Exception('Failed to update account');
  }

  Future<bool> deleteAccount(String accountId) async {
    final deleted = await _accountSupabase.delete(accountId);
    if (deleted) {
      _accounts.removeWhere((account) => account.id == accountId);
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
      return _storageSupabase.getSignedUrl(
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
}