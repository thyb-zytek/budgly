import 'package:budgly/src/core/logging/logger.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

abstract interface class AnalyticsProvider {
  void track(String event, Map<String, Object?> properties);
  Future<void> identify(String userId, {Map<String, Object?> properties});
  Future<void> reset();
}

class AnalyticsService {
  static final AnalyticsService instance = AnalyticsService._();
  AnalyticsService._();

  AnalyticsProvider _provider = const _DebugAnalyticsProvider();
  bool _initialized = false;
  final List<(String, Map<String, Object?>)> _pendingEvents = [];
  (String, Map<String, Object?>)? _pendingIdentity;

  static const _allowedEvents = <String>{
    'app_started',
    'screen_viewed',
    'overview_refresh',
    'profile_refresh',
    'overview_period_changed',
    'overview_expense_loaded',
    'expense_page_loaded',
    'account_created', 'account_updated', 'account_deleted',
    'account_load_failed',
    'category_created', 'category_updated', 'category_deleted',
    'category_load_failed',
    'expense_created', 'expense_updated', 'expense_deleted',
    'expense_load_failed', 'expense_create_failed', 'expense_update_failed', 'expense_delete_failed',
    'recurring_expense_version_changed',
    'recurring_expense_occurrence_modified',
    'expense_single_occurrence_deleted',
    'expense_future_occurrences_deleted',
    'expense_toggled_debited',
    'profile_updated',
    'budget_updated',
    'revenue_set', 'revenue_load_failed', 'revenue_set_failed',
    'sync_started', 'sync_completed', 'sync_failed',
    'sync_queue_item_failed',
    'login_started', 'login_completed', 'login_failed',
    'signup_started', 'signup_completed', 'signup_failed',
    'google_signin_started', 'google_signin_completed', 'google_signin_failed',
    'password_reset_started', 'password_reset_completed', 'password_reset_failed',
    'logout_completed', 'logout_failed',
    'email_verification_sent',
    'onboarding_started', 'onboarding_step_started',
    'onboarding_step_completed',
    'onboarding_completed',
    'tutorial_account_created', 'tutorial_category_created',
    'tutorial_budget_created',
    'account_switched', 'category_expense_tap',
    'revenue_editor_opened', 'revenue_editor_closed',
    'expense_form_opened', 'settings_opened',
  };

  Future<void> initialize({required String projectToken, String host = 'https://eu.i.posthog.com'}) async {
    if (_initialized || projectToken.trim().isEmpty) return;
    try {
      final config = PostHogConfig(projectToken.trim());
      config.host = host.trim().isEmpty ? 'https://eu.i.posthog.com' : host.trim();
      // Product lifecycle events are tracked explicitly below to avoid duplicate
    // automatic events and unnecessary analytics traffic.
    config.captureApplicationLifecycleEvents = false;
      config.capturePushNotificationOpened = false;
      config.capturePushNotificationSubscriptions = false;
      config.sessionReplay = false;
      await Posthog().setup(config);
      _provider = _PostHogAnalyticsProvider(Posthog());
      _initialized = true;

      // Startup is intentionally non-blocking, so keep early product events
      // until PostHog is ready instead of silently losing them.
      final pendingEvents = List<(String, Map<String, Object?>)>.from(_pendingEvents);
      _pendingEvents.clear();
      for (final event in pendingEvents) {
        _provider.track(event.$1, event.$2);
      }

      final identity = _pendingIdentity;
      _pendingIdentity = null;
      if (identity != null) {
        await _provider.identify(identity.$1, properties: identity.$2);
      }
    } catch (error, stackTrace) {
      AppLogger.error('Failed to initialize PostHog: $error', error, stackTrace);
    }
  }

  void setProvider(AnalyticsProvider provider) => _provider = provider;

  void track(String event, [Map<String, Object?> properties = const {}]) {
    if (!_allowedEvents.contains(event)) {
      AppLogger.warning('Ignored unknown analytics event: $event');
      return;
    }
    final sanitized = <String, Object?>{};
    for (final entry in properties.entries) {
      if (_isSafeProperty(entry.key, entry.value)) sanitized[entry.key] = entry.value;
    }
    if (!_initialized) {
      if (_pendingEvents.length < 100) {
        _pendingEvents.add((event, sanitized));
      }
      return;
    }
    _provider.track(event, sanitized);
  }

  Future<void> identify(String userId, {Map<String, Object?> properties = const {}}) async {
    if (userId.isEmpty) return;
    final safe = <String, Object?>{};
    for (final entry in properties.entries) {
      if (_isSafeProperty(entry.key, entry.value)) safe[entry.key] = entry.value;
    }
    if (!_initialized) {
      _pendingIdentity = (userId, safe);
      return;
    }
    await _provider.identify(userId, properties: safe);
  }

  Future<void> reset() {
    _pendingIdentity = null;
    if (!_initialized) return Future.value();
    return _provider.reset();
  }

  bool _isSafeProperty(String key, Object? value) {
    const forbidden = {
      'amount', 'name', 'email', 'description', 'merchant', 'transaction',
      'financial_data', 'picture', 'picture_url', 'avatar_url', 'full_name',
    };
    if (forbidden.contains(key.toLowerCase())) return false;
    return value == null || value is String || value is num || value is bool;
  }
}

class _PostHogAnalyticsProvider implements AnalyticsProvider {
  const _PostHogAnalyticsProvider(this._posthog);
  final Posthog _posthog;

  @override
  void track(String event, Map<String, Object?> properties) {
    _posthog.capture(eventName: event, properties: Map<String, Object>.fromEntries(properties.entries.where((e) => e.value != null).map((e) => MapEntry(e.key, e.value!))));
  }

  @override
  Future<void> identify(String userId, {Map<String, Object?> properties = const {}}) =>
      _posthog.identify(userId: userId, userProperties: Map<String, Object>.fromEntries(properties.entries.where((e) => e.value != null).map((e) => MapEntry(e.key, e.value!))));

  @override
  Future<void> reset() => _posthog.reset();
}

class _DebugAnalyticsProvider implements AnalyticsProvider {
  const _DebugAnalyticsProvider();
  @override
  void track(String event, Map<String, Object?> properties) => AppLogger.debug(
    'analytics:$event${properties.isEmpty ? '' : ' $properties'}',
  );
  @override
  Future<void> identify(String userId, {Map<String, Object?> properties = const {}}) async {}
  @override
  Future<void> reset() async {}
}
