import 'package:budgly/src/models/user/user.dart';
import 'package:budgly/src/models/user/user_profile.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/offline/local_cache.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';

/// Direct coverage of `ProfileService`'s three mutation methods
/// (`updateUserName`/`savePreferences`/`completeOnboarding`), which the
/// original audit only exercised indirectly (docs/AUDIT_PLAN.md, D3/S1).
///
/// The central regression here is P0-3: finishing onboarding then changing a
/// preference while offline used to lose the first patch, because
/// `SyncQueue.enqueue` replaced the previous payload outright instead of
/// merging it. That fix already has a unit test at the `SyncQueue` level
/// (`sync_queue_merge_and_recovery_test.dart`); this file checks the same
/// scenario through the real `ProfileService` call sequence a user actually
/// triggers, not just the queue primitive.

/// A queue whose storage is unavailable.
class _BrokenQueue extends SyncQueue {
  @override
  Future<void> enqueue({
    required String id,
    required String type,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    throw StateError('queue storage unavailable');
  }
}

void main() {
  late LocalCache cache;

  UserProfile profile({
    String id = 'user-a',
    bool onboardingCompleted = false,
    String themeMode = 'system',
    String currency = 'EUR',
  }) => UserProfile(
    id: id,
    email: 'a@budgly.app',
    fullName: 'Alice',
    onboardingCompleted: onboardingCompleted,
    themeMode: themeMode,
    currency: currency,
  );

  User user(UserProfile profile) => User(id: profile.id, profile: profile);

  ProfileService service({SyncQueue? queue}) => ProfileService(
    analytics: AnalyticsService(),
    syncManager: testSyncManager,
    syncQueue: queue ?? testSyncQueue,
  );

  setUp(() {
    cache = LocalCache();
  });

  group('updateUserName', () {
    test(
      'the durable queue entry exists as soon as the call returns',
      () async {
        final svc = service();
        await svc.updateUserName(user(profile()), 'Alicia');

        final operations = await testSyncQueue.forType('user_profiles');
        expect(operations.single.payload['full_name'], 'Alicia');
        expect(operations.single.payload['id'], 'user-a');
      },
    );

    test('mirrors the new name to the local cache', () async {
      final svc = service();
      await svc.updateUserName(user(profile()), 'Alicia');

      expect((await cache.loadProfile('user-a'))!.fullName, 'Alicia');
    });

    test(
      'a queue failure is reported and the cache is left untouched',
      () async {
        final svc = service(queue: _BrokenQueue());
        await expectLater(
          svc.updateUserName(user(profile()), 'Alicia'),
          throwsStateError,
        );

        expect(await cache.loadProfile('user-a'), isNull);
      },
    );
  });

  group('completeOnboarding then savePreferences while both offline', () {
    test(
      'the later preference patch does not lose the earlier onboarding patch '
      '(regression, docs/AUDIT_PLAN.md P0-3)',
      () async {
        final svc = service();

        final u1 = user(profile());
        final u2 = await svc.completeOnboarding(u1);
        await svc.savePreferences(
          u2,
          themeMode: ThemeMode.dark,
          locale: const Locale('en'),
          currency: 'USD',
          amountDecimalPlaces: 0,
        );

        final operation = (await testSyncQueue.forType('user_profiles')).single;
        expect(operation.payload['onboarding_completed'], isTrue);
        expect(operation.payload['theme_mode'], 'dark');
        expect(operation.payload['currency'], 'USD');

        final cached = await cache.loadProfile('user-a');
        expect(cached!.onboardingCompleted, isTrue);
        expect(cached.currency, 'USD');
      },
    );

    test('the reverse order also merges both patches', () async {
      final svc = service();

      final u1 = user(profile());
      final u2 = await svc.savePreferences(
        u1,
        themeMode: ThemeMode.dark,
        locale: const Locale('en'),
        currency: 'USD',
        amountDecimalPlaces: 0,
      );
      await svc.completeOnboarding(u2);

      final operation = (await testSyncQueue.forType('user_profiles')).single;
      expect(operation.payload['onboarding_completed'], isTrue);
      expect(operation.payload['currency'], 'USD');
    });
  });

  group('completeOnboarding', () {
    test('is a no-op once already completed', () async {
      final svc = service();
      final already = user(profile(onboardingCompleted: true));

      final result = await svc.completeOnboarding(already);

      expect(result, same(already));
      expect(await testSyncQueue.forType('user_profiles'), isEmpty);
    });

    test(
      'a queue failure is reported and the cache is left untouched',
      () async {
        final svc = service(queue: _BrokenQueue());
        await expectLater(
          svc.completeOnboarding(user(profile())),
          throwsStateError,
        );

        expect(await cache.loadProfile('user-a'), isNull);
      },
    );
  });

  group('savePreferences', () {
    test(
      'mirrors both the profile cache and the local preferences cache',
      () async {
        final svc = service();
        await svc.savePreferences(
          user(profile()),
          themeMode: ThemeMode.dark,
          locale: const Locale('en'),
          currency: 'USD',
          amountDecimalPlaces: 0,
        );

        expect((await cache.loadProfile('user-a'))!.currency, 'USD');
        final local = await svc.loadLocalPreferences(uid: 'user-a');
        expect(local.currency, 'USD');
        expect(local.themeMode, ThemeMode.dark);
      },
    );
  });
}
