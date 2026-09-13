import 'package:budgly/src/services/auth/auth_service.dart';
import 'package:budgly/src/services/auth/auth_service_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exposes the AuthService singleton', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(authServiceProvider), same(AuthService.instance));
  });

  test('can be overridden with a fake in tests', () {
    final fake = AuthService();
    final container = ProviderContainer(
      overrides: [authServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    expect(container.read(authServiceProvider), same(fake));
  });
}
