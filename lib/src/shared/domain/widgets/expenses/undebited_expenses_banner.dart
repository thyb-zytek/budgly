import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/extensions/currency.dart';
import 'package:budgly/src/core/theme/bottom_sheet.dart';
import 'package:budgly/src/core/theme/button_styles.dart';
import 'package:budgly/src/core/theme/design_tokens.dart';
import 'package:budgly/src/models/budget/period.dart';
import 'package:budgly/src/models/expense/expense_occurrence.dart';
import 'package:budgly/src/services/expenses/undebited_expenses_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class UndebitedExpensesBanner extends StatefulWidget {
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

  @override
  State<UndebitedExpensesBanner> createState() =>
      _UndebitedExpensesBannerState();
}

class _UndebitedExpensesBannerState extends State<UndebitedExpensesBanner> {
  final bool _busy = false;

  Future<void> _openExpensesSheet() async {
    if (_busy) return;
    await showAppBottomSheet<void>(
      context,
      builder: (context) => _UndebitedExpensesSheet(
        service: widget.service,
        currencyCode: widget.currencyCode,
        localeName: widget.localeName,
        amountDecimalPlaces: widget.amountDecimalPlaces,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: widget.service,
      builder: (context, _) {
        if (!widget.service.shouldShow) return const SizedBox.shrink();

        final theme = Theme.of(context);
        final foreground = theme.colorScheme.onPrimaryContainer;

        return Material(
          color: theme.colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  spacing: BudglySpacing.sm,
                  children: [
                    Icon(Icons.pending_actions_rounded, color: foreground),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 2,
                        children: [
                          Text(
                            tr.undebitedCount(widget.service.count),
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
                      onPressed: _busy ? null : widget.service.dismiss,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _openExpensesSheet,
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

class _UndebitedExpensesSheet extends StatefulWidget {
  final UndebitedExpensesService service;
  final String currencyCode;
  final String localeName;
  final int amountDecimalPlaces;

  const _UndebitedExpensesSheet({
    required this.service,
    required this.currencyCode,
    required this.localeName,
    required this.amountDecimalPlaces,
  });

  @override
  State<_UndebitedExpensesSheet> createState() =>
      _UndebitedExpensesSheetState();
}

class _UndebitedExpensesSheetState extends State<_UndebitedExpensesSheet> {
  String? _busyKey;

  Future<void> _run(
    ExpenseOccurrence occurrence,
    Future<void> Function() action,
  ) async {
    if (_busyKey != null) return;
    setState(() => _busyKey = occurrence.key);
    try {
      await action();
      if (mounted && widget.service.count == 0) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busyKey = null);
    }
  }

  List<({Period period, List<ExpenseOccurrence> occurrences})> _groupByPeriod(
    List<ExpenseOccurrence> occurrences,
  ) {
    final byPeriod = <Period, List<ExpenseOccurrence>>{};
    for (final occurrence in occurrences) {
      final period = Period.fromDate(occurrence.date);
      byPeriod.putIfAbsent(period, () => []).add(occurrence);
    }
    final keys = byPeriod.keys.toList()
      ..sort((a, b) => a.startOfMonth.compareTo(b.startOfMonth));
    return [for (final key in keys) (period: key, occurrences: byPeriod[key]!)];
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: ListenableBuilder(
        listenable: widget.service,
        builder: (context, _) {
          final occurrences = widget.service.occurrences;
          final total = occurrences.fold<double>(
            0,
            (sum, occurrence) => sum + occurrence.amount,
          );
          final currentPeriod =
              widget.service.currentPeriod ?? Period.current();
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              BudglySpacing.lg,
              BudglySpacing.sm,
              BudglySpacing.lg,
              BudglySpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: BudglySpacing.md,
              children: [
                Text(
                  tr.undebitedSheetTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                // Sticky header: the pending count and the total stay visible
                // while the grouped expenses scroll underneath.
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr.undebitedPendingCount(occurrences.length),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      formatCurrency(
                        amount: total,
                        currencyCode: widget.currencyCode,
                        localeName: widget.localeName,
                        decimalPlaces: widget.amountDecimalPlaces,
                        forceDecimal: true,
                      ),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                occurrences.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: BudglySpacing.xl,
                        ),
                        child: Text(
                          tr.undebitedBannerHint,
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.sizeOf(context).height * 0.65,
                        ),
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            for (final group in _groupByPeriod(
                              occurrences,
                            )) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: BudglySpacing.xs,
                                ),
                                child: Text(
                                  group.period.label(widget.localeName),
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              for (final occurrence in group.occurrences)
                                _ExpenseRow(
                                  occurrence: occurrence,
                                  currencyCode: widget.currencyCode,
                                  localeName: widget.localeName,
                                  amountDecimalPlaces:
                                      widget.amountDecimalPlaces,
                                  currentPeriod: currentPeriod,
                                  busy: _busyKey == occurrence.key,
                                  onCarry: () => _run(
                                    occurrence,
                                    () => widget.service
                                        .carryOccurrenceToCurrentPeriod(
                                          occurrence,
                                        ),
                                  ),
                                  onOriginal: () => _run(
                                    occurrence,
                                    () => widget.service
                                        .debitOccurrenceOnOriginalPeriod(
                                          occurrence,
                                        ),
                                  ),
                                  onCurrent: () => _run(
                                    occurrence,
                                    () => widget.service
                                        .debitOccurrenceOnCurrentPeriod(
                                          occurrence,
                                        ),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  final ExpenseOccurrence occurrence;
  final String currencyCode;
  final String localeName;
  final int amountDecimalPlaces;
  final Period currentPeriod;
  final bool busy;
  final VoidCallback onCarry;
  final VoidCallback onOriginal;
  final VoidCallback onCurrent;

  const _ExpenseRow({
    required this.occurrence,
    required this.currencyCode,
    required this.localeName,
    required this.amountDecimalPlaces,
    required this.currentPeriod,
    required this.busy,
    required this.onCarry,
    required this.onOriginal,
    required this.onCurrent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = AppLocalizations.of(context)!;
    final date = DateFormat.yMMMMd(localeName).format(occurrence.date);
    final amount = formatCurrency(
      amount: occurrence.amount,
      currencyCode: currencyCode,
      localeName: localeName,
      decimalPlaces: amountDecimalPlaces,
      forceDecimal: true,
    );
    final originalPeriod = Period.fromDate(
      occurrence.sourceDate ?? occurrence.date,
    );
    final originalLabel = originalPeriod.label(localeName);
    final currentLabel = currentPeriod.label(localeName);

    return Container(
      margin: const EdgeInsets.only(bottom: BudglySpacing.sm),
      padding: const EdgeInsets.all(BudglySpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BudglyRadius.large,
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: BudglySpacing.md,
        children: [
          Row(
            spacing: BudglySpacing.md,
            children: [
              CircleAvatar(
                radius: BudglySpacing.xl,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(
                  Icons.receipt_long_rounded,
                  size: BudglySpacing.xl,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      occurrence.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      date,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                amount,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Column(
            spacing: BudglySpacing.xs,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ActionButton(
                type: ButtonType.primary,
                icon: const Icon(Icons.schedule_send_rounded),
                label: tr.carryToCurrentPeriod(currentLabel),
                busy: busy,
                onPressed: onCarry,
              ),
              _ActionButton(
                type: ButtonType.tertiary,
                icon: _pastCheckIcon(context),
                label: tr.debitOnOriginalPeriod(originalLabel),
                busy: busy,
                onPressed: onOriginal,
              ),
              _ActionButton(
                type: ButtonType.success,
                icon: const Icon(Icons.check_circle_outline),
                label: tr.debitOnCurrentPeriod(currentLabel),
                busy: busy,
                onPressed: onCurrent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A full-width classic button for an expense action, with the leading
/// icon before the label. The carry uses a solid fill (main action), the
/// two debit options are outlined variants (lower emphasis).
class _ActionButton extends StatelessWidget {
  final ButtonType type;
  final Widget icon;
  final String label;
  final bool busy;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.type,
    required this.icon,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = type.colors(theme);
    final style = type.filledStyle(theme, dense: true);
    final leading = busy
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.foreground,
            ),
          )
        : icon;

    final onPressed = busy ? null : this.onPressed;
    return FilledButton.icon(
      onPressed: onPressed,
      style: style.copyWith(
        backgroundColor: WidgetStatePropertyAll(
          type == ButtonType.primary
              ? colors.background
              : colors.background.withAlpha(144),
        ),
      ),
      icon: leading,
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

/// A check mark sitting on a history (clock back) icon: "debited, but in a
/// past period".
Widget _pastCheckIcon(BuildContext context) {
  final theme = Theme.of(context);
  return Stack(
    clipBehavior: Clip.none,
    alignment: Alignment.center,
    children: [
      const Icon(Icons.history_rounded),
      Positioned(
        right: -3,
        bottom: -4,
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, size: 10),
        ),
      ),
    ],
  );
}
