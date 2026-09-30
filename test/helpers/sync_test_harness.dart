import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';

/// Shared test infrastructure for the process-scoped sync coordinator.
///
/// Production code creates these objects through Riverpod. Tests deliberately
/// use explicit instances so they exercise the same dependency-injection
/// contract without exposing a production singleton just for test isolation.
final testSyncQueue = SyncQueue();
final testSyncManager = SyncManager(
  queue: testSyncQueue,
  analytics: AnalyticsService(),
);
