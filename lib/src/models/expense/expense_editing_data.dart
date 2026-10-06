import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/expense/recurrence.dart';

DateTime _calendarDate(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Pure editable expense state. Flutter controllers are owned by the form
/// controller so this model remains independent from the widget lifecycle.
class ExpenseEditingData {
  ExpenseEditingData({
    this.account,
    this.category,
    DateTime? debitDate,
    this.endDate,
    this.recurrence = RecurrenceType.none,
    this.showAdvancedOptions = false,
  }) : debitDate = _calendarDate(debitDate ?? DateTime.now());

  Account? account;
  Category? category;
  DateTime debitDate;
  DateTime? endDate;
  RecurrenceType recurrence;
  bool showAdvancedOptions;

  DateTime? get effectiveEndDate => recurrence.isRecurring ? endDate : null;

  bool get hasEndDateBeforeDebitDate {
    final end = endDate;
    if (!recurrence.isRecurring || end == null) return false;
    final debitDay = _calendarDate(debitDate);
    final endDay = _calendarDate(end);
    return endDay.isBefore(debitDay);
  }
}
