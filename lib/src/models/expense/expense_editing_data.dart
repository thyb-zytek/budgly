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
  RecurrenceType recurrence;
  bool showAdvancedOptions;

  ExpenseEditingData({
    required this.nameController,
    required this.amountController,
    this.account,
    this.category,
    DateTime? debitDate,
    this.recurrence = RecurrenceType.none,
    this.showAdvancedOptions = false,
  }) : debitDate = debitDate ?? DateTime.now();
}