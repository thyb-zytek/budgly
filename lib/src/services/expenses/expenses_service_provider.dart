import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'expenses_service_provider.g.dart';

/// Riverpod-facing exposure of [ExpensesService] (issue M3).
///
/// Not rewritten: 8 call sites still on `.instance`. `ExpensesService`
/// already forwards `ExpensesStore`'s own notifications
/// (`_store.addListener(notifyListeners)`), and that store data is already
/// available reactively via `expensesSessionProvider` (issue M2) — so this
/// mirror only needs to expose what's genuinely specific to the service
/// itself: [creationRevision].
///
/// The constructor also registers a sync handler with `SyncManager`
/// (`SyncManager.instance.registerHandler('expenses', ...)`), exactly like
/// `ProfileService` (issue M1b) — safe regardless of how many times this
/// *provider* is rebuilt, because `.instance` always returns the same
/// underlying singleton, whose constructor only ever runs once.
@Riverpod(keepAlive: true)
Raw<ExpensesService> expensesService(Ref ref) => ExpensesService.instance;

@Riverpod(keepAlive: true)
class ExpensesServiceRevision extends _$ExpensesServiceRevision {
  ExpensesService get _service => ref.read(expensesServiceProvider);

  @override
  int build() {
    final service = ref.watch(expensesServiceProvider);
    service.addListener(_onChanged);
    ref.onDispose(() => service.removeListener(_onChanged));
    return service.creationRevision;
  }

  void _onChanged() {
    state = _service.creationRevision;
  }
}
