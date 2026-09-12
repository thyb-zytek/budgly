import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/theme/bottom_sheet.dart';
import 'package:budgly/src/core/theme/button_styles.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:flutter/material.dart';

/// Actions the user can pick between after swiping an [UndebitedExpenseCard]
/// to the right: carry the expense over to the current period, or debit it
/// on the current period right away.
enum UndebitedSwipeRightAction { carryToCurrentPeriod, debitOnCurrentPeriod }

/// Opens the bottom sheet triggered by a right swipe on an undebited expense
/// card. The swipe itself never completes: the card always snaps back and
/// this sheet is the only way to actually pick one of the two current-period
/// actions, which is why a clear title and distinct actions matter here.
Future<UndebitedSwipeRightAction?> showUndebitedSwipeActionsSheet(
  BuildContext context, {
  required String carryLabel,
  required String debitNowLabel,
}) {
  return showAppBottomSheet<UndebitedSwipeRightAction>(
    context,
    useRootNavigator: true,
    builder: (context) => UndebitedSwipeActionsSheet(
      carryLabel: carryLabel,
      debitNowLabel: debitNowLabel,
    ),
  );
}

class UndebitedSwipeActionsSheet extends StatelessWidget {
  final String carryLabel;
  final String debitNowLabel;

  const UndebitedSwipeActionsSheet({
    super.key,
    required this.carryLabel,
    required this.debitNowLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = AppLocalizations.of(context)!;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          BudglySpacing.lg,
          BudglySpacing.xs,
          BudglySpacing.lg,
          BudglySpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: BudglySpacing.sm,
          children: [
            Text(
              tr.undebitedSwipeSheetTitle,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: BudglySpacing.xs),
            FilledButton.icon(
              style: ButtonType.primary.filledStyle(theme, dense: true),
              icon: const Icon(Icons.schedule_send_rounded),
              label: Text(carryLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
              onPressed: () => Navigator.pop(
                context,
                UndebitedSwipeRightAction.carryToCurrentPeriod,
              ),
            ),
            FilledButton.icon(
              style: ButtonType.success.filledStyle(theme, dense: true),
              icon: const Icon(Icons.check_circle_outline),
              label: Text(debitNowLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
              onPressed: () => Navigator.pop(
                context,
                UndebitedSwipeRightAction.debitOnCurrentPeriod,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
