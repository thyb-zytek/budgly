import 'package:budgly/src/models/account/account.dart';
import 'package:budgly/src/models/category/category.dart';
import 'package:budgly/src/models/category/category_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Category.fromJson', () {
    test('parses all fields, including a hex color', () {
      final category = Category.fromJson({
        'id': 'cat-1',
        'name': 'Food',
        'color': '#00FF00',
        'icon': '0xe5d2',
        'account_id': 'acc-1',
      });

      expect(category.id, 'cat-1');
      expect(category.name, 'Food');
      expect(category.color, const Color(0xFF00FF00));
      expect(category.iconCode, '0xe5d2');
      expect(category.accountId, 'acc-1');
    });

    test('leaves color null when absent from the JSON', () {
      final category = Category.fromJson({
        'id': 'cat-1',
        'name': 'Food',
        'account_id': 'acc-1',
      });
      expect(category.color, isNull);
    });
  });

  group('Category.toJson', () {
    test('includes the id when present', () {
      final category = Category(id: 'cat-1', name: 'Food', accountId: 'acc-1');
      expect(category.toJson()['id'], 'cat-1');
    });

    test('omits the id when null', () {
      final category = Category(name: 'Food', accountId: 'acc-1');
      expect(category.toJson().containsKey('id'), isFalse);
    });

    test('derives the icon field from a CategoryIcon when set, ignoring iconCode', () {
      final category = Category(
        name: 'Food',
        accountId: 'acc-1',
        iconCode: 'should-be-ignored',
        icon: const CategoryIcon(
          iconName: 'restaurant',
          iconCode: 0xe56c,
          iconPack: 'MaterialIcons',
          labels: {},
        ),
      );
      expect(category.toJson()['icon'], '0xe56c');
    });

    test('falls back to the raw iconCode string when no CategoryIcon is set', () {
      final category = Category(
        name: 'Food',
        accountId: 'acc-1',
        iconCode: '0xe5d2',
      );
      expect(category.toJson()['icon'], '0xe5d2');
    });
  });

  group('Category.copyWith', () {
    test('keeps existing values when nothing is passed', () {
      final base = Category(id: 'cat-1', name: 'Food', accountId: 'acc-1');
      final result = base.copyWith();
      expect(result.id, base.id);
      expect(result.name, base.name);
      expect(result.accountId, base.accountId);
    });

    test('overrides accountId when a new Account is passed', () {
      final base = Category(id: 'cat-1', name: 'Food', accountId: 'acc-1');
      final result = base.copyWith(account: const Account(id: 'acc-2', name: 'Pro'));
      expect(result.accountId, 'acc-2');
    });

    test('keeps the original accountId when no Account is passed', () {
      final base = Category(id: 'cat-1', name: 'Food', accountId: 'acc-1');
      expect(base.copyWith(name: 'Groceries').accountId, 'acc-1');
    });

    test('updating the icon also refreshes the derived iconCode', () {
      final base = Category(
        id: 'cat-1',
        name: 'Food',
        accountId: 'acc-1',
        iconCode: '0x1',
      );
      final result = base.copyWith(
        icon: const CategoryIcon(
          iconName: 'restaurant',
          iconCode: 0xe56c,
          iconPack: 'MaterialIcons',
          labels: {},
        ),
      );
      expect(result.iconCode, '0xe56c');
    });
  });

  group('Category identity', () {
    test('two categories with the same fields are not equal (no operator== override)', () {
      final a = Category(id: 'cat-1', name: 'Food', accountId: 'acc-1');
      final b = Category(id: 'cat-1', name: 'Food', accountId: 'acc-1');
      expect(a, isNot(equals(b)));
    });
  });
}

