import 'dart:async';
import 'dart:convert';

import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/models/category/category_icon.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Loads the bundled category icon catalogue.
///
/// The catalogue is part of the application assets, so it is always available
/// offline and does not require a remote request before a category can be
/// displayed or edited.
class CategoryIconsService {
  static final CategoryIconsService instance = CategoryIconsService();

  CategoryIconsService({AssetBundle? assetBundle})
      : _assetBundle = assetBundle ?? rootBundle;

  final AssetBundle _assetBundle;

  List<CategoryIcon> _icons = const [];
  Future<void>? _loadFuture;

  Future<List<CategoryIcon>> getIcons() async {
    if (_icons.isNotEmpty) return List.unmodifiable(_icons);

    final inFlight = _loadFuture;
    if (inFlight != null) {
      await inFlight;
      return List.unmodifiable(_icons);
    }

    final future = _loadFromAssets();
    _loadFuture = future;
    try {
      await future;
    } finally {
      if (identical(_loadFuture, future)) _loadFuture = null;
    }
    return List.unmodifiable(_icons);
  }

  Future<void> _loadFromAssets() async {
    try {
      final jsonString = await _assetBundle.loadString(
        'assets/icons/category_icons.json',
      );
      final jsonList = json.decode(jsonString) as List<dynamic>;
      _icons = jsonList
          .map((item) => CategoryIcon.fromJson(item as Map<String, dynamic>))
          .toList(growable: false);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load category icons', e, stackTrace);
      _icons = const [];
    }
  }

  /// Clears the cached catalogue so the next [getIcons] reloads from assets.
  @visibleForTesting
  void resetForTest() {
    _icons = const [];
    _loadFuture = null;
  }
}
