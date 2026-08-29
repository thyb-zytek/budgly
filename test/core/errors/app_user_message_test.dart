import 'package:budgly/src/core/errors/app_user_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('classifyError', () {
    test('classifies a SocketException-like error as a network error', () {
      expect(
        classifyError(Exception('SocketException: Connection refused')),
        AppMessageKey.networkError,
      );
    });

    test('classifies a TimeoutException-like error as a network error', () {
      expect(
        classifyError(Exception('TimeoutException after 30s')),
        AppMessageKey.networkError,
      );
    });

    test('classifies a DNS failure as a network error', () {
      expect(
        classifyError(Exception('Failed host lookup: supabase.co')),
        AppMessageKey.networkError,
      );
    });

    test('classifies a 401/permission-flavored error as a permission error', () {
      expect(
        classifyError(Exception('401 Unauthorized')),
        AppMessageKey.permissionError,
      );
    });

    test('classifies a row-level-security error as a permission error', () {
      expect(
        classifyError(Exception('new row violates row-level security policy')),
        AppMessageKey.permissionError,
      );
    });

    test('classifies a not-found error', () {
      expect(
        classifyError(Exception('PGRST116: Results contain 0 rows (not found)')),
        AppMessageKey.notFoundError,
      );
    });

    test('falls back to unknown for an unrecognized error', () {
      expect(
        classifyError(Exception('something exploded')),
        AppMessageKey.unknownError,
      );
    });

    test('classification is case-insensitive', () {
      expect(
        classifyError(Exception('CONNECTION TIMED OUT')),
        AppMessageKey.networkError,
      );
    });
  });

  group('AppUserMessage equality', () {
    test('two messages with the same key and type are equal', () {
      const a = AppUserMessage.error(AppMessageKey.networkError);
      const b = AppUserMessage.error(AppMessageKey.networkError);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('the same key with a different type is not equal', () {
      const error = AppUserMessage.error(AppMessageKey.accountSaved);
      const success = AppUserMessage.success(AppMessageKey.accountSaved);
      expect(error, isNot(equals(success)));
    });
  });
}
