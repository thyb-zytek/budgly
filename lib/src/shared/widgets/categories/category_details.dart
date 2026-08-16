import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isHighlighted;

  const StatusChip({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isHighlighted ? color.withAlpha(28) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4, 
        children: [
          Icon(icon, size: 16, color: color),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}