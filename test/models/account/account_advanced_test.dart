import 'package:budgly/src/models/account/account.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Account advanced', () {
    test('initial returns first character uppercased', () {
      const account = Account(name: 'netflix');
      expect(account.initial, 'N');
    });

    test('initial handles single character name', () {
      const account = Account(name: 'A');
      expect(account.initial, 'A');
    });

    test('initial handles already uppercase', () {
      const account = Account(name: 'NETFLIX');
      expect(account.initial, 'N');
    });

    group('fromJson', () {
      test('parses all fields', () {
        final account = Account.fromJson({
          'id': 'a1',
          'user_id': 'u1',
          'name': 'Main',
          'picture': 'pic.png',
          'color': '#FF5722',
        });
        expect(account.id, 'a1');
        expect(account.userId, 'u1');
        expect(account.name, 'Main');
        expect(account.picture, 'pic.png');
        expect(account.color, isNotNull);
      });

      test('handles null optional fields', () {
        final account = Account.fromJson({
          'name': 'Main',
        });
        expect(account.id, isNull);
        expect(account.userId, isNull);
        expect(account.picture, isNull);
        expect(account.color, isNull);
      });
    });

    group('toJson', () {
      test('includes id only when not null', () {
        const withId = Account(id: 'a1', name: 'Main');
        expect(withId.toJson().containsKey('id'), isTrue);

        const withoutId = Account(name: 'Main');
        expect(withoutId.toJson().containsKey('id'), isFalse);
      });

      test('round-trips through fromJson', () {
        const account = Account(
          id: 'a1',
          userId: 'u1',
          name: 'Main',
          picture: 'pic.png',
        );
        final json = account.toJson();
        final restored = Account.fromJson(json);
        expect(restored.id, account.id);
        expect(restored.userId, account.userId);
        expect(restored.name, account.name);
        expect(restored.picture, account.picture);
      });
    });

    group('equality', () {
      test('accounts with same id are equal', () {
        const a = Account(id: 'a1', name: 'First');
        const b = Account(id: 'a1', name: 'Second');
        expect(a, equals(b));
      });

      test('accounts with different ids are not equal', () {
        const a = Account(id: 'a1', name: 'Main');
        const b = Account(id: 'a2', name: 'Main');
        expect(a, isNot(equals(b)));
      });

      test('accounts with null ids are equal (known footgun)', () {
        const a = Account(name: 'A');
        const b = Account(name: 'B');
        expect(a, equals(b));
      });

      test('not equal to non-Account', () {
        const a = Account(id: 'a1', name: 'Main');
        expect(a, isNot('string'));
      });
    });

    group('copyWith', () {
      test('copies all fields', () {
        const original = Account(
          id: 'a1',
          userId: 'u1',
          name: 'Main',
          picture: 'pic.png',
        );
        final copy = original.copyWith(name: 'New');
        expect(copy.name, 'New');
        expect(copy.id, 'a1');
        expect(copy.userId, 'u1');
        expect(copy.picture, 'pic.png');
      });

      test('clears picture when passed null explicitly', () {
        const original = Account(id: 'a1', name: 'Main', picture: 'pic.png');
        final copy = original.copyWith(picture: null);
        expect(copy.picture, isNull);
      });

      test('clears pictureUrl when passed null explicitly', () {
        const original = Account(id: 'a1', name: 'Main', pictureUrl: 'url.png');
        final copy = original.copyWith(pictureUrl: null);
        expect(copy.pictureUrl, isNull);
      });

      test('preserves picture when not passed', () {
        const original = Account(id: 'a1', name: 'Main', picture: 'pic.png');
        final copy = original.copyWith(name: 'New');
        expect(copy.picture, 'pic.png');
      });
    });
  });
}
