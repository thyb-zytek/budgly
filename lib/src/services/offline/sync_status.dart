/// Immutable snapshot of the synchronization state exposed to the UI.
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
