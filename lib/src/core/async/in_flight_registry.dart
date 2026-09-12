/// Tracks in-progress asynchronous operations keyed by [K] so that
/// concurrent callers can observe (or ignore) the same underlying
/// [Future] instead of triggering duplicate work — typically a duplicate
/// network refresh for the same account/user/period.
///
/// This intentionally owns *only* the pending-operation bookkeeping. It
/// does not decide when to refresh, how to combine with a local cache, or
/// when an entry should be released: those policies differ enough between
/// `AccountsService`, `CategoriesService` and `AccountBudgetsService` that
/// folding them into a single generic method would hide real behavioral
/// differences behind a false abstraction. Callers keep their own control
/// flow and simply call [register]/[release] where they previously wrote
/// directly to a `Map<K, Future<void>>`.
class InFlightRegistry<K> {
  final Map<K, Future<Object?>> _pending = {};

  /// The future currently registered for [key], if any. Dart retains full
  /// generic type information at runtime, so this cast is safe as long as
  /// callers are consistent about the [T] they registered for a given key.
  Future<T>? peek<T>(K key) {
    final future = _pending[key];
    return future == null ? null : future as Future<T>;
  }

  bool isPending(K key) => _pending.containsKey(key);

  /// Registers [future] as the in-progress operation for [key]. Does not
  /// remove it automatically — call [release] once the caller no longer
  /// needs to short-circuit on this entry, mirroring each service's
  /// existing cleanup timing exactly.
  void register(K key, Future<Object?> future) {
    _pending[key] = future;
  }

  /// Removes [key] only if [future] is still the entry currently
  /// registered for it (a newer call may have already replaced it).
  void release(K key, Future<Object?> future) {
    if (identical(_pending[key], future)) _pending.remove(key);
  }

  void remove(K key) => _pending.remove(key);

  void clear() => _pending.clear();
}
