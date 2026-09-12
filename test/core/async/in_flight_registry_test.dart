import 'dart:async';

import 'package:budgly/src/core/async/in_flight_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InFlightRegistry', () {
    test('peek returns null when nothing is registered', () {
      final registry = InFlightRegistry<String>();
      expect(registry.peek<void>('a'), isNull);
      expect(registry.isPending('a'), isFalse);
    });

    test('peek returns the registered future for the key', () async {
      final registry = InFlightRegistry<String>();
      final completer = Completer<List<int>>();
      registry.register('a', completer.future);

      expect(registry.isPending('a'), isTrue);
      expect(identical(registry.peek<List<int>>('a'), completer.future), isTrue);

      completer.complete([1, 2, 3]);
      await completer.future;
    });

    test('release removes the entry only if it is still the current one', () async {
      final registry = InFlightRegistry<String>();
      final first = Future<void>.value();
      final second = Future<void>.value();

      registry.register('a', first);
      registry.register('a', second); // second call replaces the first

      // Releasing the stale (first) future must not evict the current one.
      registry.release('a', first);
      expect(registry.isPending('a'), isTrue);

      registry.release('a', second);
      expect(registry.isPending('a'), isFalse);
    });

    test('does not auto-release on completion — caller controls cleanup', () async {
      final registry = InFlightRegistry<String>();
      final future = Future<void>.value();
      registry.register('a', future);
      await future;

      // Mirrors the existing per-service behavior where some code paths
      // (e.g. an unawaited background refresh) intentionally never call
      // release(); this extraction must not silently change that.
      expect(registry.isPending('a'), isTrue);
    });

    test('remove and clear drop entries unconditionally', () {
      final registry = InFlightRegistry<String>();
      registry.register('a', Future<void>.value());
      registry.register('b', Future<void>.value());

      registry.remove('a');
      expect(registry.isPending('a'), isFalse);
      expect(registry.isPending('b'), isTrue);

      registry.clear();
      expect(registry.isPending('b'), isFalse);
    });

    test('different keys are tracked independently', () {
      final registry = InFlightRegistry<String>();
      final futureA = Future<void>.value();
      final futureB = Future<void>.value();

      registry.register('a', futureA);
      registry.register('b', futureB);

      expect(identical(registry.peek<void>('a'), futureA), isTrue);
      expect(identical(registry.peek<void>('b'), futureB), isTrue);
    });
  });
}
