import 'package:flutter/material.dart';

/// A single stat inside the summary card: a small icon in a tinted
/// circle, a caption label, and a bold value.
///
/// Replaces the old plain text-only row with something that scans
/// faster and gives each stat its own visual identity via [color].
class SummaryStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;
  final bool isEmphasized;

  const SummaryStat({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color,
    this.isEmphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = color ?? theme.colorScheme.primary;

    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: accent.withAlpha(28),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 17, color: accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: isEmphasized ? FontWeight.w800 : FontWeight.w700,
                  color: isEmphasized ? accent : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}