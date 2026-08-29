import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:flutter/material.dart';

class ExpenseEditingData {
  final TextEditingController nameController;
  final TextEditingController amountController;
  Account? account;
  Category? category;
  DateTime debitDate;
  DateTime? endDate;
  RecurrenceType recurrence;
  bool showAdvancedOptions;

  ExpenseEditingData({
    required this.nameController,
    required this.amountController,
    this.account,
    this.category,
    DateTime? debitDate,
    this.endDate,
    this.recurrence = RecurrenceType.none,
    this.showAdvancedOptions = false,
  }) : debitDate = debitDate ?? DateTime.now();

  DateTime? get effectiveEndDate => recurrence.isRecurring ? endDate : null;

  bool get hasEndDateBeforeDebitDate {
    final end = endDate;
    if (!recurrence.isRecurring || end == null) return false;
    final debitDay = DateTime(debitDate.year, debitDate.month, debitDate.day);
    final endDay = DateTime(end.year, end.month, end.day);
    return endDay.isBefore(debitDay);
  }
}
