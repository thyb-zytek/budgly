import 'package:budgly/src/services/offline/offline_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OfflineId.uuid', () {
    test('returns a string of the expected length', () {
      final id = OfflineId.uuid();
      expect(id, hasLength(36));
    });

    test('follows the 8-4-4-4-12 dashed UUID structure', () {
      final id = OfflineId.uuid();
      final parts = id.split('-');
      expect(parts, hasLength(5));
      expect(parts[0], hasLength(8));
      expect(parts[1], hasLength(4));
      expect(parts[2], hasLength(4));
      expect(parts[3], hasLength(4));
      expect(parts[4], hasLength(12));
    });

    test('only contains hexadecimal characters and dashes', () {
      final id = OfflineId.uuid();
      for (final part in id.split('-')) {
        expect(
          int.tryParse(part, radix: 16),
          isNotNull,
          reason: 'part "$part" is not valid hex',
        );
      }
    });

    test('sets the version nibble to 4 (v4 UUID)', () {
      final id = OfflineId.uuid();
      // The version is the first hex digit of the third group.
      final versionChar = id.split('-')[2].substring(0, 1);
      expect(versionChar, '4');
    });

    test('sets the variant bits to 10xx (10-bit variant)', () {
      final id = OfflineId.uuid();
      // Variant is the first hex digit of the fourth group; 10xx => 8,9,a,b.
      final variantChar = id.split('-')[3].substring(0, 1);
      final variant = int.parse(variantChar, radix: 16);
      // Mask the top two bits: 0xC = 0b1100, expected 0b10 = 2.
      expect((variant & 0xC) >> 2, 2);
    });

    test('generates unique values across many calls', () {
      final ids = List.generate(1000, (_) => OfflineId.uuid()).toSet();
      expect(ids, hasLength(1000));
    });
  });
}
