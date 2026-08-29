import 'package:budgly/src/shared/ui/widgets/layout/section_label.dart';
import 'package:flutter/material.dart';

class AdvancedDateField extends StatelessWidget {
  final String label;
  final Widget child;

  const AdvancedDateField({
    super.key,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: [
        SectionLabel(label),
        child,
      ],
    );
  }
}
