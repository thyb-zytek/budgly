import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'analytics_service_provider.g.dart';

/// Process-wide analytics client owned by Riverpod.
///
/// The provider owns the single application instance; domain services receive
/// it explicitly instead of reaching into a global singleton.
@Riverpod(keepAlive: true)
AnalyticsService analyticsService(Ref ref) => AnalyticsService();
