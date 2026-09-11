import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/button_styles.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/services/expenses/undebited_expenses_service.dart';
import 'package:budgly/src/pages/undebited_expenses/view.dart';
import 'package:flutter/material.dart';

class UndebitedExpensesBanner extends StatelessWidget {
  final UndebitedExpensesService service;
  final String currencyCode;
  final String localeName;
  final int amountDecimalPlaces;
  const UndebitedExpensesBanner({
    super.key,
    required this.service,
    required this.currencyCode,
    required this.localeName,
    this.amountDecimalPlaces = 2,
  });

  void _open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const UndebitedExpensesPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        if (!service.shouldShow) return const SizedBox.shrink();
        final theme = Theme.of(context);
        final foreground = theme.colorScheme.onPrimaryContainer;
        return Material(
          color: theme.colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              BudglySpacing.lg, BudglySpacing.sm, BudglySpacing.lg, BudglySpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: BudglySpacing.sm,
              children: [
                Row(
                  children: [
                    Icon(Icons.pending_actions_rounded, color: foreground),
                    const SizedBox(width: BudglySpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 2,
                        children: [
                          Text(tr.undebitedCount(service.count), style: theme.textTheme.titleSmall?.copyWith(color: foreground, fontWeight: FontWeight.w700)),
                          Text(tr.undebitedBannerHint, style: theme.textTheme.bodySmall?.copyWith(color: foreground)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: tr.undebitedBannerDismiss,
                      onPressed: service.dismiss,
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
      },
    );
  }
}
