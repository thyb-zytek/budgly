import 'package:budgly/src/services/analytics/analytics_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'analytics_service_provider.g.dart';

/// Riverpod-facing exposure of [AnalyticsService] (issue M3).
///
/// Not rewritten: 14 call sites still on `.instance` — by far the most
/// widely used service in the app (events fired from almost every page).
/// Full removal of `.instance` is unrealistic before those pages migrate
/// (issues M4/M5); this provider only gives migrated `Notifier`s a way to
/// fire analytics events without reaching for the static singleton
/// directly. No `ChangeNotifier` state — plain pass-through.
@Riverpod(keepAlive: true)
AnalyticsService analyticsService(Ref ref) => AnalyticsService.instance;
