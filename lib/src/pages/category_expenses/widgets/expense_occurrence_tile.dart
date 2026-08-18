import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/extensions/currency.dart';
import 'package:budgly/src/core/theme/button_styles.dart';
import 'package:budgly/src/models/expense/expense_occurrence.dart';
import 'package:budgly/src/shared/widgets/selector/recurrence_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ExpenseOccurrenceTile extends StatelessWidget {
  final ExpenseOccurrence occurrence;
  final String currencyCode;
  final String localeName;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggleDebited;
  final VoidCallback? onUserInteracted;

  const ExpenseOccurrenceTile({
    super.key,
    required this.occurrence,
    required this.currencyCode,
    required this.localeName,
    required this.onTap,
    required this.onEdit,
    required this.onToggleDebited,
    this.onUserInteracted,
  });

  String _formatAmount(double value) {
    return formatCurrency(
      amount: value,
      currencyCode: currencyCode,
      localeName: localeName,
    );
  }

  String _formatDate(DateTime date) => DateFormat.yMMMd(localeName).format(date);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = AppLocalizations.of(context)!;
    final isDebited = occurrence.isDebited;
    final isRecurring = occurrence.recurrence.isRecurring;
    final success = ButtonType.success.colors(theme);

    final displayDate = isRecurring
        ? occurrence.date
        : (occurrence.expense.createdAt ?? occurrence.date);
    final dateLabel = isRecurring ? tr.debitedOnDate : tr.createdOnDate;

    return Dismissible(
      key: ValueKey(occurrence.key),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        onUserInteracted?.call();
        if (direction == DismissDirection.startToEnd) {
          onEdit();
        } else {
          onToggleDebited();
        }
        return false;
      },
      background: _SwipeActionBackground(
        alignment: Alignment.centerLeft,
        icon: Icons.edit_rounded,
        color: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
      ),
      secondaryBackground: _SwipeActionBackground(
        alignment: Alignment.centerRight,
        icon: isDebited ? Icons.undo_rounded : Icons.check_rounded,
        color: isDebited ? theme.colorScheme.tertiary : success.background,
        foregroundColor: isDebited ? theme.colorScheme.onTertiary : success.foreground,
      ),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: isDebited ? 0.6 : 1.0,
        child: InkWell(
          onTap: () {
            onUserInteracted?.call();
            onTap();
          },
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withAlpha(70),
              ),
            ),
            child: Row(
              spacing: 12,
              children: [
                _StatusAvatar(isDebited: isDebited),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        occurrence.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        spacing: 6,
                        children: [
                          Icon(
                            Icons.event_outlined,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          Flexible(
                            child: Text(
                              '$dateLabel ${_formatDate(displayDate)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          if (isRecurring)
                            _RecurrenceBadge(
                              label: recurrenceLabel(tr, occurrence.recurrence),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _formatAmount(occurrence.amount),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDebited
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular badge whose icon tells the debited state at a glance.
class _StatusAvatar extends StatelessWidget {
  final bool isDebited;

  const _StatusAvatar({required this.isDebited});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDebited = this.isDebited;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: isDebited
            ? theme.colorScheme.tertiaryContainer
            : theme.colorScheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(
        isDebited ? Icons.check_circle_rounded : Icons.schedule_rounded,
        size: 24,
        color: isDebited
            ? theme.colorScheme.tertiary
            : theme.colorScheme.primary,
      ),
    );
  }
}

class _RecurrenceBadge extends StatelessWidget {
  final String label;

  const _RecurrenceBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 3,
        children: [
          Icon(
            Icons.repeat_rounded,
            size: 12,
            color: theme.colorScheme.primary,
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeActionBackground extends StatelessWidget {
  final Alignment alignment;
  final IconData icon;
  final Color color;
  final Color foregroundColor;

  const _SwipeActionBackground({
    required this.alignment,
    required this.icon,
    required this.color,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: alignment,
      child: Icon(icon, color: foregroundColor, size: 24),
    );
  }
}
