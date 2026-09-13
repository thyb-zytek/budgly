import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/services/expenses/expenses_service_provider.dart';
import 'package:budgly/src/services/providers/firestore/expenses.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/builders.dart';
import '../../helpers/fake_stores.dart';

/// Accepts any create/update call without touching a real Firestore
/// backend — this test only cares about the service's own
/// [ExpensesService.creationRevision], not about persistence.
class NoopExpenseFirestore extends ExpenseFirestore {
  @override
  Future<Expense?> create(Expense expense) async => expense;
}

void main() {
  late ExpensesService fake;
  late ProviderContainer container;

  setUp(() {
    clearAllTestStores();
    Fixtures.resetSeq();
    // No `store:` override: ExpensesStore only exposes a private
    // constructor (`ExpensesStore._()`), so tests share the singleton like
    // every other test in this suite — isolation comes from
    // `clearAllTestStores()` in setUp/tearDown.
    fake = ExpensesService(expenseFirestore: NoopExpenseFirestore());
    container = ProviderContainer(
      overrides: [expensesServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
  });

  tearDown(clearAllTestStores);

  test('expensesServiceProvider exposes the given service', () {
    expect(container.read(expensesServiceProvider), same(fake));
  });

  test('initial creationRevision mirrors the service', () {
    expect(container.read(expensesServiceRevisionProvider), fake.creationRevision);
    expect(container.read(expensesServiceRevisionProvider), 0);
  });

  test('increments when an expense is created', () async {
    container.read(expensesServiceRevisionProvider); // ensure build() ran

    var notifications = 0;
    container.listen(expensesServiceRevisionProvider, (previous, next) => notifications++);

    await fake.createExpense(
      Fixtures.expense(id: 'e1', accountId: 'a1', categoryId: 'c1'),
    );

    expect(container.read(expensesServiceRevisionProvider), 1);
    expect(notifications, greaterThanOrEqualTo(1));
  });

  test('disposing the container detaches the listener without error', () {
    final localFake = ExpensesService(expenseFirestore: NoopExpenseFirestore());
    final localContainer = ProviderContainer(
      overrides: [expensesServiceProvider.overrideWithValue(localFake)],
    );
    localContainer.read(expensesServiceRevisionProvider);
    localContainer.dispose();

    expect(
      () => localFake.createExpense(
        Fixtures.expense(id: 'e2', accountId: 'a1', categoryId: 'c1'),
      ),
      returnsNormally,
    );
  });
}
