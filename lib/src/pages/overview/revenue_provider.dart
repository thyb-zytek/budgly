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
    ref.listen(profileSessionProvider, (_, _) => _refreshFromSession());
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
        showEditor: _shouldShow(state.isLoaded, state.revenue),
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
      showEditor: _shouldShow(true, revenue),
      status: const ActionStatus.idle(),
    );
  }

  void _refreshFromSession() {
    final current = _fromSession();
    _set(
      revenue: current.revenue,
      isLoaded: current.isLoaded,
      showEditor: _shouldShow(current.isLoaded, current.revenue),
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

  bool _shouldShow(bool isLoaded, double revenue) => isLoaded && revenue <= 0;
}

const _unset = Object();
