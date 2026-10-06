import 'dart:async';

import 'package:budgly/src/core/errors/app_user_message.dart';
import 'package:budgly/src/core/extensions/amount.dart';
import 'package:budgly/src/core/logging/logger.dart';
import 'package:budgly/src/state/action_status.dart';
import 'package:budgly/src/state/account_budgets_provider.dart';
import 'package:budgly/src/state/profile_providers.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/services/budget/account_budgets_service_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'revenue_provider.g.dart';

class RevenueState {
  const RevenueState({
    required this.revenue,
    required this.inheritedRevenue,
    required this.isLoaded,
    required this.showEditor,
    required this.status,
  });

  final double revenue;
  final double? inheritedRevenue;
  final bool isLoaded;
  final bool showEditor;
  final ActionStatus status;

  bool get hasRevenue => revenue > 0;
  bool get isEstimated => !hasRevenue && (inheritedRevenue ?? 0) > 0;
  double get effectiveRevenue => hasRevenue ? revenue : (inheritedRevenue ?? 0);
}

@riverpod
class Revenue extends _$Revenue {
  @override
  RevenueState build(String accountId, Period period) {
    ref.listen(accountBudgetsSessionProvider, (_, _) => _refreshFromSession());
    ref.listen(profileSessionProvider, (_, _) {
      _refreshFromSession();
      // The estimate is normalized with the profile's amountDecimalPlaces at
      // derivation time, so it has to be re-derived when the profile changes.
      // The service caches the raw value, so this is usually a cache hit.
      unawaited(loadInherited());
    });
    // A period's provider can be materialized by `Overview.selectPeriod`
    // before any widget watches it. That unlistened instance is disposed and
    // the instance the UI keeps is a new one, so anything derived here has to
    // be re-derived by every instance, exactly like `_fromSession` does for
    // the session-backed fields. Otherwise the inherited revenue — which only
    // lives in this provider — is lost on every period change.
    unawaited(loadInherited());
    return _fromSession();
  }

  Future<void> load({bool forceRefresh = false}) async {
    try {
      await ref
          .read(accountBudgetsSessionProvider.notifier)
          .loadRevenue(
            accountId,
            period.year,
            period.month,
            forceRefresh: forceRefresh,
          );
      if (!ref.mounted) return;
      _refreshFromSession();
      await loadInherited(forceRefresh: forceRefresh);
    } catch (e) {
      if (!ref.mounted) return;
      AppLogger.debug('Background overview revenue load unavailable: $e');
    }
  }

  /// Derives the estimate for [period] from the most recent revenue of a
  /// strictly earlier period (RL-01). The derivation owns exactly one
  /// visibility rule: an existing estimate hides the form. Whether the form
  /// should appear stays owned by `_fromSession`, `_refreshFromSession` and
  /// `setRevenue`, so a derivation resolving with no estimate never forces
  /// the form open or shut (before the session resolved, or once the user
  /// closed it).
  Future<void> loadInherited({bool forceRefresh = false}) async {
    try {
      if (forceRefresh) {
        ref
            .read(accountBudgetsServiceProvider)
            .invalidateMostRecentRevenueCache();
      }
      final value = await ref
          .read(accountBudgetsServiceProvider)
          .getMostRecentRevenue(accountId, before: period);
      if (!ref.mounted) return;
      final normalized = value == null
          ? null
          : normalizeAmount(
              value,
              decimalPlaces: ref
                  .read(profileSessionProvider)
                  .amountDecimalPlaces,
            );
      _set(
        inheritedRevenue: normalized,
        showEditor: (normalized ?? 0) > 0 ? false : null,
      );
    } catch (e) {
      if (!ref.mounted) return;
      AppLogger.debug('Inherited overview revenue unavailable: $e');
    }
  }

  void openEditor() => _set(showEditor: true);
  void closeEditor() => _set(showEditor: false);

  Future<void> setRevenue(double value) async {
    _set(status: state.status.loading());
    try {
      await ref
          .read(accountBudgetsSessionProvider.notifier)
          .setRevenue(accountId, period.year, period.month, value);
      final normalized = normalizeAmount(
        value,
        decimalPlaces: ref.read(profileSessionProvider).amountDecimalPlaces,
      );
      _set(
        revenue: normalized,
        inheritedRevenue: null,
        isLoaded: true,
        showEditor: false,
        status: state.status.success(
          const AppUserMessage.success(AppMessageKey.budgetSaved),
        ),
      );
      await loadInherited(forceRefresh: true);
    } catch (e) {
      _set(status: state.status.failure(e));
    } finally {
      _set(status: state.status.doneLoading());
    }
  }

  void consumeMessage() => _set(status: state.status.consumeMessage());

  RevenueState _fromSession() {
    final budgetSession = ref.read(accountBudgetsSessionProvider);
    final key = '${accountId}_${period.year}_${period.month}';
    final budget = budgetSession.budgets[key];
    final revenue = budget == null
        ? 0.0
        : normalizeAmount(
            budget.revenue,
            decimalPlaces: ref.read(profileSessionProvider).amountDecimalPlaces,
          );
    return RevenueState(
      revenue: revenue,
      inheritedRevenue: null,
      isLoaded: budgetSession.loadedKeys.contains(key),
      // At build time the estimate has not been derived yet; `loadInherited`
      // and `_refreshFromSession` refine the visibility as soon as they run.
      showEditor: _shouldShow(true, revenue, null),
      status: const ActionStatus.idle(),
    );
  }

  void _refreshFromSession() {
    final current = _fromSession();
    _set(
      revenue: current.revenue,
      isLoaded: current.isLoaded,
      showEditor: _shouldShow(
        current.isLoaded,
        current.revenue,
        state.inheritedRevenue,
      ),
    );
  }

  void _set({
    double? revenue,
    Object? inheritedRevenue = _unset,
    bool? isLoaded,
    bool? showEditor,
    ActionStatus? status,
  }) {
    state = RevenueState(
      revenue: revenue ?? state.revenue,
      inheritedRevenue: identical(inheritedRevenue, _unset)
          ? state.inheritedRevenue
          : inheritedRevenue as double?,
      isLoaded: isLoaded ?? state.isLoaded,
      showEditor: showEditor ?? state.showEditor,
      status: status ?? state.status,
    );
  }

  /// The form is only offered once the session has resolved the period's
  /// data and the period has neither its own revenue nor one propagated from
  /// an earlier period. An explicit `openEditor` still overrides this.
  bool _shouldShow(bool isLoaded, double revenue, double? inheritedRevenue) =>
      isLoaded && revenue <= 0 && (inheritedRevenue ?? 0) <= 0;
}

const _unset = Object();
