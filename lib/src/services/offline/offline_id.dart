import 'dart:math';

/// Client-side UUID v4 generator, used to allocate an entity id *before* its
/// first remote attempt so that every replay of a queued write targets the
/// same document/row (idempotent upsert).
class OfflineId {
  // `Random.secure()` rather than `Random()`: ids are never secrets (access is
  // enforced by RLS / Firestore rules), but a CSPRNG costs nothing here and
  // removes any doubt about predictability or cross-device collisions.
  static final Random _random = Random.secure();

  static String uuid() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    // RFC 4122: version 4, variant 10xx.
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;

    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
