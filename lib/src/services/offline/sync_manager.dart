import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'sync_queue.dart';
import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';

/// Coordinates replay of Supabase mutations while the application is active.
///
/// We intentionally do not add a connectivity dependency here. A failed
/// request is cheap to retry. Replay is triggered by every local mutation, by
/// app resume, by a wake-up scheduled at the earliest backoff expiry, and by
/// a slow periodic safety net. Resume and the periodic timer run a *forced*
/// flush so operations still inside a backoff window are replayed as soon as
/// connectivity is likely back. This keeps the feature working on every
/// Flutter target supported by Budgly without pretending that a network event
/// is a reliable source of truth.
///
/// Only one replay loop runs at a time; a flush requested while a pass is
/// running triggers a trailing pass so no enqueued operation waits for the
/// next periodic trigger.
///
/// [SyncManager] is also a [ChangeNotifier]: once an operation has failed
/// [stuckAfterAttempts] times in a row, or has been rejected permanently by
/// the server, it is considered "stuck" — never dropped, but surfaced via
/// [hasStuckOperations] so the UI can let the user know some of their data
/// has not reached the server yet, instead of failing silently forever.
/// Permanently rejected operations are not replayed by background triggers;
/// use `flush(forceRetry: true, retryPermanent: true)` for an explicit retry.
class SyncManager with WidgetsBindingObserver, ChangeNotifier {
  SyncManager({
    required this._queue,
    required this._analytics,
    this._ownerUserIdProvider,
    this._isPermanentError,
  });

  /// Number of consecutive failed attempts after which a pending operation
  /// is considered "stuck" rather than merely retrying with backoff.
  static const int stuckAfterAttempts = 5;

  final SyncQueue _queue;
  final AnalyticsService _analytics;
  final String? Function()? _ownerUserIdProvider;

  /// Classifies replay failures that retrying can never fix. When omitted,
  /// every failure is treated as transient.
  final bool Function(Object error)? _isPermanentError;
  final Map<String, Future<void> Function(PendingSync)> _handlers = {};
  Timer? _timer;
  Timer? _retryTimer;
  bool _started = false;
  bool _disposed = false;
  bool _syncing = false;

  /// Completes when the running drain loop (one or more replay passes) ends.
  Future<void>? _flushHandle;

  /// Set when [flush] is called while a pass is running: that pass has already
  /// read the queue, so a trailing pass is required to see newer operations.
  bool _dirty = false;
  bool _forceNext = false;
  bool _retryPermanentNext = false;

  /// Whether a synchronization pass is currently running.
  bool get isSyncing => _syncing;

  /// Notifies listeners, deferring to the next frame when a [flush] is
  /// triggered synchronously during a widget build (e.g. from a service
  /// explicit sync composition at cold-start). Notifying a widget
  /// listener mid-build throws "setState() or markNeedsBuild() called during
  /// build", so we let the current frame finish first. Outside a build pass
  /// the notification is delivered synchronously as before.
  void _notifyListenersSafely() {
    if (_disposed) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
    } else {
      notifyListeners();
    }
  }

  bool _hasStuckOperations = false;
  int _stuckOperationsCount = 0;

  /// Whether at least one pending mutation has failed
  /// [stuckAfterAttempts] times or more in a row.
  bool get hasStuckOperations => _hasStuckOperations;

  /// How many pending mutations are currently considered stuck.
  int get stuckOperationsCount => _stuckOperationsCount;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    // The primary triggers are mutations and app resume. The timer is only a
    // safety net, so it can stay relatively infrequent without affecting UX.
    // Forced so a backed-off operation is retried instead of staying in its
    // backoff window until long after connectivity has come back.
    _timer = Timer.periodic(const Duration(minutes: 5), (_) {
      unawaited(flush(forceRetry: true));
    });
    unawaited(flush());
  }

  /// Entity types that currently have a replay handler (composition-root
  /// regression tests).
  @visibleForTesting
  Set<String> get registeredHandlerTypes => _handlers.keys.toSet();

  void registerHandler(
    String type,
    Future<void> Function(PendingSync operation) handler,
  ) {
    _handlers[type] = handler;
    if (_started) unawaited(flush());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Forced: coming back to the app is the most common moment where
      // connectivity has returned, so skip backoff rather than waiting for
      // the next periodic pass.
      unawaited(flush(forceRetry: true));
    }
  }

  /// Waits for the currently running synchronization pass, if any.
  ///
  /// Consumers that must not race a logout or process teardown can await this
  /// without starting another pass.
  Future<void> waitForIdle() async {
    final handle = _flushHandle;
    if (handle != null) await handle;
  }

  /// Resets coordinator state between tests. Production code should never call
  /// this method; handlers are registered by the sync composition root.
  @visibleForTesting
  Future<void> resetForTest() async {
    await stop();
    await waitForIdle();
    _handlers.clear();
    _hasStuckOperations = false;
    _stuckOperationsCount = 0;
    _syncing = false;
    _flushHandle = null;
    _dirty = false;
    _forceNext = false;
    _retryPermanentNext = false;
  }

  /// Requests a replay pass and completes when the queue has been drained as
  /// far as possible.
  ///
  /// Only one drain loop runs at a time. A call made while a pass is running
  /// marks the loop dirty, so a trailing pass picks up operations enqueued
  /// after the running pass read the queue; every caller shares the same
  /// completion future, so [waitForIdle] and explicit retries stay accurate.
  ///
  /// [forceRetry] bypasses backoff. [retryPermanent] additionally replays
  /// operations flagged as permanently rejected (explicit user retry only).
  Future<void> flush({bool forceRetry = false, bool retryPermanent = false}) {
    if (_handlers.isEmpty || _disposed) return Future<void>.value();
    _forceNext = _forceNext || forceRetry || retryPermanent;
    _retryPermanentNext = _retryPermanentNext || retryPermanent;

    final running = _flushHandle;
    if (running != null) {
      _dirty = true;
      return running;
    }
    final handle = _drain();
    _flushHandle = handle;
    return handle;
  }

  Future<void> _drain() async {
    try {
      do {
        _dirty = false;
        final force = _forceNext;
        final retryPermanent = _retryPermanentNext;
        _forceNext = false;
        _retryPermanentNext = false;
        _syncing = true;
        _notifyListenersSafely();
        await _runFlush(forceRetry: force, retryPermanent: retryPermanent);
      } while (_dirty && !_disposed);
    } finally {
      _flushHandle = null;
    }
  }

  Future<void> _runFlush({
    bool forceRetry = false,
    bool retryPermanent = false,
  }) async {
    try {
      final allOperations = await _queue.all();
      final ownerUserId = _ownerUserIdProvider?.call();
      final ownedOperations = _ownerUserIdProvider == null
          ? allOperations
          : ownerUserId == null
          ? const <PendingSync>[]
          : allOperations.where(
              (operation) => operation.ownerUserId == ownerUserId,
            );
      final operations = ownedOperations
          .where(
            (operation) => operation.permanent
                ? retryPermanent
                : (forceRetry || operation.isReady),
          )
          .toList();
      if (operations.isNotEmpty) {
        _analytics.track('sync_started', {
          'pending_operations': operations.length,
        });
      }

      // Account operations are replayed before categories because a category
      // has a foreign key to an account. Categories are replayed before
      // expenses for the same reason. Dependency blocking below remains
      // entity-scoped, so an unrelated account can still synchronize.
      final ordered = [
        ...operations.where((operation) => operation.type == 'accounts'),
        ...operations.where((operation) => operation.type == 'user_profiles'),
        ...operations.where((operation) => operation.type == 'categories'),
        ...operations.where((operation) => operation.type == 'expenses'),
        // Preserve support for registered test/custom handlers and future
        // entity types without accidentally dropping them from the replay
        // pass. Only the known dependency chain above has special ordering.
        ...operations.where(
          (operation) =>
              operation.type != 'accounts' &&
              operation.type != 'user_profiles' &&
              operation.type != 'categories' &&
              operation.type != 'expenses',
        ),
      ];

      // Dependencies are entity-scoped. A failed account must block only
      // categories/expenses belonging to that account; it must never stall
      // unrelated accounts. Likewise, a failed category only blocks expenses
      // referencing that category.
      final blockedEntityKeys = <String>{};
      final blockedAccountIds = <String>{
        for (final operation in ownedOperations)
          if (operation.type == 'accounts' && !operation.isReady)
            operation.entityId,
      };
      final blockedCategoryIds = <String>{
        for (final operation in ownedOperations)
          if (operation.type == 'categories' && !operation.isReady)
            operation.entityId,
      };

      bool isBlocked(PendingSync operation) {
        if (operation.entityId.isNotEmpty &&
            blockedEntityKeys.contains(
              '${operation.type}:${operation.entityId}',
            )) {
          return true;
        }
        switch (operation.type) {
          case 'categories':
            final accountId = operation.payload['account_id']?.toString();
            return accountId != null && blockedAccountIds.contains(accountId);
          case 'expenses':
            final accountId = operation.payload['accountId']?.toString();
            final categoryId = operation.payload['categoryId']?.toString();
            return (accountId != null &&
                    blockedAccountIds.contains(accountId)) ||
                (categoryId != null && blockedCategoryIds.contains(categoryId));
          default:
            return false;
        }
      }

      void blockDependents(PendingSync operation) {
        if (operation.type == 'accounts') {
          blockedAccountIds.add(operation.entityId);
        } else if (operation.type == 'categories') {
          blockedCategoryIds.add(operation.entityId);
        }
      }

      final completedIds = <String>{};
      final failedIds = <String>{};
      final permanentFailures = <String, String>{};

      for (final operation in ordered) {
        // Authentication can change while a replay pass is in flight (for
        // example after token/session invalidation). Never start another
        // mutation under the new session using the old pass's ownership.
        if (_ownerUserIdProvider != null &&
            _ownerUserIdProvider.call() != ownerUserId) {
          break;
        }
        if (isBlocked(operation)) continue;

        final handler = _handlers[operation.type];
        if (handler == null) continue;

        try {
          await handler(operation);
          completedIds.add(operation.id);
          // A dependency may have been marked blocked before this pass because
          // its parent was inside backoff. If forceRetry makes that parent run
          // successfully now, its dependents must become eligible later in
          // the same pass.
          if (operation.type == 'accounts') {
            blockedAccountIds.remove(operation.entityId);
          } else if (operation.type == 'categories') {
            blockedCategoryIds.remove(operation.entityId);
          }
        } catch (e, stackTrace) {
          final permanent = _isPermanentError?.call(e) ?? false;
          if (permanent) {
            final description = e.toString();
            permanentFailures[operation.id] = description.length > 200
                ? description.substring(0, 200)
                : description;
          } else {
            failedIds.add(operation.id);
          }
          AppLogger.error(
            'Sync operation failed (type=${operation.type}, '
            'op=${operation.operation}, attempts=${operation.attempts + 1}, '
            'permanent=$permanent)',
            e,
            stackTrace,
          );
          _analytics.track('sync_failed', {'type': operation.type});
          _analytics.track('sync_queue_item_failed', {
            'type': operation.type,
            'operation': operation.operation,
            'permanent': permanent,
          });
          if (operation.entityId.isNotEmpty) {
            blockedEntityKeys.add('${operation.type}:${operation.entityId}');
          }
          blockDependents(operation);
        }
      }

      // Persist all outcomes from this replay pass together. A successful
      // batch used to trigger one SharedPreferences JSON rewrite per item.
      // Keeping the handler execution sequential preserves dependency order,
      // while committing the outcomes once removes the storage amplification.
      await _queue.applyBatch(
        removeIds: completedIds,
        failedIds: failedIds,
        permanentFailures: permanentFailures,
      );

      if (operations.isNotEmpty) {
        final remaining = await _queue.all();
        final remainingOwned = _ownerUserIdProvider == null
            ? remaining
            : ownerUserId == null
            ? const <PendingSync>[]
            : remaining.where(
                (operation) => operation.ownerUserId == ownerUserId,
              );
        if (remainingOwned.isEmpty) {
          _analytics.track('sync_completed');
        }
      }
    } finally {
      _syncing = false;
      _notifyListenersSafely();
      await _afterPass();
    }
  }

  /// Refreshes the "stuck" indicator and schedules the next backoff wake-up.
  Future<void> _afterPass() async {
    final all = await _queue.all();
    final ownerUserId = _ownerUserIdProvider?.call();
    final owned = _ownerUserIdProvider == null
        ? all
        : all.where(
            (operation) =>
                ownerUserId != null && operation.ownerUserId == ownerUserId,
          );

    final stuckCount = owned
        .where(
          (operation) =>
              operation.permanent || operation.attempts >= stuckAfterAttempts,
        )
        .length;
    final isStuck = stuckCount > 0;
    if (isStuck != _hasStuckOperations || stuckCount != _stuckOperationsCount) {
      _hasStuckOperations = isStuck;
      _stuckOperationsCount = stuckCount;
      _notifyListenersSafely();
    }

    _scheduleNextRetry(owned);
  }

  /// Wakes the manager when the earliest backoff window ends, so backoff is
  /// effective instead of waiting for the next periodic/resume trigger.
  ///
  /// Only operations whose retry time is still in the future are considered:
  /// an operation whose time has already passed but that was skipped (blocked
  /// behind a failed parent) must not cause a busy loop.
  void _scheduleNextRetry(Iterable<PendingSync> owned) {
    _retryTimer?.cancel();
    _retryTimer = null;
    if (!_started || _disposed) return;

    final now = DateTime.now();
    DateTime? next;
    for (final operation in owned) {
      final at = operation.nextAttemptAt;
      if (operation.permanent || at == null || !at.isAfter(now)) continue;
      if (next == null || at.isBefore(next)) next = at;
    }
    if (next == null) return;

    var delay = next.difference(now);
    if (delay < const Duration(seconds: 1)) delay = const Duration(seconds: 1);
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      unawaited(flush());
    });
  }

  /// Stops the periodic flush timer and lifecycle observation.
  ///
  /// [SyncManager] is a [ChangeNotifier], so [dispose] also calls this and
  /// makes any in-flight pass stop notifying listeners.
  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(stop());
    super.dispose();
  }
}
