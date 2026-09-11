import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/pages/undebited_expenses/view_model.dart';
import 'package:flutter/material.dart';

/// Flat selection strip pinned right above the expense list while the user is
/// in selection mode.
///
/// Gmail-style: a circular badge carries the number of selected expenses and
/// the two scope controls sit on the right, while the summary of pending
/// expenses above stays untouched. The bottom action bar keeps the three
/// actions shared with the normal per-card mode.
class UndebitedSelectionBanner extends StatelessWidget {
  final UndebitedExpensesViewModel viewModel;

  const UndebitedSelectionBanner({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final selectionEnabled = !viewModel.isProcessing;
    final count = viewModel.selectedCount;

    Widget scopeAction(VoidCallback? onPressed, String label) => Flexible(
          fit: FlexFit.loose,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: TextButton(
              onPressed: onPressed,
              style: _pillButtonStyle(theme),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BudglySpacing.lg,
        BudglySpacing.xs,
        BudglySpacing.lg,
        BudglySpacing.sm,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: BudglySpacing.md,
          vertical: BudglySpacing.sm,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer,
          borderRadius: BudglyRadius.large,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$count',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: BudglySpacing.sm),
            Expanded(
              child: Text(
                tr.selected,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: BudglySpacing.xs),
            scopeAction(
              selectionEnabled ? viewModel.selectAll : null,
              tr.selectAll,
            ),
            scopeAction(
              selectionEnabled ? viewModel.clearSelection : null,
              tr.deselectAll,
            ),
          ],
        ),
      ),
    );
  }

  ButtonStyle _pillButtonStyle(ThemeData theme) => TextButton.styleFrom(
        foregroundColor: theme.colorScheme.primary,
        padding: const EdgeInsets.symmetric(horizontal: BudglySpacing.sm),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        textStyle: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      );
}