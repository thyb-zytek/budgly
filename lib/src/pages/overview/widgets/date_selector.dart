import 'package:app/l10n/app_localizations.dart';
import 'package:app/src/shared/widgets/buttons/constants.dart';
import 'package:app/src/shared/widgets/buttons/icon_button.dart';
import 'package:flutter/material.dart';
import 'package:app/src/core/extensions/datetime.dart';

class DateSelector extends StatelessWidget {
  final DateTime period;
  final Function(DateTime newPeriod) onPeriodChanged;
  final int maxMonthsBefore;
  final int maxMonthsAfter;

  const DateSelector({
    super.key,
    required this.period,
    required this.onPeriodChanged,
    this.maxMonthsAfter = 3,
    this.maxMonthsBefore = 12,
  });

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      spacing: 32,
      children: [
        BudglyIconButton(
          icon: Icons.chevron_left_rounded,
          type: ButtonType.iconDefault,
          onPressed: () {
            final now = DateTime.now();
            final limit = DateTime(
              now.year,
              now.month - maxMonthsBefore - 1,
              1,
            );
            final targetDate = DateTime(period.year, period.month - 1, 1);

            return targetDate.isAfter(limit)
                ? () => onPeriodChanged(targetDate)
                : null;
          }(),
        ),
        Text(
          period
              .formatMonthYear(tr.localeName)
              .replaceFirstMapped(
                RegExp(r'^.'),
                (match) => match.group(0)!.toUpperCase(),
              ),
          style: theme.textTheme.headlineSmall,
        ),
        BudglyIconButton(
          icon: Icons.chevron_right_rounded,
          type: ButtonType.iconDefault,
          onPressed: () {
            final now = DateTime.now();
            final limit = DateTime(now.year, now.month + maxMonthsAfter + 1, 1);
            final targetDate = DateTime(period.year, period.month + 1, 1);

            return targetDate.isBefore(limit)
                ? () => onPeriodChanged(targetDate)
                : null;
          }(),
        ),
      ],
    );
  }
}
