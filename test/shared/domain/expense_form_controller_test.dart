import 'package:budgly/l10n/app_localizations_fr.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/expense/expense.dart';
import 'package:budgly/src/models/expense/expense_occurrence.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/shared/domain/widgets/expenses/expense_form_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ExpenseFormController controller;

  setUp(() {
    controller = ExpenseFormController();
  });

  tearDown(() {
    controller.dispose();
  });

  test('resetForCreation initializes a clean form', () {
    const account = Account(id: 'a1', name: 'Compte');
    final category = Category(id: 'c1', accountId: 'a1', name: 'Courses');

    controller.resetForCreation(account: account, category: category);

    expect(controller.data.account, account);
    expect(controller.data.category, category);
    expect(controller.data.nameController.text, isEmpty);
    expect(controller.data.amountController.text, isEmpty);
    expect(controller.data.recurrence, RecurrenceType.none);
    expect(controller.data.showAdvancedOptions, isFalse);
    expect(controller.data.endDate, isNull);
  });

  test('loadFromOccurrence restores the editable fields', () {
    final expense = Expense(
      id: 'e1',
      accountId: 'a1',
      categoryId: 'c1',
      name: 'Courses',
      amount: 42,
      debitDate: DateTime(2026, 8, 10),
      recurrence: RecurrenceType.monthly,
      endDate: DateTime(2026, 12, 10),
    );
    final occurrence = ExpenseOccurrence(
      expense: expense,
      date: DateTime(2026, 8, 10),
      isDebited: false,
    );

    controller.loadFromOccurrence(occurrence);

    expect(controller.data.nameController.text, 'Courses');
    expect(controller.data.amountController.text, '42');
    expect(controller.data.debitDate, DateTime(2026, 8, 10));
    expect(controller.data.endDate, DateTime(2026, 12, 10));
    expect(controller.data.recurrence, RecurrenceType.monthly);
    expect(controller.data.showAdvancedOptions, isFalse);
    expect(controller.data.category, isNull);
  });

  test('loadFromOccurrence keeps advanced options collapsed for recurring', () {
    final expense = Expense(
      id: 'e1',
      accountId: 'a1',
      categoryId: 'c1',
      name: 'Courses',
      amount: 42,
      debitDate: DateTime(2026, 8, 10),
      recurrence: RecurrenceType.monthly,
    );
    final occurrence = ExpenseOccurrence(
      expense: expense,
      date: DateTime(2026, 8, 10),
      isDebited: false,
    );

    controller.loadFromOccurrence(occurrence);

    expect(controller.data.showAdvancedOptions, isFalse);
  });

  test('loadFromOccurrence restores the editable category', () {
    final expense = Expense(
      id: 'e1',
      accountId: 'a1',
      categoryId: 'c1',
      name: 'Courses',
      amount: 42,
      debitDate: DateTime(2026, 8, 10),
    );
    final occurrence = ExpenseOccurrence(
      expense: expense,
      date: DateTime(2026, 8, 10),
      isDebited: true,
    );
    final category = Category(id: 'c1', accountId: 'a1', name: 'Courses');

    controller.loadFromOccurrence(occurrence, category: category);

    expect(controller.data.category, category);
  });

  test('loadFromOccurrence restores the editable account', () {
    final expense = Expense(
      id: 'e1',
      accountId: 'a1',
      categoryId: 'c1',
      name: 'Courses',
      amount: 42,
      debitDate: DateTime(2026, 8, 10),
    );
    final occurrence = ExpenseOccurrence(
      expense: expense,
      date: DateTime(2026, 8, 10),
      isDebited: true,
    );
    const account = Account(id: 'a1', name: 'Compte');

    controller.loadFromOccurrence(occurrence, account: account);

    expect(controller.data.account, account);
  });

  test('form mutations notify listeners', () {
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.setDebitDate(DateTime(2026, 8, 20));
    controller.setRecurrence(RecurrenceType.monthly);
    controller.toggleAdvancedOptions();

    expect(notifications, 3);
  });

  test('validate passes when the first category is preselected on open', () {
    final tr = AppLocalizationsFr();
    const account = Account(id: 'a1', name: 'Compte');
    final category = Category(id: 'c1', accountId: 'a1', name: 'Courses');

    controller.resetForCreation(account: account, category: category);
    controller.data.nameController.text = 'Courses';
    controller.data.amountController.text = '42';

    expect(
      controller.validate(tr, requireAccountAndCategory: true),
      isNull,
      reason: 'a preselected category must satisfy categoryRequired',
    );
  });
}
