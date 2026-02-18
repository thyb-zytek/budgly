import 'dart:convert';

import 'package:app/src/models/category/category_icon.dart';
import 'package:app/src/services/supabase.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CategoryIconsService {
  static CategoryIconsService? _instance;

  static CategoryIconsService get instance {
    _instance ??= CategoryIconsService._();
    return _instance!;
  }

  CategoryIconsService._();

  final SupabaseService _service = SupabaseService();

  static const String _bucketName = 'config-files';
  static const String _iconsFileName = 'category_icons.json';
  static const String _cacheKey = 'cached_category_icons';
  static const Duration _cacheValidity = Duration(days: 1);

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
      print('Erreur Supabase: $e');
    }

    try {
      final fromAssets = await _loadIconsFromAssets();
      _icons = fromAssets;
      _lastFetch = DateTime.now();
      return List.unmodifiable(_icons);
    } catch (e) {
      print('Erreur assets: $e');
    }

    return [];
  }

  Future<List<CategoryIcon>> _loadIconsFromSupabase() async {
    final response = await _service.getFileContent(
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
      print('Erreur lecture cache: $e');
      return null;
    }
  }

  Future<void> refreshCache() async {
    await invalidateCache();
    await getIcons();
  }
}
