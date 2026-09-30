/// Small in-memory cache for Supabase Storage signed URLs.
///
/// Entries are keyed by bucket + object path and are only reusable while the
/// requested validity window is still covered. A short safety margin avoids
/// handing out URLs that are about to expire.
class SignedUrlCache {
  final DateTime Function() _now;
  final Map<String, _Entry> _entries = {};

  SignedUrlCache({DateTime Function()? now}) : _now = now ?? DateTime.now;

  String? get(String key, {required int validityInSeconds}) {
    final entry = _entries[key];
    if (entry == null) return null;

    final margin = Duration(seconds: validityInSeconds > 5 ? 5 : 0);
    final requiredUntil = _now().add(
      Duration(seconds: validityInSeconds) - margin,
    );
    if (!entry.expiresAt.isAfter(requiredUntil)) {
      _entries.remove(key);
      return null;
    }
    return entry.url;
  }

  void put(String key, {required String url, required int validityInSeconds}) {
    _entries[key] = _Entry(
      url: url,
      expiresAt: _now().add(Duration(seconds: validityInSeconds)),
    );
  }

  void invalidate(String key) => _entries.remove(key);

  void clear() => _entries.clear();
}

class _Entry {
  const _Entry({required this.url, required this.expiresAt});

  final String url;
  final DateTime expiresAt;
}
