import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/analytics/analytics_service_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exposes the AnalyticsService singleton', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(analyticsServiceProvider), same(AnalyticsService.instance));
  });

  // Note: AnalyticsService only exposes a private constructor
  // (`AnalyticsService._()`), so there is no way today to build a second,
  // independent instance to override this provider with in a test — unlike
  // the other services bridged in this issue. Widening that constructor is
  // out of scope for a Riverpod-exposure issue; flagged here rather than
  // silently skipped.
}
