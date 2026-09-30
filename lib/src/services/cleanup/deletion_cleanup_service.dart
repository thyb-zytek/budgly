import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/accounts/accounts_service_provider.dart';
import 'package:budgly/src/services/budget/account_budgets_service.dart';
import 'package:budgly/src/services/budget/account_budgets_service_provider.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/services/expenses/expenses_service_provider.dart';
import 'package:budgly/src/services/offline/sync_manager.dart';
import 'package:budgly/src/services/offline/sync_queue.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Durable cleanup of the data that lives outside Supabase when an account or
/// a category is deleted (Firestore expenses/budgets, storage folder).
///
/// The Supabase delete is the durable operation the user triggered. Once the
/// server confirmed it, `AccountsService` / `CategoriesService` enqueue a
/// `cleanup` operation that this service replays. Unlike the previous
/// fire-and-forget attempt it:
///
/// * survives an app kill and being offline (it is retried until it succeeds);
/// * queries the *server*, so documents this device never cached are found;
/// * reports failures (the operation is retried instead of leaving orphans).
///
/// Every step is idempotent, so a replay after a partial failure is safe.
class DeletionCleanupService {
  DeletionCleanupService({
    required this._expenses,
    required this._budgets,
    required this._accounts,
  });

  final ExpensesService _expenses;
  final AccountBudgetsService _budgets;
  final AccountsService _accounts;

  void registerSyncHandler(SyncManager manager) {
    manager.registerHandler('cleanup', _handlePendingSync);
  }

  Future<void> _handlePendingSync(PendingSync operation) async {
    final id = operation.payload['id'] as String;
    switch (operation.operation) {
      case 'account':
        await _expenses.purgeByAccountId(id);
        await _budgets.purgeByAccountId(id);
        await _accounts
            .deleteAccountFolder(id, throwOnFailure: true)
            .timeout(AppConstants.networkTimeout);
      case 'category':
        await _expenses.purgeByCategoryId(id);
      default:
        throw StateError('Unknown cleanup operation: ${operation.operation}');
    }
  }
}

final deletionCleanupServiceProvider = Provider<DeletionCleanupService>(
  (ref) => DeletionCleanupService(
    expenses: ref.watch(expensesServiceProvider),
    budgets: ref.watch(accountBudgetsServiceProvider),
    accounts: ref.watch(accountsServiceProvider),
  ),
);
