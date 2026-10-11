import 'package:budgly/src/core/dependencies/backend_clients_provider.dart';
import 'package:budgly/src/services/providers/firestore/accounts_budget.dart';
import 'package:budgly/src/services/budget/account_budgets_service.dart';
import 'package:budgly/src/services/analytics/analytics_service_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'account_budgets_service_provider.g.dart';

@Riverpod(keepAlive: true)
AccountBudgetsService accountBudgetsService(Ref ref) => AccountBudgetsService(
  provider: AccountBudgetFirestore(
    firestore: ref.watch(firestoreClientProvider),
    auth: ref.watch(firebaseAuthClientProvider),
  ),
  analytics: ref.watch(analyticsServiceProvider),
);
