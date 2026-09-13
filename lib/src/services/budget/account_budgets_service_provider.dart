import 'package:budgly/src/services/budget/account_budgets_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'account_budgets_service_provider.g.dart';

/// Riverpod-facing exposure of [AccountBudgetsService] (issue M3).
///
/// Same reasoning as `accountsService`: not rewritten (5 call sites still on
/// `.instance`, not-yet-migrated ViewModels — issue M4). No state of its own
/// beyond `AccountBudgetsStore` (already mirrored by
/// `accountBudgetsSessionProvider`, issue M2) — plain pass-through.
@Riverpod(keepAlive: true)
AccountBudgetsService accountBudgetsService(Ref ref) => AccountBudgetsService.instance;
