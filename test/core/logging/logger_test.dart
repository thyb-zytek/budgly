import 'package:budgly/src/core/logging/logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('expected error logging does not escape as an unhandled async error', () async {
    AppLogger.error('expected test error', StateError('test'));
    await Future<void>.delayed(Duration.zero);
  });
}
