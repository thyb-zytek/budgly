import 'package:budgly/src/core/extensions/collection_equality.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('listContentEquals', () {
    test('true for two empty lists', () {
      expect(listContentEquals<int>([], [], (a, b) => a == b), isTrue);
    });

    test('false when lengths differ', () {
      expect(listContentEquals([1, 2], [1], (a, b) => a == b), isFalse);
    });

    test('true when every element matches by the given predicate', () {
      expect(listContentEquals([1, 2, 3], [1, 2, 3], (a, b) => a == b), isTrue);
    });

    test('false when any element differs, regardless of position', () {
      expect(listContentEquals([1, 2, 3], [1, 5, 3], (a, b) => a == b), isFalse);
    });

    test('order matters: same elements in a different order are not equal', () {
      expect(listContentEquals([1, 2], [2, 1], (a, b) => a == b), isFalse);
    });

    test('supports a custom equality narrower than ==', () {
      // Only compares parity, not exact value.
      final same = listContentEquals(
        [1, 3, 5],
        [7, 9, 11],
        (a, b) => a.isOdd == b.isOdd,
      );
      expect(same, isTrue);
    });
  });
}
