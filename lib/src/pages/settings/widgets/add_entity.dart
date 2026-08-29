import 'dart:async';

import 'package:budgly/src/shared/ui/widgets/layout/budgly_fab.dart';
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

class _AddEntityState extends State<AddEntity> {
  late final ValueNotifier<bool> _showFabLabel;
  Timer? _fabLabelTimer;

  @override
  void initState() {
    super.initState();
    _showFabLabel = ValueNotifier(widget.label != null);
    if (widget.label != null) {
      _fabLabelTimer = Timer(const Duration(seconds: 8), () {
        _showFabLabel.value = false;
      });
    }
  }

  @override
  void dispose() {
    _fabLabelTimer?.cancel();
    _showFabLabel.dispose();
    super.dispose();
  }

  void _handlePressed() {
    _showFabLabel.value = false;
    _fabLabelTimer?.cancel();
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 24,
      right: 24,
      child: ValueListenableBuilder<bool>(
        valueListenable: _showFabLabel,
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
