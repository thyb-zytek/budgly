import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/models/expense/expense_occurrence.dart';
import 'package:budgly/src/pages/category_expenses/category_expenses_provider.dart'
    hide CategoryExpenses;
import 'package:budgly/src/pages/category_expenses/widgets/expense_card.dart';
import 'package:budgly/src/pages/category_expenses/widgets/swipe_hint_wrapper.dart';
import 'package:budgly/src/shared/domain/widgets/categories/category_expenses.dart';
import 'package:budgly/src/shared/ui/widgets/layout/empty_state.dart';
import 'package:flutter/material.dart';

class CategoryExpensesContent extends StatelessWidget {
  final CategoryExpensesState state;
  final AppLocalizations translations;
  final GlobalKey<SwipeHintWrapperState> swipeHintKey;
  final ValueChanged<ExpenseOccurrence> onEdit;
  final Future<void> Function(ExpenseOccurrence) onToggleDebited;
  final Future<void> Function(ExpenseOccurrence) onDelete;
  final ScrollController scrollController;

  const CategoryExpensesContent({
    super.key,
    required this.state,
    required this.translations,
    required this.swipeHintKey,
    required this.onEdit,
    required this.onToggleDebited,
    required this.onDelete,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final occurrences = state.occurrences;
    final summary = state.summary;

    // The category card stays pinned above the scrollable expense list so it
    // remains visible while scrolling.
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            BudglySpacing.lg,
            BudglySpacing.xs,
            BudglySpacing.lg,
            BudglySpacing.sm,
          ),
          child: CategoryExpenses(
            summary: summary!,
            currencyCode: state.currencyCode,
            localeName: state.localeName,
            decimalPlaces: state.amountDecimalPlaces,
          ),
        ),
        Expanded(
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              if (occurrences.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: translations.noExpensesForCategory,
                    subtitle: translations.noExpensesForCategoryHint,
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    BudglySpacing.lg,
                    BudglySpacing.xs,
                    BudglySpacing.lg,
                    88,
                  ),
                  sliver: SliverList.separated(
                    itemCount: occurrences.length,
                    separatorBuilder: (_, _) =>
                        SizedBox(height: BudglySpacing.md),
                    itemBuilder: (context, index) {
                      final occurrence = occurrences[index];
                      final card = ExpenseCard(
                        occurrence: occurrence,
                        currencyCode: state.currencyCode,
                        localeName: state.localeName,
                        decimalPlaces: state.amountDecimalPlaces,
                        accountColor: state.accountColor,
                        onTap: () => onEdit(occurrence),
                        onEdit: () => onEdit(occurrence),
                        onToggleDebited: () => onToggleDebited(occurrence),
                        onDelete: () => onDelete(occurrence),
                        onUserInteracted: () =>
                            swipeHintKey.currentState?.stop(),
                      );
                      return index == 0
                          ? SwipeHintWrapper(
                              key: swipeHintKey,
                              isDebited: occurrence.isDebited,
                              child: card,
                            )
                          : card;
                    },
                  ),
                ),
              if (state.isLoadingMore)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      BudglySpacing.lg,
                      BudglySpacing.sm,
                      BudglySpacing.lg,
                      88,
                    ),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
