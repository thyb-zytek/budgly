/// Small in-memory cache coordinator used by data services.
///
/// It deliberately stores only cache metadata, while the actual application
/// state remains in the corresponding Store. This prevents duplicating the
/// same TTL/in-flight-request logic across every service.
class CacheController<K> {
  CacheController({required this.ttl});

  final Duration ttl;
  final Map<K, DateTime> _timestamps = {};
  final Map<K, Future<void>> _inFlight = {};
  int _generation = 0;

  int get generation => _generation;

  bool isFresh(K key) {
    final timestamp = _timestamps[key];
    return timestamp != null && DateTime.now().difference(timestamp) < ttl;
  }

  Future<void>? inFlight(K key) => _inFlight[key];

  void markFresh(K key) {
    _timestamps[key] = DateTime.now();
  }

  void track(K key, Future<void> future) {
    _inFlight[key] = future;
  }

  void untrack(K key, Future<void> future) {
    if (identical(_inFlight[key], future)) {
      _inFlight.remove(key);
    }
  }

  void invalidate([K? key]) {
    _generation++;
    if (key == null) {
      _timestamps.clear();
      _inFlight.clear();
      return;
    }
    _timestamps.remove(key);
    _inFlight.remove(key);
  }
}
