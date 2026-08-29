import 'package:budgly/src/core/constants/app_constants.dart';
import 'package:budgly/src/core/validation/upload_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateUploadConstraints', () {
    test('accepts a file within the size limit and an allowed extension', () {
      expect(
        () => validateUploadConstraints(
          sizeBytes: 1024,
          fileExtension: 'jpg',
        ),
        returnsNormally,
      );
    });

    test('accepts extensions regardless of case', () {
      expect(
        () => validateUploadConstraints(
          sizeBytes: 1024,
          fileExtension: 'PNG',
        ),
        returnsNormally,
      );
    });

    test('accepts a leading dot in the extension', () {
      expect(
        () => validateUploadConstraints(
          sizeBytes: 1024,
          fileExtension: '.webp',
        ),
        returnsNormally,
      );
    });

    test('rejects an unsupported extension', () {
      expect(
        () => validateUploadConstraints(
          sizeBytes: 1024,
          fileExtension: 'exe',
        ),
        throwsA(isA<UploadValidationException>()),
      );
    });

    test('rejects a file larger than the configured max size', () {
      expect(
        () => validateUploadConstraints(
          sizeBytes: AppConstants.maxUploadSizeBytes + 1,
          fileExtension: 'jpg',
        ),
        throwsA(isA<UploadValidationException>()),
      );
    });

    test('accepts a file exactly at the size limit', () {
      expect(
        () => validateUploadConstraints(
          sizeBytes: AppConstants.maxUploadSizeBytes,
          fileExtension: 'jpg',
        ),
        returnsNormally,
      );
    });

    test('rejects an empty file', () {
      expect(
        () => validateUploadConstraints(
          sizeBytes: 0,
          fileExtension: 'jpg',
        ),
        throwsA(isA<UploadValidationException>()),
      );
    });

    test('rejects a negative size', () {
      expect(
        () => validateUploadConstraints(
          sizeBytes: -1,
          fileExtension: 'jpg',
        ),
        throwsA(isA<UploadValidationException>()),
      );
    });
  });
}
