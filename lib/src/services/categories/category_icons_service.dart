import 'dart:convert';

import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/models/category/category_icon.dart';
import 'package:budgly/src/services/cache/cache_controller.dart';
import 'package:budgly/src/services/providers/supabase/storage.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CategoryIconsService {
  static CategoryIconsService? _instance;

  static CategoryIconsService get instance {
    _instance ??= CategoryIconsService._();
    return _instance!;
  }

  final StorageSupabase _storage;
  final CacheController<String> _cache = CacheController<String>(
    ttl: AppConstants.cacheValidityLong,
  );
  static const String _cacheKey = 'category-icons';

  static const String _bucketName = AppConstants.bucketConfig;
  static const String _iconsFileName = AppConstants.categoryIconsFileName;
  static const String _persistentCacheKey = AppConstants.cacheCategoryIcons;

  List<CategoryIcon> _icons = [];

  CategoryIconsService({StorageSupabase? storage})
      : _storage = storage ?? StorageSupabase();

  CategoryIconsService._() : this();

  Future<void> invalidateCache() async {
    _icons = [];
    _cache.invalidate();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_persistentCacheKey);
  }

  Future<List<CategoryIcon>> getIcons() async {
    if (_icons.isNotEmpty && _cache.isFresh(_cacheKey)) {
      return List.unmodifiable(_icons);
    }

    final inFlight = _cache.inFlight(_cacheKey);
    if (inFlight != null) {
      await inFlight;
      return List.unmodifiable(_icons);
    }

    final future = _loadIcons();
    _cache.track(_cacheKey, future);
    try {
      await future;
      return List.unmodifiable(_icons);
    } finally {
      _cache.untrack(_cacheKey, future);
    }
  }

  Future<void> _loadIcons() async {
    final cached = await _getCachedIcons();

    if (cached != null && cached.isNotEmpty) {
      _icons = cached;
      _cache.markFresh(_cacheKey);
      return;
    }

    try {
      final fromSupabase = await _loadIconsFromSupabase();
      if (fromSupabase.isNotEmpty) {
        _icons = fromSupabase;
        _cache.markFresh(_cacheKey);
        await _cacheIcons(_icons);
        return;
      }
      AppLogger.warning(
        'Supabase returned an empty category icon catalogue; using asset fallback.',
      );
    } catch (e) {
      AppLogger.error('Erreur Supabase: $e', e);
    }

    try {
      _icons = await _loadIconsFromAssets();
      if (_icons.isEmpty) {
        throw StateError('Bundled category icon JSON is empty');
      }
      _cache.markFresh(_cacheKey);
      await _cacheIcons(_icons);
    } catch (e) {
      AppLogger.error('Erreur assets: $e', e);
      _icons = [];
    }
  }

  Future<List<CategoryIcon>> _loadIconsFromSupabase() async {
    final response = await _storage.getFileContent(
      bucketId: _bucketName,
      filePath: _iconsFileName,
    );

    final jsonString = utf8.decode(response);
    final List<dynamic> jsonList = json.decode(jsonString);

    return jsonList
        .map((json) => CategoryIcon.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<CategoryIcon>> _loadIconsFromAssets() async {
    final jsonString = await rootBundle.loadString(
      'assets/icons/category_icons.json',
    );

    final List<dynamic> jsonList = json.decode(jsonString);

    return jsonList
        .map((json) => CategoryIcon.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> _cacheIcons(List<CategoryIcon> icons) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _persistentCacheKey,
      json.encode({
        'last_updated': DateTime.now().toIso8601String(),
        'icons': icons.map((i) => i.toJson()).toList(),
      }),
    );
  }

  Future<List<CategoryIcon>?> _getCachedIcons() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_persistentCacheKey);
      if (cached == null) return null;

      final data = json.decode(cached) as Map<String, dynamic>;
      final lastUpdated = DateTime.parse(data['last_updated'] as String);
      if (DateTime.now().difference(lastUpdated) >
          AppConstants.cacheValidityLong) {
        return null;
      }

      final iconsJson = data['icons'] as List<dynamic>;
      return iconsJson
          .map((json) => CategoryIcon.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.error('Erreur lecture cache: $e', e);
      return null;
    }
  }

  Future<void> refreshCache() async {
    await invalidateCache();
    await getIcons();
  }

  Future<CategoryIcon?> getIconByCode(String iconCode) async {
    if (iconCode.isEmpty) return null;
    if (_icons.isEmpty) await getIcons();

    final code = int.tryParse(iconCode);
    if (code == null) return null;

    for (final icon in _icons) {
      if (icon.iconCode == code) return icon;
    }
    return null;
  }
}
