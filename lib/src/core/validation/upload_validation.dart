import 'package:budgly/src/core/constants/app_constants.dart';

class UploadValidationException implements Exception {
  const UploadValidationException(this.message);

  final String message;

  @override
  String toString() => 'UploadValidationException: $message';
}


void validateUploadConstraints({
  required int sizeBytes,
  required String fileExtension,
}) {
  final extension = fileExtension.toLowerCase().replaceFirst('.', '');

  if (!AppConstants.allowedUploadExtensions.contains(extension)) {
    throw UploadValidationException(
      'Unsupported file type ".$extension". Allowed: '
      '${AppConstants.allowedUploadExtensions.join(', ')}.',
    );
  }

  if (sizeBytes <= 0) {
    throw const UploadValidationException('File is empty.');
  }

  if (sizeBytes > AppConstants.maxUploadSizeBytes) {
    final maxMb =
        (AppConstants.maxUploadSizeBytes / (1024 * 1024)).toStringAsFixed(0);
    throw UploadValidationException(
      'File is too large (max ${maxMb}MB).',
    );
  }
}
