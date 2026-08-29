import 'package:budgly/src/models/category/category_icon.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CategoryIcon.fromJson', () {
    test('parses an integer icon_code as-is', () {
      final icon = CategoryIcon.fromJson({
        'icon_name': 'restaurant',
        'icon_code': 0xe56c,
        'icon_pack': 'MaterialIcons',
        'labels': {'en': 'Restaurant', 'fr': 'Restaurant'},
      });

      expect(icon.iconCode, 0xe56c);
      expect(icon.labels['fr'], 'Restaurant');
    });

    test('parses a string icon_code', () {
      final icon = CategoryIcon.fromJson({
        'icon_name': 'restaurant',
        'icon_code': '${0xe56c}',
        'icon_pack': 'MaterialIcons',
        'labels': <String, dynamic>{},
      });

      expect(icon.iconCode, 0xe56c);
    });

    test('stringifies non-string label values', () {
      final icon = CategoryIcon.fromJson({
        'icon_name': 'restaurant',
        'icon_code': 1,
        'icon_pack': 'MaterialIcons',
        'labels': {'count': 42},
      });

      expect(icon.labels['count'], '42');
    });
  });

  group('CategoryIcon equality', () {
    test('two icons with the same name/code/pack are equal, labels ignored', () {
      const a = CategoryIcon(
        iconName: 'restaurant',
        iconCode: 1,
        iconPack: 'MaterialIcons',
        labels: {'en': 'Restaurant'},
      );
      const b = CategoryIcon(
        iconName: 'restaurant',
        iconCode: 1,
        iconPack: 'MaterialIcons',
        labels: {'en': 'Different label'},
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('a different iconCode makes icons unequal', () {
      const a = CategoryIcon(
        iconName: 'restaurant',
        iconCode: 1,
        iconPack: 'MaterialIcons',
        labels: {},
      );
      const b = CategoryIcon(
        iconName: 'restaurant',
        iconCode: 2,
        iconPack: 'MaterialIcons',
        labels: {},
      );
      expect(a, isNot(equals(b)));
    });
  });

  group('CategoryIcon.copyWith', () {
    test('overrides only the passed fields', () {
      const base = CategoryIcon(
        iconName: 'restaurant',
        iconCode: 1,
        iconPack: 'MaterialIcons',
        labels: {'en': 'Restaurant'},
      );
      final result = base.copyWith(iconName: 'fastfood');
      expect(result.iconName, 'fastfood');
      expect(result.iconCode, base.iconCode);
      expect(result.iconPack, base.iconPack);
      expect(result.labels, base.labels);
    });
  });
}
