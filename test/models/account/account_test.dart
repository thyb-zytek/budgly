import 'package:budgly/src/models/account/account.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Account.fromJson', () {
    test('parses all fields, including a hex color', () {
      final account = Account.fromJson({
        'id': 'acc-1',
        'user_id': 'user-1',
        'name': 'Perso',
        'picture': 'avatar.png',
        'color': '#FF5733',
      });

      expect(account.id, 'acc-1');
      expect(account.userId, 'user-1');
      expect(account.name, 'Perso');
      expect(account.picture, 'avatar.png');
      expect(account.color, const Color(0xFFFF5733));
    });

    test('leaves picture and color null when absent from the JSON', () {
      final account = Account.fromJson({
        'id': 'acc-1',
        'user_id': 'user-1',
        'name': 'Perso',
      });

      expect(account.picture, isNull);
      expect(account.color, isNull);
    });
  });

  group('Account.toJson', () {
    test('includes the id when present', () {
      const account = Account(id: 'acc-1', name: 'Perso');
      expect(account.toJson()['id'], 'acc-1');
    });

    test('omits the id entirely when null (e.g. before first insert)', () {
      const account = Account(name: 'Perso');
      expect(account.toJson().containsKey('id'), isFalse);
    });

    test('serializes a null color as null', () {
      const account = Account(name: 'Perso');
      expect(account.toJson()['color'], isNull);
    });
  });

  group('Account.copyWith', () {
    const base = Account(
      id: 'acc-1',
      userId: 'user-1',
      name: 'Perso',
      picture: 'avatar.png',
      pictureUrl: 'https://example.com/avatar.png',
      color: Color(0xFFFF5733),
    );

    test('keeps existing values when nothing is passed', () {
      final result = base.copyWith();
      expect(result.name, base.name);
      expect(result.picture, base.picture);
      expect(result.pictureUrl, base.pictureUrl);
      expect(result.color, base.color);
    });

    test('overrides name when passed', () {
      expect(base.copyWith(name: 'Compte pro').name, 'Compte pro');
    });

    test('explicitly clears picture when passed null (sentinel pattern)', () {
      final result = base.copyWith(picture: null);
      expect(result.picture, isNull);
      // Sanity check: other fields are untouched by the sentinel logic.
      expect(result.name, base.name);
    });

    test('explicitly clears pictureUrl when passed null (sentinel pattern)', () {
      final result = base.copyWith(pictureUrl: null);
      expect(result.pictureUrl, isNull);
    });

    test(
      'color cannot be cleared via copyWith(color: null) — it falls back '
      'to the existing value, unlike picture/pictureUrl',
      () {
        final result = base.copyWith(color: null);
        expect(result.color, base.color);
      },
    );
  });

  group('Account equality', () {
    test('two accounts with the same id are equal regardless of other fields', () {
      const a = Account(id: 'acc-1', name: 'Perso');
      const b = Account(id: 'acc-1', name: 'Pro');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('two accounts with different ids are not equal', () {
      const a = Account(id: 'acc-1', name: 'Perso');
      const b = Account(id: 'acc-2', name: 'Perso');
      expect(a, isNot(equals(b)));
    });

    test(
      'two accounts with a null id are equal to each other — a real '
      'footgun: two distinct not-yet-saved accounts would collide in a '
      'Set/Map keyed by Account',
      () {
        const a = Account(name: 'Perso');
        const b = Account(name: 'Pro');
        expect(a, equals(b));
      },
    );
  });

  group('Account.initial', () {
    test('is the uppercased first letter of the name', () {
      expect(const Account(name: 'perso').initial, 'P');
      expect(const Account(name: 'Perso').initial, 'P');
    });
  });
}
