import 'package:budgly/src/models/account/account.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Account edge cases', () {
    test('initial uses the first character in uppercase', () {
      expect(const Account(name: 'savings').initial, 'S');
    });

    test('copyWith can explicitly clear nullable picture fields', () {
      const account = Account(
        id: 'a1',
        userId: 'u1',
        name: 'Main',
        picture: 'avatar.png',
        pictureUrl: 'https://example.com/avatar.png',
      );

      final cleared = account.copyWith(picture: null, pictureUrl: null);

      expect(cleared.picture, isNull);
      expect(cleared.pictureUrl, isNull);
    });

    test('toJson omits a null id but keeps nullable scalar fields', () {
      const account = Account(name: 'Cash', userId: 'u1');
      final json = account.toJson();

      expect(json.containsKey('id'), isFalse);
      expect(json['user_id'], 'u1');
      expect(json['picture'], isNull);
      expect(json['color'], isNull);
    });

    test('fromJson and toJson preserve the supported color representation', () {
      const color = Color(0xFF336699);
      const account = Account(
        id: 'a1',
        userId: 'u1',
        name: 'Main',
        color: color,
      );

      final restored = Account.fromJson(account.toJson());

      expect(restored.id, account.id);
      expect(restored.userId, account.userId);
      expect(restored.name, account.name);
      expect(restored.color, color);
    });
  });
}
