import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';

final integrationSyncQueue = SyncQueue();
final integrationSyncManager = SyncManager(
  queue: integrationSyncQueue,
  analytics: AnalyticsService(),
);
