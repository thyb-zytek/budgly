import 'package:app/src/shared/widgets/buttons/constants.dart';
import 'package:app/src/shared/widgets/buttons/icon_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class ColorDialog extends StatelessWidget {
  final Color color;
  final void Function(Color) onChange;

  const ColorDialog({super.key, required this.color, required this.onChange});

  @override
  Widget build(BuildContext context) {
    Color _selectedColor = color;

    return AlertDialog(
      titlePadding: const EdgeInsets.all(0),
      contentPadding: const EdgeInsets.all(0),
      shape: RoundedRectangleBorder(
        borderRadius:
            MediaQuery.of(context).orientation == Orientation.portrait
                ? const BorderRadius.only(
                  topLeft: Radius.circular(140),
                  topRight: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                  bottomLeft: Radius.circular(10),
                )
                : const BorderRadius.horizontal(right: Radius.circular(500)),
      ),
      content: SingleChildScrollView(
        child: Stack(
          children: [
            HueRingPicker(
              pickerColor: _selectedColor,
              onColorChanged: (color) => _selectedColor = color,
              enableAlpha: false,
              displayThumbColor: true,
            ),
            Positioned(
              right: 0,
              top: 0,
              child: BudglyIconButton(
                type: ButtonType.iconDefault,
                smallIcon: true,
                icon: Icons.close_rounded,
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 24,
              child: BudglyIconButton(
                type: ButtonType.success,
                smallIcon: true,
                icon: Icons.check_rounded,
                onPressed: () {
                  onChange(_selectedColor);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
