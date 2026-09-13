import 'package:budgly/src/services/categories/category_icons_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'category_icons_service_provider.g.dart';

/// Riverpod-facing exposure of [CategoryIconsService] (issue M3).
///
/// Only one call site on `.instance` today — a good future candidate to be
/// migrated to a plain `FutureProvider` instead of kept as a bridge once its
/// single consumer moves to Riverpod (issue M4), rather than genuinely
/// needing the bridge pattern long-term.
@Riverpod(keepAlive: true)
CategoryIconsService categoryIconsService(Ref ref) => CategoryIconsService.instance;
