import 'package:budgly/src/services/analytics/analytics_service_provider.dart';
import 'package:budgly/src/services/auth/auth_service_provider.dart';
import 'package:budgly/src/services/offline/sync_error_classifier.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:budgly/src/services/offline/sync_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

export 'sync_status.dart';

part 'sync_manager_provider.g.dart';

/// Riverpod-owned access to the process-wide synchronization coordinator.
///
/// The coordinator is process-wide because it owns the application lifecycle
/// observer and the single replay loop. Domain services receive this same
/// instance through DI; they never reach into a singleton themselves.
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
  // Stops the lifecycle observer and both timers. The manager's status stream
  // is closed by dispose(), and in-flight passes are prevented from publishing
  // new status once disposal starts.
  ref.onDispose(manager.dispose);
  return manager;
}

@Riverpod(keepAlive: true)
class SyncStatusNotifier extends _$SyncStatusNotifier {
  @override
  SyncStatus build() {
    final manager = ref.watch(syncManagerProvider);
    final subscription = manager.statusStream.listen((next) {
      if (!ref.mounted) return;
      state = next;
    });
    ref.onDispose(subscription.cancel);
    return manager.status;
  }
}
