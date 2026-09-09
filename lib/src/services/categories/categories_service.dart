import 'dart:async';

import 'package:flutter/foundation.dart' hide Category;
import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/category/category_icon.dart';
import 'package:budgly/src/services/categories/category_icons_service.dart';
import 'package:budgly/src/stores/categories.dart';
import 'package:budgly/src/services/providers/supabase/categories.dart';
import 'package:budgly/src/services/offline/local_cache.dart';
import 'package:budgly/src/services/offline/offline_id.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';

class CategoriesService {
  static CategoriesService? _instance;

  static CategoriesService get instance {
    _instance ??= CategoriesService._();
    return _instance!;
  }

  final CategorySupabase _categorySupabase;
  final CategoryIconsService _categoryIconsService;
  final CategoriesStore _store;
  final LocalCache _localCache = LocalCache();
  final SyncQueue _syncQueue = SyncQueue.instance;

  final Map<String, Future<void>> _inFlight = {};
  final Map<String, DateTime> _lastRemoteRefresh = {};
  static const _refreshInterval = Duration(minutes: 1);

  CategoriesService({
    CategorySupabase? categorySupabase,
    CategoryIconsService? categoryIconsService,
    CategoriesStore? store,
  })  : _categorySupabase = categorySupabase ?? CategorySupabase(),
        _categoryIconsService = categoryIconsService ?? CategoryIconsService.instance,
        _store = store ?? CategoriesStore.instance {
    SyncManager.instance.registerHandler('categories', _handlePendingSync);
  }

  CategoriesService._() : this();

  List<CategoryIcon> get availableIcons => _store.availableIcons;
  Map<String, List<Category>> get categoriesByAccount => _store.categoriesByAccount;
  bool hasLoadedAccount(String accountId) => _store.hasLoadedAccount(accountId);
  List<Category> getCategoriesForAccount(String accountId) => _store.getCategoriesForAccount(accountId);

  void addListener(VoidCallback listener) {
    _store.addListener(listener);
  }

  void removeListener(VoidCallback listener) {
    _store.removeListener(listener);
  }

  void invalidateCache() {
    _inFlight.clear();
    _lastRemoteRefresh.clear();
    _store.clearAll();
  }

  void invalidateAccountCache(String accountId) {
    _inFlight.remove(accountId);
    _lastRemoteRefresh.remove(accountId);
    _store.clearAccountCache(accountId);
  }

  Future<void> loadAvailableIcons() async {
    if (_store.iconsLoaded) return;
    final icons = await _categoryIconsService.getIcons();
    _store.setAvailableIcons(icons);
  }

  Category _hydrateCategoryIcon(Category category) {
    if (category.icon != null) return category;

    final rawIconCode = category.iconCode ?? '0';
    final iconCode = rawIconCode.toLowerCase().startsWith('0x')
        ? int.tryParse(rawIconCode.substring(2), radix: 16) ?? 0
        : int.tryParse(rawIconCode) ?? 0;

    if (iconCode != 0) {
      for (final icon in _store.availableIcons) {
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
    final fallback = _store.availableIcons.firstWhere(
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

  Future<List<Category>> listCategoriesByAccount(
    String accountId, {
    bool forceRefresh = false,
  }) async {
    final cached = await _localCache.loadCategories(accountId);
    final hasCache = cached != null;
    if (hasCache && !_store.hasLoadedAccount(accountId)) {
      if (!_store.iconsLoaded) {
        await loadAvailableIcons();
      }
      _store.setCategoriesForAccount(
        accountId,
        cached.map(_hydrateCategoryIcon).toList(),
      );
    }

    final lastRefresh = _lastRemoteRefresh[accountId];
    final refreshNeeded = forceRefresh ||
        lastRefresh == null ||
        DateTime.now().difference(lastRefresh) >= _refreshInterval;
    if (!refreshNeeded) return _store.getCategoriesForAccount(accountId);

    final existing = _inFlight[accountId];
    if (existing != null) {
      if (forceRefresh || !hasCache) await existing;
      return _store.getCategoriesForAccount(accountId);
    }

    final future = _refreshCategoriesFromRemote(accountId);
    _inFlight[accountId] = future;
    if (!forceRefresh && hasCache) {
      unawaited(future);
      return _store.getCategoriesForAccount(accountId);
    }
    try {
      await future;
    } finally {
      if (identical(_inFlight[accountId], future)) _inFlight.remove(accountId);
    }
    return _store.getCategoriesForAccount(accountId);
  }

  Future<List<Category>> _refreshCategoriesFromRemote(
    String accountId,
  ) async {
    if (await _syncQueue.hasPending(type: 'categories')) {
      return _store.getCategoriesForAccount(accountId);
    }
    try {
      // Le catalogue d'icônes doit être disponible avant d'hydrater les
      // catégories, sinon chaque icône inconnue retombe sur le défaut.
      if (!_store.iconsLoaded) {
        await loadAvailableIcons();
      }
      final freshCategories = await _categorySupabase
          .listByAccountId(accountId)
          .timeout(AppConstants.networkTimeout);
      final categoriesWithIcons =
          freshCategories.map(_hydrateCategoryIcon).toList(growable: false);
      _store.setCategoriesForAccount(accountId, categoriesWithIcons);
      await _localCache.saveCategories(accountId, categoriesWithIcons);
      _lastRemoteRefresh[accountId] = DateTime.now();
      return categoriesWithIcons;
    } catch (e, stackTrace) {
      AnalyticsService.instance.track('category_load_failed', {'error': e.toString()});
      AppLogger.error('Failed to refresh categories from remote', e, stackTrace);
      if (_store.hasLoadedAccount(accountId)) {
        return _store.getCategoriesForAccount(accountId);
      }
      rethrow;
    }
  }

  Future<Category> createCategory(Category category) async {
    final optimistic = category.id == null
        ? category.copyWith(id: OfflineId.uuid())
        : category;
    final hydrated = _hydrateCategoryIcon(optimistic);
    _store.addCategory(hydrated);
    await _localCache.saveCategories(
      hydrated.accountId,
      _store.getCategoriesForAccount(hydrated.accountId),
    );
    AnalyticsService.instance.track('category_created');

    await _queueAndFlush(
      id: 'category:${hydrated.id}',
      operation: 'create',
      payload: hydrated.toJson(),
    );
    return hydrated;
  }

  Future<Category> updateCategory(Category category) async {
    final hydrated = _hydrateCategoryIcon(category);
    _store.updateCategory(hydrated);
    await _localCache.saveCategories(
      hydrated.accountId,
      _store.getCategoriesForAccount(hydrated.accountId),
    );
    AnalyticsService.instance.track('category_updated');

    await _queueAndFlush(
      id: 'category:update:${category.id}',
      operation: 'update',
      payload: hydrated.toJson(),
    );
    return hydrated;
  }

  Future<bool> deleteCategory(String categoryId) async {
    final category = _store.getCategoryById(categoryId);
    _store.removeCategory(categoryId);
    if (category != null) {
      await _localCache.saveCategories(
        category.accountId,
        _store.getCategoriesForAccount(category.accountId),
      );
    }

    await _queueAndFlush(
      id: 'category:delete:$categoryId',
      operation: 'delete',
      payload: {
        'id': categoryId,
        'account_id': category?.accountId,
      },
    );
    AnalyticsService.instance.track('category_deleted');
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
        type: 'categories',
        operation: operation,
        payload: payload,
      );
      unawaited(SyncManager.instance.flush());
    } catch (e, st) {
      AppLogger.error('Failed to persist category sync operation', e, st);
    }
  }

  Future<void> _handlePendingSync(PendingSync operation) async {
    switch (operation.operation) {
      case 'create':
        await _categorySupabase.create(Category.fromJson(operation.payload)).timeout(AppConstants.networkTimeout);
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
        await _categorySupabase.delete(operation.payload['id'] as String).timeout(AppConstants.networkTimeout);
        return;
      default:
        throw StateError(
          'Unknown category sync operation: ${operation.operation}',
        );
    }
  }

  Category? getCategoryById(String categoryId) {
    final category = _store.getCategoryById(categoryId);
    return category != null ? _hydrateCategoryIcon(category) : null;
  }
}
