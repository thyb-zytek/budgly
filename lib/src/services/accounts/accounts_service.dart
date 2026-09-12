import 'dart:io';
import 'dart:async';

import 'package:budgly/src/core/async/in_flight_registry.dart';
import 'package:budgly/src/core/async/refresh_throttle.dart';
import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/stores/accounts.dart';
import 'package:budgly/src/services/providers/supabase/accounts.dart';
import 'package:budgly/src/services/providers/supabase/storage.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:budgly/src/services/offline/local_cache.dart';
import 'package:budgly/src/services/offline/offline_id.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';

class AccountsService {
  static AccountsService? _instance;

  static AccountsService get instance {
    _instance ??= AccountsService._();
    return _instance!;
  }

  final AccountSupabase _accountSupabase;
  final StorageSupabase _storageSupabase;
  final fb.FirebaseAuth? _authInput;
  fb.FirebaseAuth get _auth => _authInput ?? fb.FirebaseAuth.instance;
  final String _bucketId = AppConstants.bucketAccounts;

  final _inFlight = InFlightRegistry<String>();
  final _refreshThrottle = RefreshThrottle<String>(const Duration(minutes: 1));

  final AccountsStore _store;
  final LocalCache _localCache = LocalCache();
  final SyncQueue _syncQueue = SyncQueue.instance;
  String? _loadedUserId;

  AccountsService({
    AccountSupabase? accountSupabase,
    StorageSupabase? storageSupabase,
    fb.FirebaseAuth? auth,
    AccountsStore? store,
  }) : _accountSupabase = accountSupabase ?? AccountSupabase(),
       _storageSupabase = storageSupabase ?? StorageSupabase(),
       _authInput = auth,
       _store = store ?? AccountsStore.instance {
    SyncManager.instance.registerHandler('accounts', _handlePendingSync);
  }

  AccountsService._() : this();

  Listenable get changeNotifier => _store;
  List<Account> get accounts => _store.accounts;
  bool get hasLoaded => _store.hasLoaded;

  void invalidateCache() {
    _inFlight.clear();
    _refreshThrottle.clear();
  }

  String get _currentUserId {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }
    return user.uid;
  }

  Future<void> loadAccounts({bool forceRefresh = false}) async {
    final userId = _currentUserId;
    if (_loadedUserId != null && _loadedUserId != userId) {
      _inFlight.clear();
      _refreshThrottle.clear();
      _store.clearLocalAccounts();
    }
    _loadedUserId = userId;

    final existing = _inFlight.peek<void>(userId);
    if (existing != null) return existing;

    final cached = await _localCache.loadAccounts(userId);
    final hasCache = cached != null;
    if (hasCache && !_store.hasLoaded) {
      _store.setAccounts(cached);
    }

    if (!_refreshThrottle.isDue(userId, forceRefresh: forceRefresh)) return;

    final future = _refreshAccountsFromRemote(userId);
    _inFlight.register(userId, future);
    if (!forceRefresh && hasCache) {
      unawaited(future);
      return;
    }
    try {
      await future;
    } finally {
      _inFlight.release(userId, future);
    }
  }

  Future<void> _refreshAccountsFromRemote(String userId) async {
    if (await _syncQueue.hasPending(type: 'accounts')) return;
    try {
      // Account data and signed image URLs have different lifetimes. Persist
      // the durable account data immediately; URLs are short-lived
      // presentation data and are refreshed independently.
      final accounts = await _accountSupabase.listByUserId(userId);
      if (_auth.currentUser?.uid != userId) return;

      _store.setAccounts(accounts);
      await _localCache.saveAccounts(userId, accounts);
      _refreshThrottle.markRefreshed(userId);

      unawaited(_refreshPictureUrls(accounts, userId));
    } catch (e, stackTrace) {
      AnalyticsService.instance.track('account_load_failed', {
        'error': e.toString(),
      });
      AppLogger.error('Failed to refresh accounts from remote', e, stackTrace);
    }
  }

  Future<void> _refreshPictureUrls(
    List<Account> accounts,
    String userId,
  ) async {
    if (_auth.currentUser?.uid != userId) return;
    final withUrls = await _withSignedUrls(accounts);
    if (_auth.currentUser?.uid != userId) return;

    for (final account in withUrls) {
      if (account.pictureUrl != null) {
        _store.updateAccount(account);
      }
    }
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
          } catch (e, stackTrace) {
            AppLogger.error(
              'Failed to resolve signed picture URL',
              e,
              stackTrace,
            );
            return account;
          }
        }
        return account;
      }),
    );
  }

  Future<Account> createAccount(Account account) async {
    final optimistic =
        (account.id == null ? account.copyWith(id: OfflineId.uuid()) : account)
            .copyWith(userId: _currentUserId);

    _store.addAccount(optimistic);
    await _localCache.saveAccounts(_currentUserId, _store.accounts);
    AnalyticsService.instance.track('account_created');

    await _queueAndFlush(
      id: 'account:${optimistic.id}',
      operation: 'create',
      payload: optimistic.toJson(),
    );
    return optimistic;
  }

  Future<Account> updateAccount(Account account) async {
    final optimistic = account.copyWith(userId: _currentUserId);
    _store.updateAccount(optimistic);
    await _localCache.saveAccounts(_currentUserId, _store.accounts);
    AnalyticsService.instance.track('account_updated');

    await _queueAndFlush(
      id: 'account:update:${account.id}',
      operation: 'update',
      payload: optimistic.toJson(),
    );
    return optimistic;
  }

  void updateLocalAccount(Account account) => _store.updateAccount(account);

  Future<bool> deleteAccount(String accountId) async {
    _store.removeAccount(accountId);
    await _localCache.clearAccount(accountId);
    await _localCache.saveAccounts(_currentUserId, _store.accounts);

    await _syncQueue.removeWhere(
      (operation) =>
          (operation.type == 'categories' &&
              operation.payload['account_id']?.toString() == accountId) ||
          (operation.type == 'expenses' &&
              operation.payload['accountId']?.toString() == accountId),
    );
    await _queueAndFlush(
      id: 'account:delete:$accountId',
      operation: 'delete',
      payload: {'id': accountId},
    );
    AnalyticsService.instance.track('account_deleted');
    return true;
  }

  Future<void> _queueAndFlush({
    required String id,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    try {
      await _syncQueue.enqueue(
        id: id,
        type: 'accounts',
        operation: operation,
        payload: payload,
      );
      unawaited(SyncManager.instance.flush());
    } catch (e, st) {
      // The local mutation remains visible; keep diagnostics for a rare
      // persistence failure in the queue itself.
      AppLogger.error('Failed to persist account sync operation', e, st);
    }
  }

  Future<void> _handlePendingSync(PendingSync operation) async {
    switch (operation.operation) {
      case 'create':
        final account = Account.fromJson(operation.payload);
        await _accountSupabase
            .create(account)
            .timeout(AppConstants.networkTimeout);
        await _uploadQueuedPicture(operation, account);
        return;
      case 'update':
        final account = Account.fromJson(operation.payload);
        final updated = await _accountSupabase
            .update(account)
            .timeout(AppConstants.networkTimeout);
        if (updated == null) {
          final recreated = await _accountSupabase
              .create(account)
              .timeout(AppConstants.networkTimeout);
          if (recreated == null) {
            throw StateError('Failed to recreate account');
          }
        }
        await _uploadQueuedPicture(operation, account);
        return;
      case 'delete':
        await _accountSupabase
            .delete(operation.payload['id'] as String)
            .timeout(AppConstants.networkTimeout);
        return;
      default:
        throw StateError(
          'Unknown account sync operation: ${operation.operation}',
        );
    }
  }

  Future<void> _uploadQueuedPicture(
    PendingSync operation,
    Account account,
  ) async {
    final localPicturePath =
        operation.payload['_local_picture_path'] as String?;
    if (localPicturePath == null ||
        account.id == null ||
        account.picture == null) {
      return;
    }
    await uploadPicture(
      File(localPicturePath),
      account.id!,
      account.picture!,
    );
    final pictureUrl = await getSignedUrl(account.picture!, account.id!);
    if (pictureUrl == null) return;
    final updated = account.copyWith(pictureUrl: pictureUrl);
    _store.updateAccount(updated);
    await _localCache.saveAccounts(_currentUserId, _store.accounts);
  }

  Future<void> queuePictureUpload(Account account, File file) {
    if (account.id == null || account.picture == null) return Future.value();
    return _queueAndFlush(
      id: 'account:image:${account.id}',
      operation: 'update',
      payload: {...account.toJson(), '_local_picture_path': file.path},
    );
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
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to get signed URL for account picture',
        e,
        stackTrace,
      );
      return null;
    }
  }

  Future<bool> deletePicture(String path, String accountId) async {
    final fullPath = '$_currentUserId/$accountId/$path';
    return _storageSupabase.deleteFile(bucketId: _bucketId, filePath: fullPath);
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
    _inFlight.clear();
    _refreshThrottle.clear();
    _loadedUserId = null;
    _store.clearLocalAccounts();
  }
}
