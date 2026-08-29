import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/extensions/amount.dart';
import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/expense/expense_editing_data.dart';
import 'package:budgly/src/models/expense/expense_occurrence.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:flutter/material.dart';

/// Shared state and behavior for the expense creation/editing form.
///
/// It deliberately contains form concerns only. Creating, updating or
/// deleting an expense remains the responsibility of the owning ViewModel.
class ExpenseFormController extends ChangeNotifier {
  late final ExpenseEditingData data = ExpenseEditingData(
    nameController: TextEditingController(),
    amountController: TextEditingController(),
  );

  void resetForCreation({Account? account, Category? category}) {
    data.nameController.clear();
    data.amountController.clear();
    data.account = account;
    data.category = category;
    data.debitDate = DateTime.now();
    data.endDate = null;
    data.recurrence = RecurrenceType.none;
    data.showAdvancedOptions = false;
    notifyListeners();
  }

  void loadFromOccurrence(
    ExpenseOccurrence occurrence, {
    Category? category,
    Account? account,
  }) {
    data.nameController.text = occurrence.name;
    data.amountController.text = _formatAmount(occurrence.amount);
    data.account = account;
    data.category = category;
    data.debitDate = occurrence.expense.debitDate;
    data.endDate = occurrence.expense.endDate;
    data.recurrence = occurrence.recurrence;
    data.showAdvancedOptions = false;
    notifyListeners();
  }

  void setAccount(Account account) {
    if (data.account?.id == account.id && data.category == null) return;
    data.account = account;
    data.category = null;
    notifyListeners();
  }

  void setCategory(Category category) {
    if (data.category?.id == category.id) return;
    data.category = category;
    notifyListeners();
  }

  void setDebitDate(DateTime date) {
    if (data.debitDate == date) return;
    data.debitDate = date;
    notifyListeners();
  }

  void setEndDate(DateTime date) {
    if (data.endDate == date) return;
    data.endDate = date;
    notifyListeners();
  }

  void clearEndDate() {
    if (data.endDate == null) return;
    data.endDate = null;
    notifyListeners();
  }

  void setRecurrence(
    RecurrenceType recurrence, {
    bool preventPastStart = false,
  }) {
    var changed = data.recurrence != recurrence;
    if (preventPastStart && recurrence.isRecurring) {
      final now = DateTime.now();
      final debitDay = DateTime(
        data.debitDate.year,
        data.debitDate.month,
        data.debitDate.day,
      );
      final todayDay = DateTime(now.year, now.month, now.day);
      if (debitDay.isBefore(todayDay)) {
        data.debitDate = now;
        changed = true;
      }
    }
    if (!changed) return;
    data.recurrence = recurrence;
    notifyListeners();
  }

  void toggleAdvancedOptions() {
    data.showAdvancedOptions = !data.showAdvancedOptions;
    notifyListeners();
  }

  String? validate(
    AppLocalizations tr, {
    bool requireAccountAndCategory = false,
  }) {
    if (requireAccountAndCategory && data.account == null) {
      return tr.accountRequired;
    }
    if (requireAccountAndCategory && data.category == null) {
      return tr.categoryRequired;
    }
    if (data.nameController.text.trim().isEmpty) return tr.nameRequired;

    if (parseAmount(data.amountController.text) == null) {
      return tr.amountInvalid;
    }
    if (data.hasEndDateBeforeDebitDate) return tr.endDateBeforeDebitDate;
    return null;
  }

  double? parseEnteredAmount() => parseAmount(data.amountController.text);

  static String _formatAmount(double value) {
    final text = value.toString();
    return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  }

  @override
  void dispose() {
    data.nameController.dispose();
    data.amountController.dispose();
    super.dispose();
  }
}

