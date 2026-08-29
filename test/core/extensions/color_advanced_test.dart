import 'package:budgly/src/core/extensions/color.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HexColor.fromHex', () {
    test('parses 6-digit hex', () {
      final color = HexColor.fromHex('#FF5722');
      expect((color.r * 255.0).round(), 0xFF);
      expect((color.g * 255.0).round(), 0x57);
      expect((color.b * 255.0).round(), 0x22);
    });

    test('parses 8-digit hex with alpha', () {
      final color = HexColor.fromHex('#80FF5722');
      expect((color.a * 255.0).round(), 0x80);
      expect((color.r * 255.0).round(), 0xFF);
    });

    test('parses without hash prefix', () {
      final color = HexColor.fromHex('FF5722');
      expect((color.r * 255.0).round(), 0xFF);
      expect((color.g * 255.0).round(), 0x57);
      expect((color.b * 255.0).round(), 0x22);
    });

    test('parses lowercase hex', () {
      final color = HexColor.fromHex('#ff5722');
      expect((color.r * 255.0).round(), 0xFF);
      expect((color.g * 255.0).round(), 0x57);
      expect((color.b * 255.0).round(), 0x22);
    });
  });

  group('HexColor.toHex', () {
    test('round-trips through fromHex', () {
      final original = HexColor.fromHex('#FF5722');
      final hex = original.toHex();
      final restored = HexColor.fromHex(hex);

      expect((restored.r * 255.0).round(), (original.r * 255.0).round());
      expect((restored.g * 255.0).round(), (original.g * 255.0).round());
      expect((restored.b * 255.0).round(), (original.b * 255.0).round());
    });
  });
}
