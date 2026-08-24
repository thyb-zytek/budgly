import 'dart:async';

import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/core/theme/component_styles.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BudglyFab extends StatefulWidget {
  final String heroTag;
  final String? label;
  final VoidCallback onPressed;
  final bool disabled;

  const BudglyFab({
    super.key,
    required this.heroTag,
    required this.onPressed,
    this.label,
    this.disabled = false,
  });

  @override
  State<BudglyFab> createState() => _BudglyFabState();
}

class _BudglyFabState extends State<BudglyFab> {
  static const collapseDelay = Duration(seconds: 6);
  static const animationDuration = Duration(milliseconds: 250);

  Timer? _collapseTimer;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _restoreExpandedState();
  }

  @override
  void didUpdateWidget(covariant BudglyFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.heroTag != widget.heroTag) {
      _collapseTimer?.cancel();
      setState(() => _expanded = false);
      _restoreExpandedState();
    }
  }

  Future<void> _restoreExpandedState() async {
    if (widget.label == null) return;

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final alreadyUsed =
        prefs.getBool(AppConstants.fabUsedKey(widget.heroTag)) ?? false;

    setState(() => _expanded = !alreadyUsed);
    if (_expanded) _scheduleCollapse();
  }

  void _scheduleCollapse() {
    _collapseTimer?.cancel();
    _collapseTimer = Timer(collapseDelay, () {
      if (mounted) setState(() => _expanded = false);
    });
  }

  void _handlePressed() {
    if (_expanded) {
      _collapseTimer?.cancel();
      setState(() => _expanded = false);
      unawaited(_persistUsed());
    }
    widget.onPressed();
  }

  Future<void> _persistUsed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.fabUsedKey(widget.heroTag), true);
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fabTheme = theme.floatingActionButtonTheme;
    final hasLabel = widget.label != null;
    final showLabel = hasLabel && _expanded;

    final backgroundColor =
        fabTheme.backgroundColor ?? theme.colorScheme.primary;
    final foregroundColor =
        fabTheme.foregroundColor ?? theme.colorScheme.onPrimary;
    final shape =
        fabTheme.shape ??
        const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        );

    // A single, persistent button whose label reveals/hides in place —
    // no widget swap, so there is never a frame with both states on screen.
    Widget fab = Hero(
      tag: widget.heroTag,
      child: Material(
        color: backgroundColor,
        shape: shape,
        elevation: fabTheme.elevation ?? 0,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: shape,
          onTap: widget.disabled ? null : _handlePressed,
          child: Container(
            height: BudglyComponentStyles.fabSize,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_rounded,
                  size: BudglyComponentStyles.fabIconSize,
                  color: foregroundColor,
                ),
                if (hasLabel)
                  ClipRect(
                    child: AnimatedAlign(
                      duration: animationDuration,
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.centerLeft,
                      widthFactor: showLabel ? 1 : 0,
                      child: AnimatedOpacity(
                        duration: animationDuration,
                        curve: Curves.easeOutCubic,
                        opacity: showLabel ? 1 : 0,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            widget.label!,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.clip,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: foregroundColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    if (widget.disabled) {
      fab = IgnorePointer(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: 0.4,
          child: fab,
        ),
      );
    }

    return fab;
  }
}