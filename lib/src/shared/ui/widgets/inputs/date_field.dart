import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateField extends StatelessWidget {
  final DateTime? date;
  final String? placeholder;
  final String localeName;
  final ValueChanged<DateTime> onDateChanged;

  final VoidCallback? onCleared;
  final DateTime? firstDate;
  final DateTime? suggestedDate;

  final IconData icon;

  const DateField({
    super.key,
    required this.localeName,
    required this.onDateChanged,
    this.date,
    this.placeholder,
    this.onCleared,
    this.firstDate,
    this.suggestedDate,
    this.icon = Icons.event_outlined,
  });

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final effectiveFirst =
        firstDate ?? now.subtract(const Duration(days: 365));
    final lastDate = now.add(
      const Duration(days: AppConstants.maxFutureExpenseDays),
    );

    var initial = date ?? suggestedDate ?? effectiveFirst;
    if (initial.isBefore(effectiveFirst)) initial = effectiveFirst;
    if (initial.isAfter(lastDate)) initial = lastDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: effectiveFirst,
      lastDate: lastDate,
    );
    if (picked != null) onDateChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasClearButton = onCleared != null;
    final value = date;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _pickDate(context),
      child: Container(
        padding: hasClearButton
            ? const EdgeInsets.only(left: 16, top: 6, bottom: 6, right: 6)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          spacing: 8,
          children: [
            Icon(icon, color: theme.colorScheme.onSurfaceVariant, size: 28),
            Expanded(
              child: value != null
                  ? Text(
                      DateFormat.yMMMMd(localeName).format(value),
                      style: theme.textTheme.bodyMedium,
                    )
                  : Text(
                      placeholder ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
            ),
            if (hasClearButton)
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: onCleared,
              ),
          ],
        ),
      ),
    );
  }
}
