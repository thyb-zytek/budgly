import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnalyticsService - Critical event tracking', () {
    late AnalyticsService analytics;

    setUp(() {
      analytics = AnalyticsService();
    });

    test('Critical user action events can be tracked', () {
      final criticalEvents = [
        'account_created',
        'account_updated',
        'account_deleted',
        'category_created',
        'category_deleted',
        'expense_created',
        'expense_updated',
        'expense_deleted',
        'expense_single_occurrence_deleted',
        'expense_future_occurrences_deleted',
        'expense_toggled_debited',
        'recurring_expense_version_changed',
        'recurring_expense_occurrence_modified',
      ];

      // Verify all critical events can be tracked without throwing
      for (final event in criticalEvents) {
        expect(
          () => analytics.track(event),
          returnsNormally,
          reason: 'Event $event should be trackable',
        );
      }
    });

    test('User identification can be tracked', () {
      const testUserId = 'firebase_uid_12345';
      
      expect(
        () => analytics.identify(testUserId),
        returnsNormally,
        reason: 'User identification should succeed',
      );
    });

    test('Error tracking with context properties', () {
      const errorEvent = 'account_load_failed';
      
      expect(
        () => analytics.track(errorEvent, {'error': 'Network timeout', 'retry': 1}),
        returnsNormally,
        reason: 'Error tracking with context should succeed',
      );
    });

    test('App lifecycle events can be tracked', () {
      final lifecycleEvents = [
        'app_started',
        'sync_started',
        'sync_completed',
        'sync_failed',
      ];

      for (final event in lifecycleEvents) {
        expect(
          () => analytics.track(event),
          returnsNormally,
          reason: 'Lifecycle event $event should be trackable',
        );
      }
    });

    test('Event properties with various types are accepted', () {
      expect(
        () => analytics.track('expense_created', {
          'recurring': true,
          'amount': 100.50,
          'category': 'groceries',
          'account_id': 'acc_123',
        }),
        returnsNormally,
        reason: 'Events with mixed property types should be accepted',
      );
    });
  });
}
