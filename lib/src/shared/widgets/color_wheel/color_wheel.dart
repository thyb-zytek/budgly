import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class ColorWheel extends StatelessWidget {
  final Color color;
  final ValueChanged<Color> onChanged;

  const ColorWheel({super.key, required this.color, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final mediaQuery = MediaQuery.of(context);

        return MediaQuery(
          data: mediaQuery.copyWith(
            size: Size(availableWidth, availableWidth * 0.6),
          ),
          child: SizedBox(
            height: 220,
            child: HueRingPicker(
              pickerColor: color,
              onColorChanged: onChanged,
              enableAlpha: false,
              displayThumbColor: true,
              colorPickerHeight: availableWidth * 0.65,
              hueRingStrokeWidth: 16,
            ),
          ),
        );
      },
    );
  }
}
