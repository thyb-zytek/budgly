import 'dart:math';

import 'package:app/src/shared/widgets/inputs/color_dialog.dart';
import 'package:flutter/material.dart';

class ColorPicker extends StatefulWidget {
  final Color? color;

  final void Function(Color) onChange;

  const ColorPicker({super.key, this.color, required this.onChange});

  @override
  State<ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<ColorPicker> {
  late Color _color;

  @override
  void initState() {
    if (widget.color != null) {
      _color = widget.color!;
    } else {
      _color = Colors.primaries[Random().nextInt(Colors.primaries.length)];
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: FilledButton(
        onPressed:
            () => showDialog(
              context: context,
              builder:
                  (BuildContext context) =>
                      ColorDialog(color: _color, onChange: (color) => setState(() => _color = color)),
            ),
        style: FilledButton.styleFrom(
          backgroundColor: _color,
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          iconSize: 24,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        child: Container(),
      ),
    );
  }
}
