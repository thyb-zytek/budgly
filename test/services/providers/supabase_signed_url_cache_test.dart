import 'package:budgly/src/services/providers/supabase/signed_url_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reuses a cached URL while the requested validity is covered', () {
    var now = DateTime(2026, 9, 19, 12);
    final cache = SignedUrlCache(now: () => now);

    cache.put('avatars:u1/a.png', url: 'signed-1', validityInSeconds: 3600);

    expect(cache.get('avatars:u1/a.png', validityInSeconds: 60), 'signed-1');

    now = now.add(const Duration(minutes: 59, seconds: 56));
    expect(cache.get('avatars:u1/a.png', validityInSeconds: 60), isNull);
  });

  test(
    'does not reuse a shorter-lived URL for a longer requested validity',
    () {
      final now = DateTime(2026, 9, 19, 12);
      final cache = SignedUrlCache(now: () => now);

      cache.put('avatars:u1/a.png', url: 'signed-1', validityInSeconds: 60);

      expect(cache.get('avatars:u1/a.png', validityInSeconds: 3600), isNull);
    },
  );

  test('invalidating an object never removes another object', () {
    final cache = SignedUrlCache(now: () => DateTime(2026, 9, 19, 12));
    cache.put('avatars:u1/a.png', url: 'a', validityInSeconds: 3600);
    cache.put('avatars:u1/b.png', url: 'b', validityInSeconds: 3600);

    cache.invalidate('avatars:u1/a.png');

    expect(cache.get('avatars:u1/a.png', validityInSeconds: 60), isNull);
    expect(cache.get('avatars:u1/b.png', validityInSeconds: 60), 'b');
  });
}
