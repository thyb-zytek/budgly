import 'dart:async';

import 'package:budgly/src/core/async/in_flight_registry.dart';
import 'package:budgly/src/core/async/refresh_throttle.dart';
import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/category/category_icon.dart';
import 'package:budgly/src/services/categories/category_icons_service.dart';
import 'package:budgly/src/services/providers/supabase/categories.dart';
import 'package:budgly/src/services/offline/local_cache.dart';
import 'package:budgly/src/services/offline/offline_id.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';

class CategoriesService {
  final CategorySupabase _categorySupabase;
  final CategoryIconsService _categoryIconsService;
  final LocalCache _localCache;
  final SyncQueue _syncQueue;
  final AnalyticsService _analytics;
  final SyncManager _syncManager;

  final _inFlight = InFlightRegistry<String>();
  final _refreshThrottle = RefreshThrottle<String>(const Duration(minutes: 1));

  CategoriesService({
    CategorySupabase? categorySupabase,
    CategoryIconsService? categoryIconsService,
    required this._analytics,
    required this._syncManager,
    required this._syncQueue,
    LocalCache? localCache,
  }) : _categorySupabase = categorySupabase ?? CategorySupabase(),
       _categoryIconsService = categoryIconsService ?? CategoryIconsService(),
       // Production always injects the shared instance (localCacheProvider);
       // the fallback only exists for tests that build the service directly.
       _localCache = localCache ?? LocalCache();

  void registerSyncHandler(SyncManager manager) {
    manager.registerHandler('categories', _handlePendingSync);
  }

  void invalidateCache() {
    _inFlight.clear();
    _refreshThrottle.clear();
  }

  void invalidateAccountCache(String accountId) {
    _inFlight.remove(accountId);
    _refreshThrottle.remove(accountId);
  }

  Future<List<CategoryIcon>> loadAvailableIcons() async {
    return _categoryIconsService.getIcons();
  }

  Category _hydrateCategoryIcon(Category category, List<CategoryIcon> icons) {
    if (category.icon != null) return category;

    final rawIconCode = category.iconCode ?? '0';
    final iconCode = rawIconCode.toLowerCase().startsWith('0x')
        ? int.tryParse(rawIconCode.substring(2), radix: 16) ?? 0
        : int.tryParse(rawIconCode) ?? 0;

    if (iconCode != 0) {
      for (final icon in icons) {
        if (icon.iconCode == iconCode) {
          return category.copyWith(icon: icon);
        }
      }
    }

    // Icône inconnue ou absente : on attache l'icône par défaut uniquement
    // pour l'affichage, en conservant l'iconCode d'origine pour que la
    // réhydratation puisse retrouver la vraie icône dès que le catalogue
    // est disponible. Ne jamais réécrire iconCode ici : il est persisté tel
    // quel dans le cache local.
    final fallback = icons.firstWhere(
      (i) => i.iconName == AppConstants.defaultCategoryIcon.iconName,
      orElse: () => AppConstants.defaultCategoryIcon,
    );

    return Category(
      id: category.id,
      name: category.name,
      color: category.color,
      icon: fallback,
      iconCode: category.iconCode,
      accountId: category.accountId,
      monthlyThreshold: category.monthlyThreshold,
    );
  }

  /// Cache-first load (RL-01 §3.2), mirroring `AccountsService.loadAccounts`:
  /// see its doc comment for the [onRevalidated] contract.
  Future<List<Category>> listCategoriesByAccount(
    String accountId, {
    bool forceRefresh = false,
    void Function(List<Category>)? onRevalidated,
  }) async {
    final cached = await _localCache.loadCategories(accountId);
    if (!_refreshThrottle.isDue(accountId, forceRefresh: forceRefresh)) {
      if (cached == null) return const [];
      final icons = await _categoryIconsService.getIcons();
      return cached.map((c) => _hydrateCategoryIcon(c, icons)).toList();
    }
    final existing = _inFlight.peek<List<Category>>(accountId);
    if (existing != null) return existing;
    final future = _refreshCategoriesFromRemote(accountId);
    _inFlight.register(accountId, future);
    if (!forceRefresh && cached != null) {
      // See `AccountsService.loadAccounts`: release the in-flight guard and
      // forward the eventual server result instead of leaking it forever.
      unawaited(
        future
            .then((remote) => onRevalidated?.call(remote), onError: (_) {})
            .whenComplete(() => _inFlight.release(accountId, future)),
      );
      final icons = await _categoryIconsService.getIcons();
      return cached.map((c) => _hydrateCategoryIcon(c, icons)).toList();
    }
    try {
      return await future;
    } finally {
      _inFlight.release(accountId, future);
    }
  }

  Future<List<Category>> _refreshCategoriesFromRemote(String accountId) async {
    try {
      final fresh = await _categorySupabase
          .listByAccountId(accountId)
          .timeout(AppConstants.networkTimeout);
      final icons = await _categoryIconsService.getIcons();
      final hydrated = fresh
          .map((c) => _hydrateCategoryIcon(c, icons))
          .toList(growable: false);
      // Merge pending operations and write the cache in one atomic step, so a
      // mutation cannot interleave and be overwritten by this snapshot.
      final categories = await _localCache.updateCategories(
        accountId,
        (_) async => _mergePendingCategories(
          accountId,
          hydrated,
          await _syncQueue.forType('categories'),
          icons,
        ),
      );
      _refreshThrottle.markRefreshed(accountId);
      return categories ?? hydrated;
    } catch (e, stackTrace) {
      _analytics.track('category_load_failed', {'error': e.toString()});
      AppLogger.error(
        'Failed to refresh categories from remote',
        e,
        stackTrace,
      );
      final cached = await _localCache.loadCategories(accountId);
      if (cached != null) {
        final icons = await _categoryIconsService.getIcons();
        return cached.map((c) => _hydrateCategoryIcon(c, icons)).toList();
      }
      rethrow;
    }
  }

  /// Overlays queued local operations on the [remote] snapshot.
  ///
  /// Pure and synchronous on purpose: it runs while the cache lock is held.
  /// A delete payload may lack the account id, so deletes are matched by the
  /// (globally unique) category id instead of being filtered on payload fields.
  List<Category> _mergePendingCategories(
    String accountId,
    List<Category> remote,
    List<PendingSync> pending,
    List<CategoryIcon> icons,
  ) {
    final byId = <String, Category>{
      for (final category in remote)
        if (category.id != null) category.id!: category,
    };

    for (final operation in pending) {
      final id = operation.entityId;
      if (id.isEmpty) continue;
      switch (operation.operation) {
        case 'create':
        case 'update':
          if (operation.payload['account_id']?.toString() != accountId) {
            continue;
          }
          byId[id] = _hydrateCategoryIcon(
            Category.fromJson(operation.payload),
            icons,
          );
        case 'delete':
          byId.remove(id);
      }
    }

    return byId.values.toList(growable: false);
  }

  // Mutation contract (see docs/ARCHITECTURE.md): the durable queue entry is
  // written first; the cache is a best-effort mirror written afterwards.

  Future<Category> createCategory(Category category) async {
    final optimistic = category.id == null
        ? category.copyWith(id: OfflineId.uuid())
        : category;
    final hydrated = _hydrateCategoryIcon(
      optimistic,
      await _categoryIconsService.getIcons(),
    );

    await _queueAndFlush(
      id: 'category:${hydrated.id}',
      operation: 'create',
      payload: hydrated.toJson(),
    );
    await _mirrorToCache(
      hydrated.accountId,
      (current) => [...?current, hydrated],
    );
    _analytics.track('category_created');
    return hydrated;
  }

  Future<Category> updateCategory(Category category) async {
    final hydrated = _hydrateCategoryIcon(
      category,
      await _categoryIconsService.getIcons(),
    );

    await _queueAndFlush(
      id: 'category:update:${category.id}',
      operation: 'update',
      payload: hydrated.toJson(),
    );
    await _mirrorToCache(
      hydrated.accountId,
      (current) => current == null
          ? null
          : [
              for (final item in current)
                if (item.id == hydrated.id) hydrated else item,
            ],
    );
    _analytics.track('category_updated');
    return hydrated;
  }

  Future<bool> deleteCategory(String categoryId, {String? accountId}) async {
    await _queueAndFlush(
      id: 'category:delete:$categoryId',
      operation: 'delete',
      payload: {'id': categoryId, 'account_id': accountId},
    );
    if (accountId != null) {
      await _mirrorToCache(
        accountId,
        (current) => current
            ?.where((category) => category.id != categoryId)
            .toList(growable: false),
      );
    }
    _analytics.track('category_deleted');
    return true;
  }

  /// Best-effort update of the cache mirror. The durable intent is already in
  /// the queue, so a failure here is logged and never reported as a failed
  /// mutation.
  Future<void> _mirrorToCache(
    String accountId,
    List<Category>? Function(List<Category>? current) transform,
  ) async {
    try {
      await _localCache.updateCategories(accountId, transform);
    } catch (e, st) {
      AppLogger.error('Failed to mirror category change to local cache', e, st);
    }
  }

  /// Persists the mutation in the durable queue and requests a replay. A queue
  /// failure is rethrown so the caller never shows a change that was not
  /// persisted.
  Future<void> _queueAndFlush({
    required String id,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    try {
      await _syncQueue.enqueue(
        id: id,
        type: 'categories',
        operation: operation,
        payload: payload,
      );
    } catch (e, st) {
      AppLogger.error('Failed to persist category sync operation', e, st);
      rethrow;
    }
    unawaited(_syncManager.flush());
  }

  Future<void> _handlePendingSync(PendingSync operation) async {
    switch (operation.operation) {
      case 'create':
        await _categorySupabase
            .create(Category.fromJson(operation.payload))
            .timeout(AppConstants.networkTimeout);
        return;
      case 'update':
        final category = Category.fromJson(operation.payload);
        final updated = await _categorySupabase
            .update(category)
            .timeout(AppConstants.networkTimeout);
        if (updated == null) {
          final recreated = await _categorySupabase
              .create(category)
              .timeout(AppConstants.networkTimeout);
          if (recreated == null) {
            throw StateError('Failed to recreate category');
          }
        }
        return;
      case 'delete':
        final categoryId = operation.payload['id'] as String;
        await _categorySupabase
            .delete(categoryId)
            .timeout(AppConstants.networkTimeout);
        // Durable cleanup of the category's Firestore expenses (see
        // DeletionCleanupService); enqueued once the server delete succeeded.
        await _syncQueue.enqueue(
          id: 'cleanup:category:$categoryId',
          type: 'cleanup',
          operation: 'category',
          payload: {'id': categoryId},
        );
        // See AccountsService._handlePendingSync: schedules a trailing pass
        // instead of waiting for the next periodic trigger.
        unawaited(_syncManager.flush());
        return;
      default:
        throw StateError(
          'Unknown category sync operation: ${operation.operation}',
        );
    }
  }
}
