import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers.dart';

/// RL-01 §1.3 — the local preference mirror is a per-uid cache of
/// `UserProfile`'s preference fields, never an independent/global source of
/// truth, so it must not leak between accounts sharing a device.
void main() {
  late ProfileService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = ProfileService(
      analytics: AnalyticsService(),
      syncManager: testSyncManager,
      syncQueue: testSyncQueue,
    );
  });

  test(
    'no signed-in uid returns system defaults, never a stale cached value',
    () async {
      await service.cacheLocalPreferences(
        'previous-user',
        themeMode: ThemeMode.dark,
        locale: const Locale('en'),
        currency: 'USD',
        amountDecimalPlaces: 0,
      );

      final prefs = await service.loadLocalPreferences(uid: null);

      expect(prefs.themeMode, ThemeMode.system);
      expect(prefs.locale.languageCode, 'fr');
      expect(prefs.currency, 'EUR');
      expect(prefs.amountDecimalPlaces, 2);
    },
  );

  test(
    'a user with no cached preferences yet gets defaults, not another user\'s',
    () async {
      await service.cacheLocalPreferences(
        'user-a',
        themeMode: ThemeMode.dark,
        locale: const Locale('en'),
        currency: 'USD',
        amountDecimalPlaces: 0,
      );

      final prefsForB = await service.loadLocalPreferences(uid: 'user-b');

      expect(prefsForB.themeMode, ThemeMode.system);
      expect(prefsForB.locale.languageCode, 'fr');
      expect(prefsForB.currency, 'EUR');
    },
  );

  test(
    'cacheLocalPreferences then loadLocalPreferences round-trips for that uid',
    () async {
      await service.cacheLocalPreferences(
        'user-a',
        themeMode: ThemeMode.dark,
        locale: const Locale('en'),
        currency: 'USD',
        amountDecimalPlaces: 0,
      );

      final prefs = await service.loadLocalPreferences(uid: 'user-a');

      expect(prefs.themeMode, ThemeMode.dark);
      expect(prefs.locale.languageCode, 'en');
      expect(prefs.currency, 'USD');
      expect(prefs.amountDecimalPlaces, 0);
    },
  );

  test(
    'two users sharing a device keep independent cached preferences',
    () async {
      await service.cacheLocalPreferences(
        'user-a',
        themeMode: ThemeMode.dark,
        locale: const Locale('en'),
        currency: 'USD',
        amountDecimalPlaces: 0,
      );
      await service.cacheLocalPreferences(
        'user-b',
        themeMode: ThemeMode.light,
        locale: const Locale('fr'),
        currency: 'EUR',
        amountDecimalPlaces: 2,
      );

      final prefsA = await service.loadLocalPreferences(uid: 'user-a');
      final prefsB = await service.loadLocalPreferences(uid: 'user-b');

      expect(prefsA.themeMode, ThemeMode.dark);
      expect(prefsA.currency, 'USD');
      expect(prefsB.themeMode, ThemeMode.light);
      expect(prefsB.currency, 'EUR');
    },
  );
}
