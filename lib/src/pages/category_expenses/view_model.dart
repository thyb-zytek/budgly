import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/extensions/amount.dart';
import 'package:budgly/src/core/view_models/base_view_model.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/expense/category_expense_summary.dart';
import 'package:budgly/src/models/expense/expense_editing_data.dart';
import 'package:budgly/src/models/expense/expense_occurrence.dart';
import 'package:budgly/src/models/expense/recurrence.dart';
import 'package:budgly/src/services/accounts/accounts_service.dart';
import 'package:budgly/src/services/categories/categories_service.dart';
import 'package:budgly/src/services/expenses/expenses_service.dart';
import 'package:budgly/src/services/profile/profile_service.dart';
import 'package:flutter/material.dart';

class CategoryExpensesViewModel extends BaseViewModel {
  final ExpensesService _expensesService;
  final CategoriesService _categoriesService;
  final ProfileService _profileService;
  final AccountsService _accountsService;

  final String accountId;
  final String categoryId;
  final Period period;

  ExpenseOccurrence? _editingOccurrence;
  bool _isSaving = false;

  late final ExpenseEditingData editingData;

  CategoryExpensesViewModel({
    required this.accountId,
    required this.categoryId,
    required this.period,
    ExpensesService? expensesService,
    CategoriesService? categoriesService,
    ProfileService? profileService,
    AccountsService? accountsService,
  })  : _expensesService = expensesService ?? ExpensesService.instance,
        _categoriesService = categoriesService ?? CategoriesService.instance,
        _profileService = profileService ?? ProfileService.instance,
        _accountsService = accountsService ?? AccountsService.instance {
    editingData = ExpenseEditingData(
      nameController: TextEditingController(),
      amountController: TextEditingController(),
    );
    _expensesService.addListener(_onServiceChanged);
  }

  void _onServiceChanged() {
    _refreshEditingOccurrence();
    if (!isDisposed) notifyListeners();
  }

  void _refreshEditingOccurrence() {
    final current = _editingOccurrence;
    if (current == null) return;
    final fresh = _expensesService.getExpenseById(current.id);
    if (fresh == null) return;
    _editingOccurrence = ExpenseOccurrence(
      expense: fresh,
      date: current.date,
      isDebited: fresh.isDebitedAt(current.date),
    );
  }

  Category? get category => _categoriesService.getCategoryById(categoryId);

  String get currencyCode => _profileService.currency;
  String get localeName => _profileService.locale.languageCode;

  int get amountDecimalPlaces => _profileService.amountDecimalPlaces;

  Color? get accountColor => _accountsService.getAccountById(accountId)?.color;

  bool get isSaving => _isSaving;

  ExpenseOccurrence? get editingOccurrence => _editingOccurrence;
  bool get isEditingRecurring =>
      _editingOccurrence?.recurrence.isRecurring ?? false;

  Future<void> ensureDataLoaded() async {
    if (!_categoriesService.hasLoadedAccount(accountId)) {
      setLoading(true);
      await _categoriesService.listCategoriesByAccount(accountId);
      setLoading(false);
    }
    if (!_expensesService.hasLoadedAccount(accountId)) {
      setLoading(true);
      await _expensesService.listExpensesByAccount(accountId);
      setLoading(false);
    }
    if (!isDisposed) notifyListeners();
  }

  List<ExpenseOccurrence> get occurrences {
    final expenses = _expensesService
        .getExpensesForAccount(accountId)
        .where((e) => e.categoryId == categoryId)
        .toList();
    if (expenses.isEmpty) return const [];

    final start = period.startOfMonth;
    final end = period.endOfMonth;

    final result = <ExpenseOccurrence>[];
    for (final expense in expenses) {
      result.addAll(expandExpenseOccurrencesBetween(expense, start, end));
    }
    result.sort((a, b) {
      if (a.isDebited != b.isDebited) return a.isDebited ? 1 : -1;
      return a.date.compareTo(b.date);
    });
    return result;
  }

  CategoryExpenseSummary? get summary {
    if (category == null) return null;
    return summarize(occurrences);
  }

  CategoryExpenseSummary summarize(List<ExpenseOccurrence> occurrences) {
    final cat = category!;
    double total = 0;
    double debited = 0;
    double undebited = 0;
    int undebitedCount = 0;
    for (final occurrence in occurrences) {
      total += occurrence.amount;
      if (occurrence.isDebited) {
        debited += occurrence.amount;
      } else {
        undebited += occurrence.amount;
        undebitedCount++;
      }
    }

    return CategoryExpenseSummary(
      category: cat,
      total: total,
      debited: debited,
      undebited: undebited,
      undebitedCount: undebitedCount,
    );
  }

  void startEditing(ExpenseOccurrence occurrence) {
    _editingOccurrence = occurrence;
    editingData.nameController.text = occurrence.name;
    editingData.amountController.text = _formatAmountInput(occurrence.amount);
    editingData.debitDate = occurrence.expense.debitDate;
    editingData.recurrence = occurrence.recurrence;
    editingData.showAdvancedOptions = occurrence.recurrence.isRecurring;
    if (!isDisposed) notifyListeners();
  }

  static String _formatAmountInput(double value) {
    final text = value.toString();
    return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  }

  void setDebitDate(DateTime date) {
    editingData.debitDate = date;
    if (!isDisposed) notifyListeners();
  }

  void setRecurrence(RecurrenceType recurrence) {
    editingData.recurrence = recurrence;
    if (!isDisposed) notifyListeners();
  }

  void toggleAdvancedOptions() {
    editingData.showAdvancedOptions = !editingData.showAdvancedOptions;
    if (!isDisposed) notifyListeners();
  }

  String? validate(AppLocalizations tr) {
    if (editingData.nameController.text.trim().isEmpty) return tr.nameRequired;
    final amount = parseAmount(
      editingData.amountController.text,
      decimalPlaces: _profileService.amountDecimalPlaces,
    );
    if (amount == null) return tr.amountInvalid;
    return null;
  }

  Future<bool> saveEditing() async {
    if (_isSaving) return false;
    final occurrence = _editingOccurrence;
    if (occurrence == null) return false;

    final amount = parseAmount(
      editingData.amountController.text,
      decimalPlaces: _profileService.amountDecimalPlaces,
    );
    if (amount == null) return false;

    _isSaving = true;
    if (!isDisposed) notifyListeners();

    try {
      await _expensesService.updateExpense(
        occurrence.expense.copyWith(
          name: editingData.nameController.text.trim(),
          amount: amount,
          debitDate: editingData.debitDate,
          recurrence: editingData.recurrence,
        ),
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      _isSaving = false;
      if (!isDisposed) notifyListeners();
    }
  }

  Future<bool> deleteEditingExpense() async {
    if (_isSaving) return false;
    final occurrence = _editingOccurrence;
    if (occurrence == null || occurrence.id.isEmpty) return false;

    _isSaving = true;
    if (!isDisposed) notifyListeners();

    try {
      return await _expensesService.deleteExpense(
        occurrence.id,
        accountId,
      );
    } catch (_) {
      return false;
    } finally {
      _isSaving = false;
      if (!isDisposed) notifyListeners();
    }
  }

  Future<bool> deleteOccurrence(ExpenseOccurrence occurrence) async {
    if (_isSaving) return false;
    if (occurrence.id.isEmpty) return false;

    _isSaving = true;
    if (!isDisposed) notifyListeners();

    try {
      return await _expensesService.deleteExpense(
        occurrence.id,
        accountId,
      );
    } catch (_) {
      return false;
    } finally {
      _isSaving = false;
      if (!isDisposed) notifyListeners();
    }
  }

  Future<bool> toggleEditingOccurrenceDebited() async {
    if (_isSaving) return false;
    final occurrence = _editingOccurrence;
    if (occurrence == null) return false;

    _isSaving = true;
    if (!isDisposed) notifyListeners();

    try {
      await _expensesService.toggleOccurrenceDebited(
        occurrence.expense,
        occurrence.date,
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      _isSaving = false;
      if (!isDisposed) notifyListeners();
    }
  }

  Future<bool> toggleDebited(ExpenseOccurrence occurrence) async {
    if (_isSaving) return false;
    _isSaving = true;
    if (!isDisposed) notifyListeners();

    try {
      await _expensesService.toggleOccurrenceDebited(
        occurrence.expense,
        occurrence.date,
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      _isSaving = false;
      if (!isDisposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _expensesService.removeListener(_onServiceChanged);
    editingData.nameController.dispose();
    editingData.amountController.dispose();
    super.dispose();
  }
}
