import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_manager_provider.g.dart';

/// Riverpod-facing exposure of [SyncManager] (issue M3).
///
/// Not rewritten: 8 call sites still on `.instance` (mostly other services
/// registering handlers in their constructor, e.g. `ProfileService`,
/// `ExpensesService`). [SyncManager] also mixes in `WidgetsBindingObserver`
/// to trigger a flush on app resume — untouched here.
@Riverpod(keepAlive: true)
Raw<SyncManager> syncManager(Ref ref) => SyncManager.instance;

/// Immutable snapshot of the sync status, for a future "syncing.../stuck"
/// indicator widget to watch reactively instead of adding its own
/// `addListener`/`removeListener` pair on the singleton.
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
  int get hashCode => Object.hash(isSyncing, hasStuckOperations, stuckOperationsCount);
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
