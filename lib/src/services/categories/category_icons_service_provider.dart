import 'package:budgly/src/services/categories/category_icons_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'category_icons_service_provider.g.dart';

/// Application-scoped category icon catalogue service.
///
/// The service itself is stateless; Riverpod owns its application lifetime so
/// consumers share one instance and tests can override it directly.
@Riverpod(keepAlive: true)
CategoryIconsService categoryIconsService(Ref ref) => CategoryIconsService();
