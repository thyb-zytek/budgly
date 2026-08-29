import 'package:budgly/src/models/expense/expense_occurrence.dart';

class CategoryExpensesUiState {
  final ExpenseOccurrence? editingOccurrence;
  final bool isSaving;
  final int dataRevision;

  const CategoryExpensesUiState({
    this.editingOccurrence,
    this.isSaving = false,
    this.dataRevision = 0,
  });

  CategoryExpensesUiState copyWith({
    ExpenseOccurrence? editingOccurrence,
    bool clearEditingOccurrence = false,
    bool? isSaving,
    int? dataRevision,
  }) {
    return CategoryExpensesUiState(
      editingOccurrence: clearEditingOccurrence
          ? null
          : (editingOccurrence ?? this.editingOccurrence),
      isSaving: isSaving ?? this.isSaving,
      dataRevision: dataRevision ?? this.dataRevision,
    );
  }
}
