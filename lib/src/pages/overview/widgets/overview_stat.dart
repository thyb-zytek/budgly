import 'package:budgly/src/pages/overview/ui_state.dart';
import 'package:budgly/src/pages/overview/widgets/summary_stat.dart';
import 'package:flutter/material.dart';

class OverviewStat extends StatelessWidget {
  final OverviewStatItem item;
  final bool compact;

  const OverviewStat({
    super.key,
    required this.item,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return SummaryStat(
      icon: item.icon,
      label: item.label,
      value: item.value,
      detail: item.detail,
      detailColor: item.detailColor,
      color: item.color,
      isEmphasized: item.isEmphasized,
      compact: compact,
      tooltip: item.tooltip,
      onTap: item.onTap,
      trailingIcon: item.trailingIcon,
    );
  }
}
