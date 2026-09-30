import 'dart:io';
import 'dart:async';

import 'package:budgly/src/core/async/in_flight_registry.dart';
import 'package:budgly/src/core/async/refresh_throttle.dart';
import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/services/providers/supabase/accounts.dart';
import 'package:budgly/src/services/providers/supabase/storage.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:budgly/src/services/offline/local_cache.dart';
import 'package:budgly/src/services/offline/offline_id.dart';
import 'package:path_provider/path_provider.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';

class AccountsService {
  final AccountSupabase _accountSupabase;
  final StorageSupabase _storageSupabase;
  final fb.FirebaseAuth? _authInput;
  fb.FirebaseAuth get _auth => _authInput ?? fb.FirebaseAuth.instance;
  final String _bucketId = AppConstants.bucketAccounts;

  final _inFlight = InFlightRegistry<String>();
  final _refreshThrottle = RefreshThrottle<String>(const Duration(minutes: 1));

  final LocalCache _localCache;
  final SyncQueue _syncQueue;
  final AnalyticsService _analytics;
  final SyncManager _syncManager;
  String? _loadedUserId;

  AccountsService({
    AccountSupabase? accountSupabase,
    StorageSupabase? storageSupabase,
    fb.FirebaseAuth? auth,
    required this._analytics,
    required this._syncManager,
    required this._syncQueue,
    LocalCache? localCache,
  }) : _accountSupabase = accountSupabase ?? AccountSupabase(),
       _storageSupabase = storageSupabase ?? StorageSupabase(),
       _authInput = auth,
       // Production always injects the shared instance (localCacheProvider);
       // the fallback only exists for tests that build the service directly.
       _localCache = localCache ?? LocalCache();

  void registerSyncHandler(SyncManager manager) {
    manager.registerHandler('accounts', _handlePendingSync);
  }

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

  /// Cache-first load (RL-01 §3.2). When cached accounts already exist, they
  /// are returned immediately and a background revalidation is kicked off;
  /// [onRevalidated] is called with the server result once that revalidation
  /// completes, so the caller (`AccountsSession`) can push the fresher data
  /// into the reactive session state and let the UI rebuild — the service
  /// itself never touches Riverpod state directly.
  Future<List<Account>> loadAccounts({
    bool forceRefresh = false,
    void Function(List<Account>)? onRevalidated,
  }) async {
    final userId = _currentUserId;
    if (_loadedUserId != null && _loadedUserId != userId) {
      _inFlight.clear();
      _refreshThrottle.clear();
    }
    _loadedUserId = userId;

    final existing = _inFlight.peek<List<Account>>(userId);
    if (existing != null) return existing;

    final cached = await _localCache.loadAccounts(userId);
    final hasCache = cached != null;
    if (!_refreshThrottle.isDue(userId, forceRefresh: forceRefresh)) {
      return cached ?? const [];
    }

    final future = _refreshAccountsFromRemote(userId);
    _inFlight.register(userId, future);
    if (!forceRefresh && hasCache) {
      // Release the in-flight guard and hand the eventual server result to
      // the caller regardless of outcome; a failure is already logged/tracked
      // inside `_refreshAccountsFromRemote` and must not surface as an
      // unhandled async error just because nobody awaits this branch.
      unawaited(
        future
            .then((remote) => onRevalidated?.call(remote), onError: (_) {})
            .whenComplete(() => _inFlight.release(userId, future)),
      );
      return cached;
    }
    try {
      return await future;
    } finally {
      _inFlight.release(userId, future);
    }
  }

  Future<List<Account>> _refreshAccountsFromRemote(String userId) async {
    try {
      final accounts = await _accountSupabase.listByUserId(userId);
      if (_auth.currentUser?.uid != userId) return const [];
      final withUrls = await _withSignedUrls(accounts);
      // Merge pending operations and write the cache in one atomic step, so a
      // mutation cannot interleave and be overwritten by this snapshot.
      final merged = await _localCache.updateAccounts(
        userId,
        (current) async => _mergePendingAccounts(
          userId,
          withUrls,
          await _syncQueue.forType('accounts'),
          current ?? const [],
        ),
      );
      _refreshThrottle.markRefreshed(userId);
      return merged ?? withUrls;
    } catch (e, stackTrace) {
      _analytics.track('account_load_failed', {'error': e.toString()});
      AppLogger.error('Failed to refresh accounts from remote', e, stackTrace);
      return await _localCache.loadAccounts(userId) ?? (throw e);
    }
  }

  /// Overlays queued local operations on the [remote] snapshot.
  ///
  /// Pure and synchronous on purpose: it runs while the cache lock is held.
  /// Ownership comes from [PendingSync.ownerUserId]; a delete payload carries
  /// only the id, so it must never be filtered on payload fields.
  List<Account> _mergePendingAccounts(
    String userId,
    List<Account> remote,
    List<PendingSync> pending,
    List<Account> cached,
  ) {
    final byId = <String, Account>{
      for (final account in remote)
        if (account.id != null) account.id!: account,
    };
    final cachedById = <String, Account>{
      for (final account in cached)
        if (account.id != null) account.id!: account,
    };

    for (final operation in pending) {
      final owner = operation.ownerUserId;
      if (owner != null && owner != userId) continue;
      final id = operation.entityId;
      if (id.isEmpty) continue;
      switch (operation.operation) {
        case 'create':
        case 'update':
          // Legacy ownerless entries are attributed through their payload.
          if (owner == null &&
              operation.payload['user_id']?.toString() != userId) {
            continue;
          }
          var account = Account.fromJson(operation.payload);
          // Keep an already-resolved picture URL for the same picture file
          // instead of resolving it again over the network.
          final known = cachedById[id];
          if (account.pictureUrl == null &&
              known != null &&
              known.picture == account.picture) {
            account = account.copyWith(pictureUrl: known.pictureUrl);
          }
          byId[id] = account;
        case 'delete':
          byId.remove(id);
      }
    }

    return byId.values.toList(growable: false);
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

  // Mutation contract (see docs/ARCHITECTURE.md): the durable queue entry is
  // written *first* and is the source of truth; the local cache is a
  // best-effort mirror written afterwards. A crash between the two therefore
  // loses nothing, and a queue failure is reported to the caller instead of
  // leaving an optimistic change that would silently vanish.

  Future<Account> createAccount(Account account) async {
    final userId = _currentUserId;
    final optimistic =
        (account.id == null ? account.copyWith(id: OfflineId.uuid()) : account)
            .copyWith(userId: userId);

    await _queueAndFlush(
      id: 'account:${optimistic.id}',
      operation: 'create',
      payload: optimistic.toJson(),
    );
    await _mirrorToCache(userId, (current) => [...?current, optimistic]);
    _analytics.track('account_created');
    return optimistic;
  }

  Future<Account> updateAccount(Account account) async {
    final userId = _currentUserId;
    final optimistic = account.copyWith(userId: userId);

    await _queueAndFlush(
      id: 'account:update:${account.id}',
      operation: 'update',
      payload: optimistic.toJson(),
    );
    await _mirrorToCache(
      userId,
      (current) => current == null
          ? null
          : [
              for (final item in current)
                if (item.id == optimistic.id) optimistic else item,
            ],
    );
    _analytics.track('account_updated');
    return optimistic;
  }

  Future<bool> deleteAccount(String accountId) async {
    final userId = _currentUserId;

    // Child mutations are intentionally kept in the queue until the account
    // deletion reaches the server. SyncManager will block them behind a
    // failed account operation, and the delete handler removes them once the
    // parent deletion has succeeded. This avoids losing durable child work
    // during an offline account deletion.
    await _queueAndFlush(
      id: 'account:delete:$accountId',
      operation: 'delete',
      payload: {'id': accountId},
    );
    await _mirrorToCache(
      userId,
      (current) => current
          ?.where((account) => account.id != accountId)
          .toList(growable: false),
    );
    try {
      await _localCache.clearAccount(accountId);
    } catch (e, st) {
      AppLogger.error('Failed to clear cached categories', e, st);
    }
    _analytics.track('account_deleted');
    return true;
  }

  /// Best-effort update of the cache mirror. The durable intent is already in
  /// the queue, so a failure here is logged and never reported as a failed
  /// mutation.
  Future<void> _mirrorToCache(
    String userId,
    List<Account>? Function(List<Account>? current) transform,
  ) async {
    try {
      await _localCache.updateAccounts(userId, transform);
    } catch (e, st) {
      AppLogger.error('Failed to mirror account change to local cache', e, st);
    }
  }

  /// Persists the mutation in the durable queue and requests a replay.
  ///
  /// A queue failure is rethrown: the caller must know the change was not
  /// persisted rather than show an optimistic state that will silently vanish.
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
    } catch (e, st) {
      AppLogger.error('Failed to persist account sync operation', e, st);
      rethrow;
    }
    unawaited(_syncManager.flush());
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
        final accountId = operation.payload['id'] as String;
        await _accountSupabase
            .delete(accountId)
            .timeout(AppConstants.networkTimeout);
        // The account is gone on the server: schedule the durable cleanup of
        // what lives elsewhere (Firestore expenses/budgets, storage folder).
        // Enqueued here, not at tap time, so it never runs while the account
        // could still be restored by a failing delete.
        await _syncQueue.enqueue(
          id: 'cleanup:account:$accountId',
          type: 'cleanup',
          operation: 'account',
          payload: {'id': accountId},
        );
        // Called from inside a running flush pass: this schedules a trailing
        // pass (see SyncManager.flush) instead of waiting for the next
        // periodic trigger, so cleanup starts right away when online.
        unawaited(_syncManager.flush());
        await _syncQueue.removeWhere(
          (pending) =>
              (pending.type == 'categories' &&
                  pending.payload['account_id']?.toString() == accountId) ||
              (pending.type == 'expenses' &&
                  pending.payload['accountId']?.toString() == accountId),
        );
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
    final localName = operation.payload['_local_picture_name'] as String?;
    // Operations queued by older builds stored an absolute path.
    final legacyPath = operation.payload['_local_picture_path'] as String?;
    final fileName =
        localName ?? (legacyPath?.split(Platform.pathSeparator).last);
    if (fileName == null || account.id == null || account.picture == null) {
      return;
    }
    // The account was edited again and now points to another picture (or none):
    // this queued file is superseded and must not be uploaded under a name the
    // account no longer references.
    if (fileName != account.picture) return;

    final file = await _resolveLocalPicture(fileName, legacyPath);
    if (file == null) {
      AppLogger.error(
        'Queued account picture is no longer on disk',
        StateError('Missing local picture $fileName'),
        StackTrace.current,
      );
      return;
    }

    await uploadPicture(file, account.id!, account.picture!);
    final pictureUrl = await getSignedUrl(account.picture!, account.id!);
    if (pictureUrl != null) {
      final updated = account.copyWith(pictureUrl: pictureUrl);
      final userId = operation.ownerUserId ?? _currentUserId;
      await _mirrorToCache(
        userId,
        (current) => current == null
            ? null
            : [
                for (final item in current)
                  if (item.id == updated.id) updated else item,
              ],
      );
    }
    try {
      // The upload is durable now; the private copy is no longer needed.
      await file.delete();
    } catch (_) {}
  }

  /// The documents directory path changes across iOS app updates, so the file
  /// is resolved from its name rather than trusting a stored absolute path.
  Future<File?> _resolveLocalPicture(
    String fileName,
    String? legacyPath,
  ) async {
    final candidates = <File>[];
    try {
      final directory = await getApplicationDocumentsDirectory();
      candidates.add(File('${directory.path}/$fileName'));
    } catch (_) {}
    if (legacyPath != null) candidates.add(File(legacyPath));
    for (final candidate in candidates) {
      if (await candidate.exists()) return candidate;
    }
    return null;
  }

  Future<void> queuePictureUpload(Account account, File file) {
    if (account.id == null || account.picture == null) return Future.value();
    return _queueAndFlush(
      id: 'account:image:${account.id}',
      operation: 'update',
      payload: {
        ...account.toJson(),
        // A name, not an absolute path: see _resolveLocalPicture.
        '_local_picture_name': file.uri.pathSegments.last,
      },
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

  Future<void> deleteAccountFolder(
    String accountId, {
    bool throwOnFailure = false,
  }) async {
    final folderPath = '$_currentUserId/$accountId';
    await _storageSupabase.deleteFolder(
      bucketId: _bucketId,
      folderPath: folderPath,
      throwOnFailure: throwOnFailure,
    );
  }

  void clearLocalAccounts() {
    _inFlight.clear();
    _refreshThrottle.clear();
    _loadedUserId = null;
  }
}
