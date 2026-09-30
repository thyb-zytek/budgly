import 'dart:async';

import 'package:budgly/src/services/accounts/accounts_service_provider.dart';
import 'package:budgly/src/services/categories/categories_service_provider.dart';
import 'package:budgly/src/services/cleanup/deletion_cleanup_service.dart';
import 'package:budgly/src/services/expenses/expenses_service_provider.dart';
import 'package:budgly/src/services/offline/local_cache_provider.dart';
import 'package:budgly/src/services/offline/sync_manager_provider.dart';
import 'package:budgly/src/state/expenses_provider.dart';
import 'package:budgly/src/state/profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Application composition root for offline sync handlers.
///
/// Services are constructed without lifecycle side effects. This provider
/// wires their handlers to the single application sync coordinator explicitly.
final syncBootstrapProvider = Provider<void>((ref) {
  final manager = ref.read(syncManagerProvider);
  ref.read(accountsServiceProvider).registerSyncHandler(manager);
  ref.read(categoriesServiceProvider).registerSyncHandler(manager);
  final expenses = ref.read(expensesServiceProvider);
  // Drains operations queued by older builds; new expense writes go through
  // Firestore's own offline queue only.
  expenses.registerSyncHandler(manager);
  ref.read(profileServiceProvider).registerSyncHandler(manager);
  ref.read(deletionCleanupServiceProvider).registerSyncHandler(manager);

  // Best-effort; never blocks startup and never reports failure upward (see
  // LocalCache.purgeObsoleteCacheEntries).
  unawaited(ref.read(localCacheProvider).purgeObsoleteCacheEntries());

  // Firestore can reject a write long after it was applied optimistically
  // (the write Future only completes on a server acknowledgement). Reload the
  // affected account so the UI shows the server truth instead of a phantom.
  final rejections = expenses.rejectedWrites.listen((accountId) {
    unawaited(
      ref
          .read(expensesSessionProvider.notifier)
          .loadAccount(accountId, forceRefresh: true)
          .then<void>((_) {}, onError: (_) {}),
    );
  });
  ref.onDispose(rejections.cancel);
});
