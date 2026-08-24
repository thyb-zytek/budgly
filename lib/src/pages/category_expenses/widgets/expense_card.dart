import 'package:budgly/l10n/app_localizations.dart';
import 'package:budgly/src/core/extensions/currency.dart';
import 'package:budgly/src/core/theme/button_styles.dart';
import 'package:budgly/src/models/expense/expense_occurrence.dart';
import 'package:budgly/src/pages/category_expenses/widgets/expense_quick_actions_sheet.dart';
import 'package:budgly/src/pages/category_expenses/widgets/expense_status_avatar.dart';
import 'package:budgly/src/shared/domain/widgets/expenses/recurrence_badge.dart';
import 'package:budgly/src/pages/category_expenses/widgets/swipe_action_background.dart';
import 'package:budgly/src/shared/domain/widgets/expenses/recurrence_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class ExpenseCard extends StatelessWidget {
  final ExpenseOccurrence occurrence;
  final String currencyCode;
  final String localeName;

  final Color? accountColor;

  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggleDebited;
  final VoidCallback onDelete;
  final VoidCallback? onUserInteracted;

  const ExpenseCard({
    super.key,
    required this.occurrence,
    required this.currencyCode,
    required this.localeName,
    required this.onTap,
    required this.onEdit,
    required this.onToggleDebited,
    required this.onDelete,
    this.accountColor,
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

  void _showQuickActionsMenu(BuildContext context) {
    HapticFeedback.mediumImpact();
    onUserInteracted?.call();

    showExpenseQuickActionsSheet(
      context,
      onEdit: occurrence.isDebited ? null : onEdit,
      onDelete: onDelete,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = AppLocalizations.of(context)!;
    final isDebited = occurrence.isDebited;
    final isRecurring = occurrence.recurrence.isRecurring;
    final accent = accountColor ?? theme.colorScheme.primary;
    final success = ButtonType.success.colors(theme);

    final displayDate = isRecurring
        ? occurrence.date
        : (occurrence.expense.createdAt ?? occurrence.date);
    final dateLabel = isRecurring ? tr.debitedOnDate : tr.createdOnDate;

    return GestureDetector(
      onLongPress: () => _showQuickActionsMenu(context),
      child: Dismissible(
        key: ValueKey(occurrence.key),
        direction:
            isDebited ? DismissDirection.endToStart : DismissDirection.horizontal,
        confirmDismiss: (direction) async {
          onUserInteracted?.call();
          if (direction == DismissDirection.startToEnd) {
            if (!isDebited) onToggleDebited();
          } else if (isDebited) {
            onToggleDebited();
          } else {
            onEdit();
          }

          return false;
        },
        background: SwipeActionBackground(
          alignment: Alignment.centerLeft,
          icon: isDebited ? Icons.undo_rounded : Icons.check_rounded,
          color: isDebited
              ? theme.colorScheme.secondary
              : success.background,
          foregroundColor: isDebited
              ? theme.colorScheme.onSecondary
              : success.foreground,
        ),
        secondaryBackground: SwipeActionBackground(
          alignment: Alignment.centerRight,
          icon: isDebited ? Icons.undo_rounded : Icons.edit_rounded,
          color: isDebited
              ? theme.colorScheme.secondary
              : theme.colorScheme.primaryContainer,
          foregroundColor: isDebited
              ? theme.colorScheme.onSecondary
              : theme.colorScheme.onPrimaryContainer,
        ),
        child: InkWell(
          onTap: () {
            onUserInteracted?.call();
            if (!isDebited) onTap();
          },
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              boxShadow: const [],
              color: isDebited
                  ? accent.withValues(alpha: 0.08)
                  : theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDebited
                    ? accent.withValues(alpha: 0.25)
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              spacing: 12,
              children: [
                ExpenseStatusAvatar(color: accountColor, isDebited: isDebited),
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
                          color: theme.colorScheme.onSurface,
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
                            RecurrenceBadge(
                              label: recurrenceLabel(tr, occurrence.recurrence),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
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
