import 'package:budgly/src/models/expense/expense_editing_data.dart';
import 'package:budgly/src/shared/domain/widgets/expenses/expense_editor_sheet.dart';
import 'package:budgly/src/stores/expenses.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/builders.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import '../helpers/pump_app.dart';

void main() {
  testWidgets('editing modal mutation updates the underlying screen without reload', (tester) async {
    final store = ExpensesStore.instance;
    store.clearAll();
    final expense = Fixtures.expense(id: 'e1', accountId: 'a1', categoryId: 'c1', amount: 100);
    store.addExpense(expense);

    await pumpApp(
      tester,
      ListenableBuilder(
        listenable: store,
        builder: (context, _) => Column(
          children: [
            Text('amount:${store.getExpenseById('e1')?.amount.toStringAsFixed(0)}'),
            ElevatedButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => ExpenseEditorSheet(
                  listenable: store,
                  editingData: ExpenseEditingData(
                    nameController: TextEditingController(text: expense.name),
                    amountController: TextEditingController(text: expense.amount.toString()),
                    debitDate: expense.debitDate,
                    recurrence: RecurrenceType.none,
                  ),
                  title: 'Modifier',
                  currencyCode: 'EUR',
                  localeName: 'fr',
                  validate: (_) => null,
                  onSubmit: () async {
                    store.updateExpense(expense.copyWith(amount: 250));
                    return true;
                  },
                  isSaving: () => false,
                  onDateChanged: (_) {},
                  onRecurrenceChanged: (_) {},
                  onEndDateChanged: (_) {},
                  onEndDateCleared: () {},
                  onToggleAdvanced: () {},
                ),
              ),
              child: const Text('Modifier'),
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();

    expect(find.text('amount:250'), findsOneWidget);
  });
}
