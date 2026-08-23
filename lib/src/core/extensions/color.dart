import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

extension HexColor on Color {
  static Color fromHex(String hexString) {
    var hex = hexString.replaceFirst('#', '');
    if (hex.length == 6) hex = 'ff$hex';
    if (hex.length == 8) hex = hex;
    return Color(int.parse(hex, radix: 16));
  }

  String toHex({bool leadingHashSign = true, bool includeAlpha = true}) {
   return toHexString();
  }
}
