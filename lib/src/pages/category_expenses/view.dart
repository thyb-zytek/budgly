import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/bottom_sheet.dart';
import 'package:budgly/src/core/theme/snackbar.dart';
import 'package:budgly/src/models/expense/expense_occurrence.dart';
import 'package:budgly/src/pages/category_expenses/category_expenses_provider.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:intl/intl.dart';
import 'package:budgly/src/pages/category_expenses/widgets/swipe_hint_wrapper.dart';
import 'package:budgly/src/pages/category_expenses/widgets/category_expenses_content.dart';
import 'package:budgly/src/pages/category_expenses/widgets/category_expense_editor_sheet.dart';
import 'package:budgly/src/pages/settings/widgets/confirm_delete.dart';
import 'package:budgly/src/shared/ui/widgets/layout/loading_indicator.dart';
import 'package:budgly/src/shared/ui/widgets/feedback/riverpod_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:budgly/src/shared/domain/widgets/expenses/expense_form_controller.dart';
import 'package:budgly/src/state/accounts_provider.dart';
import 'package:budgly/src/state/categories_provider.dart';

class CategoryExpensesPage extends ConsumerStatefulWidget {
  final String accountId;
  final String categoryId;
  final Period period;

  const CategoryExpensesPage({
    super.key,
    required this.accountId,
    required this.categoryId,
    required this.period,
  });

  @override
  ConsumerState<CategoryExpensesPage> createState() =>
      _CategoryExpensesPageState();
}

class _CategoryExpensesPageState extends ConsumerState<CategoryExpensesPage> {
  final GlobalKey<SwipeHintWrapperState> _swipeHintKey =
      GlobalKey<SwipeHintWrapperState>();
  final ScrollController _scrollController = ScrollController();

  late final ExpenseFormController _expenseForm;

  CategoryExpensesState get _state => ref.read(
    categoryExpensesProvider(
      widget.accountId,
      widget.categoryId,
      widget.period,
    ),
  );
  CategoryExpenses get _notifier => ref.read(
    categoryExpensesProvider(
      widget.accountId,
      widget.categoryId,
      widget.period,
    ).notifier,
  );

  @override
  void initState() {
    super.initState();
    _expenseForm = ExpenseFormController();
    Future.microtask(() => _notifier.ensureDataLoaded());
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 500) _notifier.loadMore();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _expenseForm.dispose();
    super.dispose();
  }

  Future<void> _openEditSheet(ExpenseOccurrence occurrence) async {
    _notifier.startEditing(occurrence);
    final category = ref
        .read(categoriesSessionProvider)
        .categoriesByAccount[occurrence.expense.accountId]
        ?.where((item) => item.id == occurrence.categoryId)
        .firstOrNull;
    final account = ref
        .read(accountsSessionProvider)
        .accounts
        .where((item) => item.id == occurrence.expense.accountId)
        .firstOrNull;
    _expenseForm.loadFromOccurrence(
      occurrence,
      category: category,
      account: account,
    );
    showAppBottomSheet(
      context,
      builder: (_) => CategoryExpenseEditorSheet(
        form: _expenseForm,
        occurrence: occurrence,
        accountId: widget.accountId,
        categoryId: widget.categoryId,
        period: widget.period,
      ),
    );
  }

  Future<void> _toggleDebited(ExpenseOccurrence occurrence) async {
    final tr = AppLocalizations.of(context)!;
    final wasDebited = occurrence.isDebited;

    final success = await _notifier.toggleDebited(occurrence);
    if (!mounted || !success) return;

    showAppSnackBar(
      context,
      message: wasDebited
          ? tr.expenseMarkedAsPending
          : tr.expenseMarkedAsDebited,
      type: wasDebited ? SnackBarType.pending : SnackBarType.success,
    );
  }

  Future<void> _deleteOccurrence(ExpenseOccurrence occurrence) async {
    final tr = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    var success = false;

    if (occurrence.recurrence.isRecurring) {
      final choice = await showRecurringDeleteOptions(
        context,
        expenseName: occurrence.name,
        dateLabel: DateFormat.yMMMMd(_state.localeName).format(occurrence.date),
      );
      if (choice == null) return;
      if (choice == RecurringDeleteChoice.single) {
        success = await _notifier.deleteSingleOccurrence(occurrence);
      } else {
        success = await _notifier.deleteFutureOccurrences(occurrence);
      }
    } else {
      final deleted = await showConfirmDelete(
        context,
        title: tr.confirmDeleteExpense(occurrence.name),
        content: tr.confirmDeleteExpenseMessage(occurrence.name),
        onConfirm: () async {
          success = await _notifier.deleteOccurrence(occurrence);
        },
      );
      if (deleted != true) return;
    }

    if (!mounted || !success) return;

    messenger.showSnackBar(
      buildAppSnackBar(tr.expenseDeletedSuccessfully, SnackBarType.success),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final state = ref.watch(
      categoryExpensesProvider(
        widget.accountId,
        widget.categoryId,
        widget.period,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          state.category?.name ?? '',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      body: RiverpodFeedback(
        messageListenable: categoryExpensesProvider(
          widget.accountId,
          widget.categoryId,
          widget.period,
        ).select((state) => state.status.pendingMessage),
        onConsume: (ref) => ref
            .read(
              categoryExpensesProvider(
                widget.accountId,
                widget.categoryId,
                widget.period,
              ).notifier,
            )
            .consumeMessage(),
        child: state.isLoading || state.category == null
            ? const AppLoadingIndicator()
            : CategoryExpensesContent(
                state: state,
                translations: tr,
                swipeHintKey: _swipeHintKey,
                onEdit: _openEditSheet,
                onToggleDebited: _toggleDebited,
                onDelete: _deleteOccurrence,
                scrollController: _scrollController,
              ),
      ),
    );
  }
}
