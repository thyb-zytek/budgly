import 'package:budgly/src/core/extensions/color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HexColor.fromHex', () {
    test('parses a 6-digit hex string with a leading #', () {
      expect(HexColor.fromHex('#FF5733'), const Color(0xFFFF5733));
    });

    test('parses a 6-digit hex string without a leading #', () {
      expect(HexColor.fromHex('00FF00'), const Color(0xFF00FF00));
    });

    test('is case-insensitive', () {
      expect(HexColor.fromHex('ff5733'), HexColor.fromHex('FF5733'));
    });

    test('parses an 8-digit hex string as-is, honoring a custom alpha', () {
      expect(HexColor.fromHex('80112233'), const Color(0x80112233));
    });

    test('defaults to fully opaque for a 6-digit input', () {
      expect(HexColor.fromHex('123456'), const Color(0xFF123456));
    });
  });

  group('HexColor.toHex', () {
    // Note: toHex() delegates entirely to flutter_colorpicker's
    // Color.toHexString() — the leadingHashSign/includeAlpha parameters are
    // currently accepted but ignored (see color.dart). This round-trip test
    // only checks that the underlying implementation still produces
    // something fromHex can parse back; run `flutter test` locally to
    // confirm the flutter_colorpicker version in use behaves this way.
    test('round-trips through fromHex for an opaque color', () {
      const original = Color(0xFFAB12CD);
      final hex = original.toHex();
      expect(HexColor.fromHex(hex), original);
    });
  });
}
