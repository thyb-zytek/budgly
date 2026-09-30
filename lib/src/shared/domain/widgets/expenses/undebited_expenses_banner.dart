import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/button_styles.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/pages/undebited_expenses/undebited_expenses_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:budgly/src/pages/undebited_expenses/view.dart';
import 'package:flutter/material.dart';

class UndebitedExpensesBanner extends ConsumerWidget {
  const UndebitedExpensesBanner({super.key});

  void _open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const UndebitedExpensesPage()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = AppLocalizations.of(context)!;
    final state = ref.watch(undebitedExpensesProvider);
    if (!state.bannerVisible) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final foreground = theme.colorScheme.onPrimaryContainer;
    return Material(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          BudglySpacing.lg,
          BudglySpacing.sm,
          BudglySpacing.lg,
          BudglySpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: BudglySpacing.sm,
          children: [
            Row(
              children: [
                Icon(Icons.pending_actions_rounded, color: foreground),
                SizedBox(width: BudglySpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(
                        tr.undebitedCount(state.allOccurrences.length),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        tr.undebitedBannerHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: foreground,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: tr.undebitedBannerDismiss,
                  onPressed: () =>
                      ref.read(undebitedExpensesProvider.notifier).dismiss(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => _open(context),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text(tr.manageUndebitedExpenses),
                style: ButtonType.primary.filledStyle(theme),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
