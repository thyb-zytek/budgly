import 'package:app/l10n/app_localizations.dart';
import 'package:app/src/shared/widgets/buttons/button.dart';
import 'package:app/src/shared/widgets/buttons/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class ColorDialog extends StatelessWidget {
  final Color color;
  final void Function(Color) onChange;

  const ColorDialog({super.key, required this.color, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    Color _selectedColor = color;

    return AlertDialog(
      titlePadding: const EdgeInsets.all(0),
      contentPadding: const EdgeInsets.all(0),
      shape: RoundedRectangleBorder(
        borderRadius:
            MediaQuery.of(context).orientation == Orientation.portrait
                ? const BorderRadius.vertical(
                  top: Radius.circular(140),
                  bottom: Radius.circular(10),
                )
                : const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(140),
                  bottomLeft: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(8).copyWith(
              bottom: 0,
              right:
                  MediaQuery.of(context).orientation == Orientation.portrait
                      ? 8
                      : 16,
            ),
            child: HueRingPicker(
              pickerColor: _selectedColor,
              onColorChanged: (color) => _selectedColor = color,
              enableAlpha: false,
              displayThumbColor: true,
              pickerAreaBorderRadius: BorderRadius.circular(10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              mainAxisSize: MainAxisSize.max,
              children: [
                BudglyButton(
                  text: tr.cancel,
                  type: ButtonType.error,
                  dense: true,
                  onPressed: () => Navigator.pop(context),
                ),
                BudglyButton(
                  text: tr.validate,
                  type: ButtonType.success,
                  dense: true,
                  onPressed: () {
                    onChange(_selectedColor);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
