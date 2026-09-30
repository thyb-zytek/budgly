import 'package:budgly/src/services/categories/categories_service.dart';
import 'package:budgly/src/services/analytics/analytics_service_provider.dart';
import 'package:budgly/src/services/categories/category_icons_service_provider.dart';
import 'package:budgly/src/services/offline/local_cache_provider.dart';
import 'package:budgly/src/services/offline/sync_manager_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'categories_service_provider.g.dart';

@Riverpod(keepAlive: true)
CategoriesService categoriesService(Ref ref) => CategoriesService(
  analytics: ref.watch(analyticsServiceProvider),
  categoryIconsService: ref.watch(categoryIconsServiceProvider),
  syncManager: ref.watch(syncManagerProvider),
  syncQueue: ref.watch(syncQueueProvider),
  localCache: ref.watch(localCacheProvider),
);
