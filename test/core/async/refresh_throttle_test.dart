import 'package:budgly/src/core/async/refresh_throttle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RefreshThrottle', () {
    test('is due for a key that has never refreshed', () {
      final throttle = RefreshThrottle<String>(const Duration(minutes: 1));
      expect(throttle.isDue('a'), isTrue);
    });

    test('is not due right after markRefreshed, within the interval', () {
      final throttle = RefreshThrottle<String>(const Duration(minutes: 1));
      throttle.markRefreshed('a');
      expect(throttle.isDue('a'), isFalse);
    });

    test('forceRefresh is always due regardless of the interval', () {
      final throttle = RefreshThrottle<String>(const Duration(minutes: 1));
      throttle.markRefreshed('a');
      expect(throttle.isDue('a', forceRefresh: true), isTrue);
    });

    test('is due again once the interval has elapsed', () {
      final throttle = RefreshThrottle<String>(const Duration(seconds: -1));
      // A negative interval means "already elapsed" immediately after
      // markRefreshed, letting us test the elapsed branch deterministically
      // without depending on real wall-clock delays in a unit test.
      throttle.markRefreshed('a');
      expect(throttle.isDue('a'), isTrue);
    });

    test('keys are tracked independently', () {
      final throttle = RefreshThrottle<String>(const Duration(minutes: 1));
      throttle.markRefreshed('a');
      expect(throttle.isDue('a'), isFalse);
      expect(throttle.isDue('b'), isTrue);
    });

    test('remove makes a key due again', () {
      final throttle = RefreshThrottle<String>(const Duration(minutes: 1));
      throttle.markRefreshed('a');
      throttle.remove('a');
      expect(throttle.isDue('a'), isTrue);
    });

    test('clear makes every key due again', () {
      final throttle = RefreshThrottle<String>(const Duration(minutes: 1));
      throttle.markRefreshed('a');
      throttle.markRefreshed('b');
      throttle.clear();
      expect(throttle.isDue('a'), isTrue);
      expect(throttle.isDue('b'), isTrue);
    });
  });
}
