import 'package:budgly/src/shared/ui/widgets/layout/budgly_fab.dart';
import 'package:budgly/src/shared/ui/widgets/layout/fab_label_auto_hide_mixin.dart';
import 'package:flutter/material.dart';

class AddEntity extends StatefulWidget {
  final String heroTag;
  final bool disabled;
  final VoidCallback onPressed;
  final String? label;

  const AddEntity({
    super.key,
    required this.onPressed,
    required this.heroTag,
    this.disabled = false,
    this.label,
  });

  @override
  State<AddEntity> createState() => _AddEntityState();
}

class _AddEntityState extends State<AddEntity> with FabLabelAutoHideMixin {
  @override
  void initState() {
    super.initState();
    startFabLabelAutoHide(visible: widget.label != null);
  }

  @override
  void dispose() {
    disposeFabLabelAutoHide();
    super.dispose();
  }

  void _handlePressed() {
    dismissFabLabel();
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 24,
      right: 24,
      child: ValueListenableBuilder<bool>(
        valueListenable: showFabLabel,
        builder: (context, showLabel, child) => BudglyFab(
          heroTag: widget.heroTag,
          disabled: widget.disabled,
          onPressed: _handlePressed,
          label: showLabel ? widget.label : null,
        ),
      ),
    );
  }
}
