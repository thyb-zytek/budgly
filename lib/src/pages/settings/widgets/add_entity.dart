import 'package:budgly/src/core/theme/component_styles.dart';
import 'package:flutter/material.dart';

class AddEntity extends StatelessWidget {
  final String heroTag;
  final bool disabled;
  final VoidCallback onPressed;
  
  const AddEntity({super.key, required this.onPressed, required this.heroTag, this.disabled = false});

  @override
  Widget build(BuildContext context) {
    return Positioned(
              bottom: 24,
              right: 24,
              child: IgnorePointer(
                ignoring: disabled,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: disabled ? 0.4 : 1,
                  child: SizedBox(
                    width: BudglyComponentStyles.fabSize,
                    height: BudglyComponentStyles.fabSize,
                    child: FloatingActionButton(
                      heroTag: heroTag,
                      onPressed: onPressed,
                      child: Icon(
                        Icons.add_rounded,
                        size: BudglyComponentStyles.fabIconSize,
                      ),
                    ),
                  ),
                ),
              ),
            );
  }
}
