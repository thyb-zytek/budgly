/// Tracks the last successful remote refresh per key so a service can skip
/// a redundant network refresh within [interval] of the previous one,
/// while always allowing an explicit `forceRefresh`.
class RefreshThrottle<K> {
  RefreshThrottle(this.interval);

  final Duration interval;
  final Map<K, DateTime> _lastRefresh = {};

  /// Whether a refresh for [key] should proceed: true when forced, when
  /// [key] has never refreshed, or when [interval] has elapsed since the
  /// last successful refresh recorded via [markRefreshed].
  bool isDue(K key, {bool forceRefresh = false}) {
    if (forceRefresh) return true;
    final last = _lastRefresh[key];
    return last == null || DateTime.now().difference(last) >= interval;
  }

  void markRefreshed(K key) => _lastRefresh[key] = DateTime.now();

  void remove(K key) => _lastRefresh.remove(key);

  void clear() => _lastRefresh.clear();
}
