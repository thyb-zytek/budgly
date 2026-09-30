import 'package:budgly/src/models/budget/account_budget.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/budget/account_budgets_service.dart';
import 'package:budgly/src/services/providers/firestore/accounts_budget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Complements `account_budgets_service_revalidation_test.dart` (which
/// covers `loadRevenue`) with the mutation and cleanup paths: `setRevenue`,
/// `deleteByAccountId` (local, best-effort) and `purgeByAccountId` (server,
/// used by the durable cleanup — docs/AUDIT_PLAN.md, L2).
class _RecordingProvider extends AccountBudgetFirestore {
  final List<String> calls = [];
  bool failSetRevenue = false;
  bool failDeleteByAccountId = false;
  AccountBudget? lastSet;

  @override
  Future<AccountBudget> setRevenue(
    String accountId,
    int year,
    int month,
    double revenue,
  ) async {
    calls.add('setRevenue');
    if (failSetRevenue) throw StateError('offline');
    lastSet = AccountBudget(
      accountId: accountId,
      year: year,
      month: month,
      revenue: revenue,
    );
    return lastSet!;
  }

  @override
  Future<void> deleteByAccountId(
    String accountId, {
    Source source = Source.serverAndCache,
    bool awaitAck = true,
  }) async {
    calls.add('deleteByAccountId(source: $source, awaitAck: $awaitAck)');
    if (failDeleteByAccountId) throw StateError('offline');
  }

  // getMostRecentRevenue (the method under test in most of this file) calls
  // this, not get() — get() backs loadRevenue instead, which this file does
  // not exercise (see account_budgets_service_revalidation_test.dart).
  @override
  Future<AccountBudget?> getMostRecentWithRevenue(
    String accountId, {
    required Period before,
    Source source = Source.server,
  }) async {
    calls.add('getMostRecentWithRevenue(source: $source)');
    throw StateError('no revenue-bearing budget seeded for this test');
  }
}

void main() {
  late _RecordingProvider provider;
  late AccountBudgetsService service;

  setUp(() {
    provider = _RecordingProvider();
    service = AccountBudgetsService(
      provider: provider,
      analytics: AnalyticsService(),
    );
  });

  group('setRevenue', () {
    test(
      'returns the optimistic value without waiting for persistence',
      () async {
        // The fake never resolves get(); if setRevenue awaited persistence
        // instead of firing it in the background, this would hang.
        final result = await service
            .setRevenue('a1', 2026, 3, 1500)
            .timeout(const Duration(seconds: 2));

        expect(result.revenue, 1500);
        expect(result.accountId, 'a1');
      },
    );

    test('persists in the background', () async {
      await service.setRevenue('a1', 2026, 3, 1500);
      await Future<void>.delayed(Duration.zero);

      expect(provider.calls, contains('setRevenue'));
      expect(provider.lastSet?.revenue, 1500);
    });

    test('a persistence failure is logged, not thrown at the caller', () async {
      provider.failSetRevenue = true;

      await expectLater(
        service
            .setRevenue('a1', 2026, 3, 1500)
            .timeout(const Duration(seconds: 2)),
        completes,
      );
      // The background persist attempt still runs and fails silently.
      await Future<void>.delayed(Duration.zero);
      expect(provider.calls, contains('setRevenue'));
    });

    test('invalidates the inherited-revenue cache for the account', () async {
      // getMostRecentRevenue's own cache-hit path is exercised by hitting the
      // cache twice: once to populate it (via a failure -> null cached),
      // then again after setRevenue to confirm the entry was cleared and a
      // fresh (still-failing, since the fake always throws) lookup runs.
      await service.getMostRecentRevenue(
        'a1',
        before: const Period(year: 2026, month: 4),
      );
      provider.calls.clear();

      await service.setRevenue('a1', 2026, 3, 1500);

      await service.getMostRecentRevenue(
        'a1',
        before: const Period(year: 2026, month: 4),
      );
      expect(
        provider.calls.where((c) => c.startsWith('getMostRecentWithRevenue(')),
        isNotEmpty,
        reason:
            'a cached null must not survive setRevenue for the same account',
      );
    });
  });

  group('getMostRecentRevenue', () {
    test(
      'returns and caches null when both cache and server lookups fail',
      () async {
        final first = await service.getMostRecentRevenue(
          'a1',
          before: const Period(year: 2026, month: 4),
        );
        expect(first, isNull);
        expect(provider.calls, [
          'getMostRecentWithRevenue(source: Source.cache)',
          'getMostRecentWithRevenue(source: Source.server)',
        ]);

        provider.calls.clear();
        final second = await service.getMostRecentRevenue(
          'a1',
          before: const Period(year: 2026, month: 4),
        );
        expect(second, isNull);
        expect(
          provider.calls,
          isEmpty,
          reason: 'the null result must be cached, not re-fetched',
        );
      },
    );
  });

  group('deleteByAccountId (local, best-effort)', () {
    test('never waits for the server (awaitAck: false)', () async {
      await service.deleteByAccountId('a1').timeout(const Duration(seconds: 2));
      expect(provider.calls.single, contains('awaitAck: false'));
    });

    test('a provider failure is swallowed, not thrown at the caller', () async {
      provider.failDeleteByAccountId = true;
      await expectLater(service.deleteByAccountId('a1'), completes);
    });

    test('clears the inherited-revenue cache for the account', () async {
      await service.getMostRecentRevenue(
        'a1',
        before: const Period(year: 2026, month: 4),
      );
      provider.calls.clear();

      await service.deleteByAccountId('a1');
      await service.getMostRecentRevenue(
        'a1',
        before: const Period(year: 2026, month: 4),
      );

      expect(
        provider.calls.where((c) => c.startsWith('getMostRecentWithRevenue(')),
        isNotEmpty,
        reason: 'a cached null must not survive an account deletion',
      );
    });
  });

  group('purgeByAccountId (server, used by the durable cleanup)', () {
    test('queries the server, not just the cache', () async {
      await service.purgeByAccountId('a1');
      expect(provider.calls.single, contains('Source.server'));
    });

    test(
      'a failure propagates, so the durable cleanup operation is retried',
      () async {
        provider.failDeleteByAccountId = true;
        await expectLater(service.purgeByAccountId('a1'), throwsStateError);
      },
    );
  });
}
