import 'package:budgly/src/models/expense/expense_occurrence.dart';

class CategoryExpensesUiState {
  final ExpenseOccurrence? editingOccurrence;
  final bool isSaving;

  const CategoryExpensesUiState({
    this.editingOccurrence,
    this.isSaving = false,
  });

  CategoryExpensesUiState copyWith({
    ExpenseOccurrence? editingOccurrence,
    bool clearEditingOccurrence = false,
    bool? isSaving,
  }) {
    return CategoryExpensesUiState(
      editingOccurrence: clearEditingOccurrence
          ? null
          : (editingOccurrence ?? this.editingOccurrence),
      isSaving: isSaving ?? this.isSaving,
    );
  }
}
