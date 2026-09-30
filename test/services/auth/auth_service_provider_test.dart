import 'package:budgly/src/services/auth/auth_service.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/auth/auth_service_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creates the AuthService through Riverpod', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final service = container.read(authServiceProvider);
    expect(service, isA<AuthService>());
  });

  test('can be overridden with a fake in tests', () {
    final fake = AuthService(analytics: AnalyticsService());
    final container = ProviderContainer(
      overrides: [authServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    expect(container.read(authServiceProvider), same(fake));
  });
}
