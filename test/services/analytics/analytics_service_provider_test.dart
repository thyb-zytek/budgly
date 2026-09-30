import 'package:budgly/src/services/analytics/analytics_service_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exposes one Riverpod-owned AnalyticsService instance', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final first = container.read(analyticsServiceProvider);
    final second = container.read(analyticsServiceProvider);
    expect(second, same(first));
  });
}
