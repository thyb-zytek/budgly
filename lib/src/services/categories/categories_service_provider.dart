import 'package:budgly/src/services/categories/categories_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'categories_service_provider.g.dart';

/// Riverpod-facing exposure of [CategoriesService] (issue M3).
///
/// Same reasoning as `accountsService`: not rewritten (8 call sites still on
/// `.instance`, mostly not-yet-migrated ViewModels — issue M4). No state of
/// its own beyond `CategoriesStore` (already mirrored by
/// `categoriesSessionProvider`, issue M2) — plain pass-through.
@Riverpod(keepAlive: true)
CategoriesService categoriesService(Ref ref) => CategoriesService.instance;
