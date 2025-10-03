import 'dart:io';
import 'package:app/src/models/account/account.dart';
import 'package:app/src/services/supabase.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

class AccountsService {
  // Singleton pattern
  static AccountsService? _instance;

  static AccountsService get instance {
    _instance ??= AccountsService._();
    return _instance!;
  }

  final SupabaseService _supabaseService = SupabaseService();
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  final String _bucketId = 'accounts-pictures';

  List<Account> _accounts = [];
  DateTime? _lastFetch;

  static const Duration _cacheValidity = Duration(minutes: 50);

  // Private constructor
  AccountsService._();

  // Invalidate internal cache to force fresh fetch on next list call
  void invalidateCache() {
    _accounts.clear();
    _lastFetch = null;
  }

  String get _currentUserId {
    if (_auth.currentUser == null) _auth.currentUser!.reload();
    return _auth.currentUser!.uid;
  }
  Future<List<Account>> listAccountsWithSignedUrls() async {
    if (_accounts.isNotEmpty &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < _cacheValidity) {
      return _accounts;
    }

    final freshAccounts = await _supabaseService.listAccountsWithSignedUrls(
      _currentUserId,
      _bucketId,
      (account) => '$_currentUserId/${account.id}/${account.picture}'
    );

    _accounts.clear();
    _accounts.addAll(freshAccounts);
    _lastFetch = DateTime.now();

    return _accounts;
  }

  Future<List<Account>> listAccounts() async {
    _accounts = await _supabaseService.getUserAccounts(_currentUserId);
    return _accounts;
  }

  Future<Account> getAccountDetails(String accountId) async {
    return _accounts.firstWhere(
      (account) => account.id == accountId && account.userId == _currentUserId,
    );
  }

  Future<Account> createAccount(Account account) async {
    final created = await _supabaseService.createAccount(account.copyWith(userId: _currentUserId));
    if (created != null) {
      _accounts.add(created);
      return created;
    } else {
      throw Exception('Failed to create account');
    }
  }

  Future<Account> updateAccount(Account account) async {
  
    final updated = await _supabaseService.updateAccount(account);
    if (updated != null) {
      _accounts =
          _accounts
              .map((acc) => acc.id == account.id ? updated : acc)
              .toList();
      return updated;
    } else {
      throw Exception('Failed to update account');
    }
  }

  Future<bool> deleteAccount(String accountId) async {
    bool deleted = await _supabaseService.deleteAccount(accountId);
    if (deleted) {
      _accounts.removeWhere((account) => account.id == accountId);
      return deleted;
    } else {
      throw Exception('Failed to delete account');
    }
  }

  Future<String?> uploadPicture(
    File file,
    String accountId,
    String fileName,
  ) async {
    return _supabaseService.uploadFile(
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
      return _supabaseService.getSignedUrl(
        bucketId: _bucketId,
        filePath: fullPath,
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> deletePicture(String path, String accountId) async {
    final fullPath = '$_currentUserId/$accountId/$path';
    return _supabaseService.deleteFile(
      bucketId: _bucketId,
      filePath: fullPath,
    );
  }
}
