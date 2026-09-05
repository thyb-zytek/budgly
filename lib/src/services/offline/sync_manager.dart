import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'sync_queue.dart';
import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/services/analytics/analytics_service.dart';

/// Coordinates replay of Supabase mutations while the application is active.
///
/// We intentionally do not add a connectivity dependency here. A failed
/// request is cheap to retry and the manager retries on app resume and at a
/// short interval while the app is running. Both triggers run a *forced*
/// flush so operations still inside a backoff window are replayed as soon as
/// connectivity is likely back, instead of waiting out the full backoff before
/// the next pass. This keeps the feature working on every Flutter target
/// supported by Budgly without pretending that a network event is a reliable
/// source of truth.
///
/// [SyncManager] is also a [ChangeNotifier]: once an operation has failed
/// [stuckAfterAttempts] times in a row, it is considered "stuck" — still
/// retried in the background (nothing is ever dropped), but surfaced via
/// [hasStuckOperations] so the UI can let the user know some of their data
/// has not reached the server yet, instead of failing silently forever.
class SyncManager with WidgetsBindingObserver, ChangeNotifier {
  static final SyncManager instance = SyncManager._();

  SyncManager._();

  /// Number of consecutive failed attempts after which a pending operation
  /// is considered "stuck" rather than merely retrying with backoff.
  static const int stuckAfterAttempts = 5;

  final SyncQueue _queue = SyncQueue.instance;
  final Map<String, Future<void> Function(PendingSync)> _handlers = {};
  Timer? _timer;
  bool _started = false;
  bool _syncing = false;
  Future<void>? _flushHandle;

  /// Whether a synchronization pass is currently running.
  bool get isSyncing => _syncing;

  /// Notifies listeners, deferring to the next frame when a [flush] is
  /// triggered synchronously during a widget build (e.g. from a service
  /// constructor's [registerHandler] at cold-start). Notifying a widget
  /// listener mid-build throws "setState() or markNeedsBuild() called during
  /// build", so we let the current frame finish first. Outside a build pass
  /// the notification is delivered synchronously as before.
  void _notifyListenersSafely() {
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

  /// Resets singleton state between tests. Production code should never call
  /// this method; real handlers are registered again by service constructors.
  @visibleForTesting
  Future<void> resetForTest() async {
    await stop();
    await waitForIdle();
    _handlers.clear();
    _hasStuckOperations = false;
    _stuckOperationsCount = 0;
    _syncing = false;
    _flushHandle = null;
  }

  Future<void> flush({bool forceRetry = false}) async {
    if (_handlers.isEmpty) return;
    // If a flush is already running, join it instead of returning silently so
    // an explicit "retry" always produces feedback.
    final inFlight = _flushHandle;
    if (inFlight != null) {
      await inFlight;
      // An explicit retry must not inherit the readiness decision of a
      // normal flush that happened to be in flight. Once that pass completes,
      // run a forced pass so backoff is genuinely bypassed.
      if (!forceRetry) return;
    }
    _syncing = true;
    _notifyListenersSafely();
    final handle = _runFlush(forceRetry: forceRetry);
    _flushHandle = handle;
    try {
      await handle;
    } finally {
      _flushHandle = null;
    }
  }

  Future<void> _runFlush({bool forceRetry = false}) async {
    try {
      final allOperations = await _queue.all();
      final operations = (forceRetry
              ? allOperations
              : allOperations.where((operation) => operation.isReady))
          .toList();
      if (operations.isNotEmpty) {
        AnalyticsService.instance.track('sync_started', {
          'pending_operations': operations.length,
        });
      }

      // Account operations must be replayed before categories because a
      // category has a foreign key to accounts. If an account operation is
      // waiting for its backoff window, do not push child categories yet.
      final accountBlocked = !forceRetry && allOperations.any(
        (operation) => operation.type == 'accounts' && !operation.isReady,
      );
      final categoryBlocked = !forceRetry && allOperations.any(
        (operation) => operation.type == 'categories' && !operation.isReady,
      );
      final parentBlocked = accountBlocked || categoryBlocked;
      final ordered = [
        ...operations.where((operation) => operation.type == 'accounts'),
        ...operations.where((operation) => operation.type == 'user_profiles'),
        if (!accountBlocked)
          ...operations.where((operation) => operation.type == 'categories'),
        if (!parentBlocked)
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

      for (final operation in ordered) {
        final handler = _handlers[operation.type];
        if (handler == null) continue;

        try {
          await handler(operation);
          await _queue.remove(operation.id);
        } catch (e, stackTrace) {
          await _queue.markFailed(operation.id);
          AppLogger.error(
            'Sync operation failed (type=${operation.type}, '
            'op=${operation.operation}, attempts=${operation.attempts + 1})',
            e,
            stackTrace,
          );
          AnalyticsService.instance.track('sync_failed', {
            'type': operation.type,
          });
          AnalyticsService.instance.track('sync_queue_item_failed', {
            'type': operation.type,
            'operation': operation.operation,
          });
          // Stop at the first failed operation. Keeping order prevents a
          // child entity from being pushed before its parent exists remotely.
          break;
        }
      }
      if (operations.isNotEmpty) {
        final remaining = await _queue.all();
        if (remaining.isEmpty) {
          AnalyticsService.instance.track('sync_completed');
        }
      }
    } finally {
      _syncing = false;
      _notifyListenersSafely();
      await _refreshStuckState();
    }
  }

  Future<void> _refreshStuckState() async {
    final all = await _queue.all();
    final stuckCount = all
        .where((operation) => operation.attempts >= stuckAfterAttempts)
        .length;
    final isStuck = stuckCount > 0;
    if (isStuck != _hasStuckOperations || stuckCount != _stuckOperationsCount) {
      _hasStuckOperations = isStuck;
      _stuckOperationsCount = stuckCount;
      _notifyListenersSafely();
    }
  }

  /// Stops the periodic flush timer and lifecycle observation.
  ///
  /// Named `stop` rather than `dispose` because [SyncManager] mixes in
  /// [ChangeNotifier], whose own `dispose()` has an incompatible (`void`,
  /// synchronous) signature.
  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
  }
}
