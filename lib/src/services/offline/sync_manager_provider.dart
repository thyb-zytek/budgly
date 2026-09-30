import 'package:budgly/src/services/offline/sync_error_classifier.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:budgly/src/services/analytics/analytics_service_provider.dart';
import 'package:budgly/src/services/auth/auth_service_provider.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_manager_provider.g.dart';

/// Riverpod-owned access to the process-wide synchronization coordinator.
///
/// The coordinator is process-wide because it owns the application lifecycle
/// observer and the single replay loop. Domain services receive this same
/// instance through DI; they never reach into the singleton themselves.
final syncQueueProvider = Provider<SyncQueue>(
  (ref) => SyncQueue(
    ownerUserIdProvider: () => ref.read(authServiceProvider).firebaseUser?.uid,
  ),
);

@Riverpod(keepAlive: true)
Raw<SyncManager> syncManager(Ref ref) {
  final manager = SyncManager(
    queue: ref.watch(syncQueueProvider),
    analytics: ref.watch(analyticsServiceProvider),
    ownerUserIdProvider: () => ref.read(authServiceProvider).firebaseUser?.uid,
    isPermanentError: isPermanentSyncError,
  );
  // Stops the lifecycle observer and both timers, and prevents an in-flight
  // pass from notifying a disposed ChangeNotifier.
  ref.onDispose(manager.dispose);
  return manager;
}

/// Immutable snapshot of the sync status, watched reactively by
/// `SyncIssueBanner` instead of adding its own `addListener`/`removeListener`
/// pair on the singleton.
class SyncStatus {
  const SyncStatus({
    required this.isSyncing,
    required this.hasStuckOperations,
    required this.stuckOperationsCount,
  });

  final bool isSyncing;
  final bool hasStuckOperations;
  final int stuckOperationsCount;

  @override
  bool operator ==(Object other) =>
      other is SyncStatus &&
      other.isSyncing == isSyncing &&
      other.hasStuckOperations == hasStuckOperations &&
      other.stuckOperationsCount == stuckOperationsCount;

  @override
  int get hashCode =>
      Object.hash(isSyncing, hasStuckOperations, stuckOperationsCount);
}

@Riverpod(keepAlive: true)
class SyncStatusNotifier extends _$SyncStatusNotifier {
  SyncManager get _manager => ref.read(syncManagerProvider);

  @override
  SyncStatus build() {
    final manager = ref.watch(syncManagerProvider);
    manager.addListener(_onChanged);
    ref.onDispose(() => manager.removeListener(_onChanged));
    return _readState(manager);
  }

  SyncStatus _readState(SyncManager manager) => SyncStatus(
    isSyncing: manager.isSyncing,
    hasStuckOperations: manager.hasStuckOperations,
    stuckOperationsCount: manager.stuckOperationsCount,
  );

  void _onChanged() {
    state = _readState(_manager);
  }
}
