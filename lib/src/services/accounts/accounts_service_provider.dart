import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/analytics/analytics_service_provider.dart';
import 'package:budgly/src/services/offline/local_cache_provider.dart';
import 'package:budgly/src/services/offline/sync_manager_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'accounts_service_provider.g.dart';

@Riverpod(keepAlive: true)
AccountsService accountsService(Ref ref) => AccountsService(
  analytics: ref.watch(analyticsServiceProvider),
  syncManager: ref.watch(syncManagerProvider),
  syncQueue: ref.watch(syncQueueProvider),
  localCache: ref.watch(localCacheProvider),
);
