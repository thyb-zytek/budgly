import 'dart:convert';

import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/models/category/category_icon.dart';
import 'package:budgly/src/services/supabase/storage_supabase.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CategoryIconsService {
  static CategoryIconsService? _instance;

  static CategoryIconsService get instance {
    _instance ??= CategoryIconsService._();
    return _instance!;
  }

  CategoryIconsService._();

  final StorageSupabase _storage = StorageSupabase();

  static const String _bucketName = AppConstants.bucketConfig;
  static const String _iconsFileName = AppConstants.categoryIconsFileName;
  static const String _cacheKey = AppConstants.cacheCategoryIcons;
  static const Duration _cacheValidity = AppConstants.cacheValidityLong;

  List<CategoryIcon> _icons = [];
  DateTime? _lastFetch;

  Future<void> invalidateCache() async {
    _icons.clear();
    _lastFetch = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
  }

  Future<List<CategoryIcon>> getIcons() async {
    if (_icons.isNotEmpty &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < _cacheValidity) {
      return List.unmodifiable(_icons);
    }

    final cached = await _getCachedIcons();
    if (cached != null) {
      _icons = cached;
      return List.unmodifiable(_icons);
    }

    try {
      final fromSupabase = await _loadIconsFromSupabase();
      if (fromSupabase.isNotEmpty) {
        _icons = fromSupabase;
        _lastFetch = DateTime.now();
        await _cacheIcons(_icons);
        return List.unmodifiable(_icons);
      }
    } catch (e) {
      AppLogger.error('Erreur Supabase: $e', e);
    }

    try {
      final fromAssets = await _loadIconsFromAssets();
      _icons = fromAssets;
      _lastFetch = DateTime.now();
      return List.unmodifiable(_icons);
    } catch (e) {
      AppLogger.error('Erreur assets: $e', e);
    }

    return [];
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
    final cacheData = {
      'last_updated': DateTime.now().toIso8601String(),
      'icons': icons.map((i) => i.toJson()).toList(),
    };

    await prefs.setString(_cacheKey, json.encode(cacheData));
  }

  Future<List<CategoryIcon>?> _getCachedIcons() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached == null) return null;

      final data = json.decode(cached) as Map<String, dynamic>;
      final lastUpdated = DateTime.parse(data['last_updated']);

      if (DateTime.now().difference(lastUpdated) > _cacheValidity) {
        return null;
      }

      final List<dynamic> iconsJson = data['icons'];
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
    if (_icons.isEmpty) {
      await getIcons();
    }

    try {
      return _icons.firstWhere((icon) => icon.iconCode == int.parse(iconCode));
    } catch (e) {
      return null;
    }
  }
}
